namespace utils_crawler
{
    // An attack clock that counts down (reuse, global recovery) after InDeltaSeconds: never below 0, and unmoved by a zero
    // or negative delta.
    float32 Get_CountdownAfter(float32 InRemaining, float32 InDeltaSeconds)
    {
        return Math::Max(InRemaining - Math::Max(InDeltaSeconds, 0.0f), 0.0f);
    }

    // An attack clock that counts up (the readiness wait, cleanup) after InDeltaSeconds: unmoved by a zero or negative delta.
    float32 Get_CountupAfter(float32 InElapsed, float32 InDeltaSeconds)
    {
        return InElapsed + Math::Max(InDeltaSeconds, 0.0f);
    }
}

// One phase change, broadcast once the tick has written everything.
struct FMars_Crawler_AttackPhaseChange
{
    EMars_Crawler_AttackPhase Old = EMars_Crawler_AttackPhase::Idle;
    EMars_Crawler_AttackPhase New = EMars_Crawler_AttackPhase::Idle;
}

// The attack's game state (armed crawlers only). The clip action owns the motion's timing; this tick starts it, cancels
// it and follows what the resolver accepted from it. Every tick runs a fixed pass:
//   1. cancellation: the queued cancel, then the resolver's displacement and obstruction, then the direct guards (Dead,
//      Hurt, Crippled, TargetLost, PoseFailed, Unsupported); the first reason wins. An offensive phase (Windup, Strike,
//      Recover) drops its candidate, bumps the generation, closes the damage window and cancels the action, whose
//      dedicated return eases the body back (and whose limb return hands claimed legs back to the gait) while the
//      attack waits in CancelRecover; Dead, PoseFailed and Disabled go straight to Cooldown. A cancel during
//      CancelRecover or Cooldown changes nothing but LastCancel, except a failed or lost action in CancelRecover, which
//      ends the wait;
//   2. commit: a surviving candidate of this generation on the live, enabled, undepleted target, with the crawler alive
//      and unhurt since admission, becomes the attack's one damage request;
//   3. accepted phase: each posed phase an accepted interval reached since the last tick is entered in order (a hitch
//      never skips one), and Recover ends in Cooldown once the accepted motion closed the Offense window;
//   4. admission of a queued start (from Idle only; anything else records the reason in LastReject): the plan's clip is
//      played with its slots bound to the claimed limbs;
//   5. settling: CancelRecover ends in Cooldown on the action's terminal record; Cooldown counts down and returns to Idle
//      once the player has released the action whose terminal record the resolver acknowledged.
// Existing accepted receipts establish admission and its costs before cancellation, even at zero DeltaT. No readiness,
// reuse, global recovery or cleanup clock advances without positive time.
class UMars_Processor_Crawler_AttackTick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Crawler_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_BodyPart_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Health_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Crawler);
        Query.Require(FMars_Fragment_Crawler_Attack);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Self = InHandle.As_Crawler();
        auto Changes = TArray<FMars_Crawler_AttackPhaseChange>();
        const auto OldDecision = Self.Get_AttackDecision();
        const auto OldAdmission = Self.Get_AttackAdmission();
        const auto OldResult = Self.Get_AttackResult();
        auto CueBefore = FMars_Crawler_CueDispatchBefore();
        CueBefore.Admission = OldAdmission;
        CueBefore.Result = OldResult;
        CueBefore.Interrupted = Self.Get_Fragment(FMars_Fragment_Crawler_Attack).CueInterrupted;
        Tick(Self, float32(InDeltaT.Get_Seconds()), Changes);
        const auto CueObservations = Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).PendingCueObservations;
        Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).PendingCueObservations.Empty();
        utils_crawler::Dispatch_AttackCues(Self, CueBefore, CueObservations);

        if (Self.Has_Fragment(FMars_Fragment_Crawler_Signals) == false)
        { return; }

        auto& Signals = Self.Get_Fragment(FMars_Fragment_Crawler_Signals);
        const auto Decision = Self.Get_AttackDecision();
        const auto Admission = Self.Get_AttackAdmission();
        const auto Result = Self.Get_AttackResult();
        if (Decision.Signature != OldDecision.Signature || Decision.LastReason != OldDecision.LastReason)
        { Signals.OnAttackDecisionChanged.Broadcast(Self, Decision); }

        if (Admission.Accepted && (OldAdmission.Accepted == false || Admission.ActionIdentity.Get_Value() != OldAdmission.ActionIdentity.Get_Value()))
        { Signals.OnAttackAdmitted.Broadcast(Self, Admission); }

        if (Result.Completed && (OldResult.Completed == false || Result.ActionIdentity.Get_Value() != OldResult.ActionIdentity.Get_Value()))
        { Signals.OnAttackCompleted.Broadcast(Self, Result); }

        for (const auto& Change : Changes)
        { Signals.OnAttackPhaseChanged.Broadcast(Self, Change.Old, Change.New); }
    }

    private void Tick(FCk_Handle_Crawler& InSelf, float32 InDeltaSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Intents = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackIntents);
        const auto StartIntent = Intents.PendingStart;
        const auto CancelIntent = Intents.PendingCancel;
        const auto PrepareIntent = Intents.PendingPrepare;
        Intents.PendingStart.Reset();
        Intents.PendingCancel.Reset();
        Intents.PendingPrepare.Reset();
        LatchAdmission(InSelf);

        auto& Selection = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection);
        const auto Abandoned = PrepareIntent.IsSet() && PrepareIntent.GetValue().Preparation == ECk_EnableDisable::Disable;
        if (CancelIntent.IsSet() || Abandoned || (Selection.Preparation.State != EMars_Attack_PreparationState::Idle &&
            (Selection.Preparation.TargetIdentity != utils_crawler::Get_AttackTargetIdentity(InSelf.Get_CombatTarget()) ||
                Selection.Preparation.TargetGeneration != InSelf.Get_CombatTargetGeneration())))
        { Selection.Preparation = FMars_Attack_Preparation(); }

        const auto CancelReason = Find_CancelReason(InSelf, CancelIntent);

        auto& Hit = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Hit;
        Hit.Displaced.Reset();
        Hit.Obstructed = false;

        if (CancelReason.IsSet())
        { ApplyCancel(InSelf, CancelReason.GetValue(), OutChanges); }

        // A zero-time tick advances no clock, but every intent it drained is still applied (a dropped request would
        // leave the HFSM waiting on a preparation that never started).
        for (auto& Reuse : Selection.Reuse)
        { Reuse.Remaining = utils_crawler::Get_CountdownAfter(Reuse.Remaining, InDeltaSeconds); }

        if (PrepareIntent.IsSet() && Abandoned == false && CancelIntent.IsSet() == false &&
            InSelf.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle &&
            PrepareIntent.GetValue().Target == InSelf.Get_CombatTarget() && InSelf.Get_IsCombatTargetValid(PrepareIntent.GetValue().Target))
        {
            Selection.Preparation = FMars_Attack_Preparation();
            Selection.Preparation.State = EMars_Attack_PreparationState::Active;
            Selection.Preparation.TargetIdentity = utils_crawler::Get_AttackTargetIdentity(PrepareIntent.GetValue().Target);
            Selection.Preparation.TargetGeneration = InSelf.Get_CombatTargetGeneration();
        }

        // Without a drained intent, the decision the last tick ended on still stands.
        if (PrepareIntent.IsSet() || CancelIntent.IsSet() || StartIntent.IsSet())
        { UpdateDecision(InSelf); }

        if (Selection.Preparation.State == EMars_Attack_PreparationState::Active && Selection.Decision.Evaluation.Selection.Preferred.IsSet() == false)
        {
            Selection.Preparation = FMars_Attack_Preparation();
            auto Event = FMars_Attack_HistoryEntry();
            Event.Event = n"PreparationAbandoned";
            Event.Reason = n"NoPreferred";
            RecordHistory(InSelf, Event);
        }

        if (Selection.Preparation.State == EMars_Attack_PreparationState::Active)
        {
            Selection.Preparation.Preferred = Selection.Decision.Evaluation.Selection.Preferred.GetValue();
            Selection.Preparation.ElapsedReadinessWait = utils_crawler::Get_CountupAfter(Selection.Preparation.ElapsedReadinessWait, InDeltaSeconds);
            const auto Preferred = utils_crawler::Find_ResolvedAttack(InSelf.Get_Spec().ResolvedAttacks, Selection.Preparation.Preferred);
            if (Preferred.IsSet() && Selection.Preparation.ElapsedReadinessWait >= Preferred.GetValue().Definition.Prepare.TimeoutSeconds)
            {
                Selection.Preparation.State = EMars_Attack_PreparationState::TimedOut;
                auto Event = FMars_Attack_HistoryEntry();
                Event.Event = n"PreparationTimedOut";
                Event.AttackId = Selection.Preparation.Preferred;
                Event.Reason = n"PrepareTimeout";
                RecordHistory(InSelf, Event);
            }

            UpdateDecision(InSelf);
        }

        CommitCandidate(InSelf);

        FollowAcceptedPhase(InSelf, OutChanges);

        if (StartIntent.IsSet())
        {
            if (CancelIntent.IsSet())
            { InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).Diagnostics.LastReject = TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::CancelPending); }
            else
            { Admit(InSelf, StartIntent.GetValue(), OutChanges); }
        }

        Settle(InSelf, InDeltaSeconds, OutChanges);
        UpdateDecision(InSelf);
    }

    private void RecordHistory(FCk_Handle_Crawler& InSelf, FMars_Attack_HistoryEntry InEntry)
    {
        auto& Ledger = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Ledger;
        auto Entry = InEntry;
        Entry.Context.AttemptGeneration = InSelf.Get_AttackGeneration();
        Entry.Context.SelectionGeneration = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Generation;
        Entry.Context.TargetGeneration = InSelf.Get_CombatTargetGeneration();
        Entry.Context.Evaluation = InSelf.Get_AttackEvaluation();
        ++Ledger.EventSequence;
        Entry.Sequence = Ledger.EventSequence;
        Ledger.History.Add(Entry);
        if (Ledger.History.Num() > constants_crawler::k_AttackHistoryCap)
        { Ledger.History.RemoveAt(0); }
    }

    private void UpdateDecision(FCk_Handle_Crawler& InSelf)
    {
        auto Evaluation = utils_crawler::Evaluate_AttackLoadout(InSelf, InSelf.Get_CombatTarget());
        const auto Signature = utils_crawler::Get_AttackDecisionSignature(Evaluation);
        const auto SelectionSignature = utils_crawler::Get_AttackSelectionSignature(Evaluation);
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection);
        const auto Changed = Signature != State.Decision.Signature;
        // The generation guards an explicit start against a choice that is no longer the kernel's: it moves with the
        // selection, never with an unrelated entry's blocker (a reuse clock expiring elsewhere is not a stale choice).
        if (SelectionSignature != State.Decision.SelectionSignature)
        { ++State.Generation; }

        Evaluation.SelectionGeneration = State.Generation;
        State.Decision.Evaluation = Evaluation;
        State.Decision.Signature = Signature;
        State.Decision.SelectionSignature = SelectionSignature;
        if (Changed)
        {
            auto Event = FMars_Attack_HistoryEntry();
            Event.Event = n"Decision";
            Event.AttackId = Evaluation.Selection.Preferred.IsSet() ? Evaluation.Selection.Preferred.GetValue() : FGameplayTag();
            RecordHistory(InSelf, Event);
        }
    }

    // Folds the resolver's stream evidence into the attack: the first accepted receipt of this action admits it (and
    // spends its reuse), a terminal record is its native result, and a window the resolver closed stays closed.
    private void LatchAdmission(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        auto& Stream = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Stream;
        if (Stream.FirstAccepted.IsSet() && Attack.Admission.Accepted == false)
        {
            const auto Stamp = Stream.FirstAccepted.GetValue();
            if (Stamp.Get_Identity().Get_Value() == Attack.Stream.Identity.Get_Value())
            {
                Attack.Admission.Accepted = true;
                Attack.Admission.SampleId = Stamp.Get_SampleSequence();
                Attack.Result.Accepted = true;
                auto& Selection = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection);
                ++Selection.Ledger.StartSequence;
                for (auto& Reuse : Selection.Reuse)
                {
                    if (Reuse.Id == Attack.Plan.Entry.Identity.Id)
                    {
                        Reuse.Remaining = Attack.Plan.Entry.Definition.Cooldown.ReuseSeconds;
                        Reuse.LastStartSequence = Selection.Ledger.StartSequence;
                    }
                }

                auto Event = FMars_Attack_HistoryEntry();
                Event.Event = n"Admitted";
                Event.AttackId = Attack.Plan.Entry.Identity.Id;
                Event.ActionIdentity = Attack.Stream.Identity;
                RecordHistory(InSelf, Event);
            }
        }

        Stream.FirstAccepted.Reset();
        if (Stream.Terminal.IsSet())
        {
            Attack.Result.Evidence.Observed = true;
            Attack.Result.Evidence.Source = Stream.TerminalSource;
            Attack.Result.Native = Stream.Terminal.GetValue();
            Attack.Diagnostics.LastActionOutcome = Attack.Result.Native.Get_Outcome();
            Attack.Diagnostics.LastActionReason = Attack.Result.Native.Get_Reason();
        }

        if (Stream.Failure.IsNone() == false)
        { Attack.Result.Evidence.Failure = Stream.Failure; }

        if (Stream.WindowClosed)
        { Attack.WindowClosed = true; }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 1. Cancellation
    //----------------------------------------------------------------------------------------------------------------------

    private TOptional<EMars_Crawler_AttackCancel> Find_CancelReason(const FCk_Handle_Crawler& InSelf, TOptional<EMars_Crawler_AttackCancel> InIntent)
    {
        if (InIntent.IsSet())
        { return InIntent; }

        const auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        const auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        const auto Spec = InSelf.Get_Spec();

        if (utils_crawler::Get_IsOffensivePhase(Attack.Phase))
        {
            if (Observations.Hit.Displaced.IsSet())
            { return Observations.Hit.Displaced; }

            if (Observations.Hit.Obstructed)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Obstructed); }

            if (InSelf.Get_IsCombatDead())
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Dead); }

            if (InSelf.Get_HurtCount() != Attack.Start.HurtCount)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Hurt); }

            if (utils_crawler::Evaluate_AttackContinuation(InSelf).Num() > 0 || Observations.Hit.RequiredPartFailures.Num() > 0)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::RequiredPartUnavailable); }

            if (utils_procedural_gait::Get_EnabledLegCount(InSelf.Get_Gait()) < Spec.MinLegsToWalk)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Crippled); }

            if (InSelf.Get_IsCombatTargetValid(Attack.Start.Target) == false)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::TargetLost); }

            if (utils_procedural_body_pose::Get_Status(InSelf.Get_BodyPose()) == ECk_ProceduralAnimation_Status::Failed ||
                Observations.Stream.Failed || utils_crawler::Get_IsAttackActionLost(InSelf) ||
                Get_HasActionStoppedOnItsOwn(Attack.Stream))
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::PoseFailed); }

            if (InSelf.Get_SupportRejection().IsSet())
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Unsupported); }
        }

        // The return cannot be waited for once the action's stream has failed or the action is gone.
        if (Attack.Phase == EMars_Crawler_AttackPhase::CancelRecover &&
            (Observations.Stream.Failed || utils_crawler::Get_IsAttackActionLost(InSelf)))
        { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::PoseFailed); }

        return TOptional<EMars_Crawler_AttackCancel>();
    }

    // The library interrupted the clip (support loss, a rejected pose, a watchdog) or finished it short of completion. A
    // completed clip returns to neutral on its own; the accepted Offense exit ends its offense instead.
    private bool Get_HasActionStoppedOnItsOwn(const FMars_Crawler_AttackStream& InStream) const
    {
        if (ck::Is_NOT_Valid(InStream.Action) || InStream.CancelRequested)
        { return false; }

        const auto State = InStream.Action.Get_State();
        if (State == ECk_ProceduralAction_State::Cancelling)
        { return true; }

        return State == ECk_ProceduralAction_State::Finished &&
            InStream.Action.Get_Result().Get_Outcome() != ECk_ProceduralAction_Outcome::Completed;
    }

    private void ApplyCancel(FCk_Handle_Crawler& InSelf, EMars_Crawler_AttackCancel InReason, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        const auto Phase = Attack.Phase;
        if (Phase == EMars_Crawler_AttackPhase::Idle)
        { return; }

        Attack.Diagnostics.LastCancel = TOptional<EMars_Crawler_AttackCancel>(InReason);
        if (Attack.Result.RequiredPartFailures.Num() == 0)
        {
            const auto ObservedFailures = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Hit.RequiredPartFailures;
            Attack.Result.RequiredPartFailures = ObservedFailures.Num() > 0 ? ObservedFailures : utils_crawler::Evaluate_AttackContinuation(InSelf);
        }

        InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Preparation = FMars_Attack_Preparation();
        if (InReason == EMars_Crawler_AttackCancel::PoseFailed && ck::IsValid(Attack.Stream.Action))
        {
            const auto Result = Attack.Stream.Action.Get_Result();
            Attack.Diagnostics.LastActionOutcome = Result.Get_Outcome();
            Attack.Diagnostics.LastActionReason = Result.Get_Reason();
        }

        if (utils_crawler::Get_IsOffensivePhase(Phase))
        {
            auto CancelEvent = FMars_Attack_HistoryEntry();
            CancelEvent.Event = n"Cancelled";
            CancelEvent.AttackId = Attack.Plan.Entry.Identity.Id;
            CancelEvent.ActionIdentity = Attack.Stream.Identity;
            CancelEvent.Reason = FName(f"{InReason :n}");
            RecordHistory(InSelf, CancelEvent);

            InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Hit.Candidate.Reset();
            if (Attack.Admission.Accepted)
            { Attack.CueInterrupted = true; }

            ++Attack.Generation;
            Attack.WindowClosed = true;
            CancelAction(InSelf);

            const auto SkipsRecovery = InReason == EMars_Crawler_AttackCancel::Dead || InReason == EMars_Crawler_AttackCancel::PoseFailed ||
                InReason == EMars_Crawler_AttackCancel::Disabled;
            if (SkipsRecovery)
            {
                EnterCooldown(InSelf, GetRecoverySeconds(InSelf), OutChanges);
                return;
            }

            Enter(InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack), EMars_Crawler_AttackPhase::CancelRecover, OutChanges);
            return;
        }

        if (Phase == EMars_Crawler_AttackPhase::CancelRecover && InReason == EMars_Crawler_AttackCancel::PoseFailed)
        {
            CancelAction(InSelf);
            EnterCooldown(InSelf, GetRecoverySeconds(InSelf), OutChanges);
        }
    }

    // Once per attack; the action's own return owns neutralization from wherever the body and the claimed limbs are.
    private void CancelAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Stream = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).Stream;
        if (Stream.CancelRequested || utils_crawler::Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Stream.Action) ||
            Stream.Action.Get_State() == ECk_ProceduralAction_State::Finished)
        { return; }

        Stream.CancelRequested = true;
        Stream.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel());
    }

    private void EnterCooldown(FCk_Handle_Crawler& InSelf, float32 InCooldownSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Enter(Attack, EMars_Crawler_AttackPhase::Cooldown, OutChanges);
        Attack.CooldownRemaining = InCooldownSeconds;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 2. Commit
    //----------------------------------------------------------------------------------------------------------------------

    private void CommitCandidate(FCk_Handle_Crawler& InSelf)
    {
        auto& Hit = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Hit;
        if (Hit.Candidate.IsSet() == false)
        { return; }

        const auto Candidate = Hit.Candidate.GetValue();
        Hit.Candidate.Reset();

        if (Get_IsCommittable(InSelf, Candidate) == false)
        { return; }

        const auto Definition = InSelf.Get_AttackPlan().Entry.Definition.Hit;
        auto Dealer = InSelf.Get_CombatDealer();
        FCk_Handle Root = InSelf;

        auto Event = utils_damage_dealer::Make_Event(Dealer, Definition.Damage, Definition.DamageType);
        Event.Source.Instigator = Root;
        Event.Source.Causer = Root;
        Event.Hit.Location = Candidate.Location;
        Event.Hit.Normal = Candidate.Normal;
        Event.Hit.Impulse = FVector::ZeroVector;
        Dealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(Candidate.HitEntity, Event));

        auto& Ledger = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).Ledger;
        Ledger.Committed = true;
        Ledger.SampleId = Candidate.SampleId;
        Ledger.Emitter = Candidate.EmitterContact;
    }

    private bool Get_IsCommittable(const FCk_Handle_Crawler& InSelf, const FMars_Crawler_HitCandidate& InCandidate)
    {
        const auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.Ledger.Committed || InCandidate.Generation != Attack.Generation || InCandidate.Target != Attack.Start.Target)
        { return false; }

        if (ck::Is_NOT_Valid(InSelf.Get_CombatDealer()) || ck::Is_NOT_Valid(InCandidate.Zone) || InCandidate.Zone.Get_IsEnabled() == false)
        { return false; }

        if (InSelf.Get_IsCombatTargetValid(Attack.Start.Target) == false || InSelf.Get_IsCombatDead())
        { return false; }

        return Attack.Admission.Accepted && InSelf.Get_HurtCount() == Attack.Start.HurtCount &&
            utils_crawler::Evaluate_AttackContinuation(InSelf).Num() == 0;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 3. Accepted phase
    //----------------------------------------------------------------------------------------------------------------------

    private void FollowAcceptedPhase(FCk_Handle_Crawler& InSelf, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        const auto& Accepted = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Accepted;
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);

        while (utils_crawler::Get_IsOffensivePhase(Attack.Phase) && int32(Attack.Phase) < int32(Accepted.Phase))
        { Enter(Attack, EMars_Crawler_AttackPhase(int32(Attack.Phase) + 1), OutChanges); }

        if (Attack.Phase == EMars_Crawler_AttackPhase::Recover && Accepted.OffenseEnded)
        { EnterCooldown(InSelf, GetRecoverySeconds(InSelf), OutChanges); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 4. Admission
    //----------------------------------------------------------------------------------------------------------------------

    private void Admit(FCk_Handle_Crawler& InSelf, const FMars_Request_Crawler_StartAttack& InRequest, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        if (InSelf.Get_AttackPhase() != EMars_Crawler_AttackPhase::Idle)
        {
            Reject(InSelf, EMars_Crawler_AttackReject::Busy);
            return;
        }

        if (InRequest.Target != InSelf.Get_CombatTarget() || InSelf.Get_IsCombatTargetValid(InRequest.Target) == false)
        {
            Reject(InSelf, EMars_Crawler_AttackReject::TargetInvalid);
            return;
        }

        if (InSelf.Get_IsWarded(InRequest.Target))
        {
            Reject(InSelf, EMars_Crawler_AttackReject::Warded);
            return;
        }

        const auto Advice = InSelf.Get_AttackEvaluation();
        auto Id = InRequest.AttackId;
        if (Id.IsValid() == false)
        {
            if (Advice.Selection.Selected.IsSet() == false)
            {
                const auto Rejection = InSelf.Get_StartRejection(InRequest.Target);
                Reject(InSelf, Rejection.IsSet() ? Rejection.GetValue() : EMars_Crawler_AttackReject::NotReady);
                return;
            }

            Id = Advice.Selection.Selected.GetValue();
        }
        else
        {
            if (utils_crawler::Find_ResolvedAttack(InSelf.Get_Spec().ResolvedAttacks, Id).IsSet() == false)
            {
                Reject(InSelf, EMars_Crawler_AttackReject::AttackUnknown);
                return;
            }

            if (InRequest.SelectionGeneration != Advice.SelectionGeneration)
            {
                Reject(InSelf, EMars_Crawler_AttackReject::SelectionStale);
                return;
            }

            if (Advice.Selection.Selected.IsSet() == false || Advice.Selection.Selected.GetValue() != Id)
            {
                Reject(InSelf, EMars_Crawler_AttackReject::SelectionNotPermitted);
                return;
            }
        }

        auto Ready = false;
        for (const auto& Evaluation : Advice.Evaluations)
        { Ready = Ready || (Evaluation.AttackId == Id && Evaluation.Availability == EMars_Attack_Availability::Ready); }

        if (Ready == false)
        {
            Reject(InSelf, EMars_Crawler_AttackReject::NotReady);
            return;
        }

        auto Plan = FMars_Attack_ResolvedPlan();
        Plan.Entry = utils_crawler::Find_ResolvedAttack(InSelf.Get_Spec().ResolvedAttacks, Id).GetValue();
        Plan.Execution = InSelf.Get_Spec().ResolvedAttacks.Execution;
        Plan.GameRevision = InSelf.Get_Spec().ResolvedAttacks.GameRevision;
        Plan.Target = InRequest.Target;
        Plan.TargetGeneration = InSelf.Get_CombatTargetGeneration();
        Plan.SelectionGeneration = Advice.SelectionGeneration;
        if (CreateAction(InSelf, Plan) == false)
        {
            Reject(InSelf, EMars_Crawler_AttackReject::NotReady);
            return;
        }

        const auto Root = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());
        const auto Up = utils_surface_motion::Get_SupportNormal(InSelf.Get_Motion()).GetSafeNormal();
        const auto Forward = Root.GetRotation().GetForwardVector();
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(InSelf.Get_Presentation());

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        ++Attack.Generation;
        Attack.Admission = FMars_Attack_Admission();
        Attack.Admission.AttackId = Plan.Entry.Identity.Id;
        Attack.Admission.ActionIdentity = Attack.Stream.Identity;
        Attack.Admission.AttemptGeneration = Attack.Generation;
        Attack.Admission.SelectionGeneration = Plan.SelectionGeneration;
        Attack.CueInterrupted = false;
        Attack.Result = FMars_Attack_Result();
        Attack.Result.AttackId = Plan.Entry.Identity.Id;
        Attack.Result.ActionIdentity = Attack.Stream.Identity;
        InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Preparation = FMars_Attack_Preparation();
        Attack.Diagnostics.LastReject.Reset();
        Attack.Start.HurtCount = InSelf.Get_HurtCount();
        Attack.Start.Root = Root.GetLocation();
        Attack.Start.NeutralRootLocal = Presentation.GetRelativeTransform(Root);
        Attack.Start.Direction = (Forward - Up * Forward.DotProduct(Up)).GetSafeNormal();
        Attack.Start.Target = InRequest.Target;
        Attack.Ledger = FMars_Crawler_AttackDamageLedger();
        Attack.WindowClosed = false;

        // A new action's stream starts from nothing: the resolver reads it from cursor 0.
        auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        Observations = FMars_Fragment_Crawler_AttackObservations();

        Enter(Attack, EMars_Crawler_AttackPhase::Windup, OutChanges);
    }

    // Takes back any limb an earlier return left unplanted, then plays the plan's clip with its slots bound to the claimed
    // limbs. False (nothing created) without a player, without the plan's clip loaded, or when the action is not created.
    private bool CreateAction(FCk_Handle_Crawler& InSelf, const FMars_Attack_ResolvedPlan& InPlan)
    {
        const auto Player = InSelf.Get_ActionPlayer();
        if (ck::Is_NOT_Valid(Player) || ck::Is_NOT_Valid(InPlan.Entry.Definition.Clip.Get()))
        { return false; }

        utils_crawler::Recover_UnplantedLimbs(InSelf);
        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        auto Claimed = TArray<FName>();
        for (const auto& Slot : InPlan.Entry.Slots)
        {
            Bindings.Add(FCk_ProceduralAction_SlotBinding(Slot.Slot, Slot.Binding.LimbId));
            Claimed.Add(Slot.Binding.LimbId);
        }

        auto PlaySpec = FCk_ProceduralAction_PlaySpec(InPlan.Entry.Definition.Clip);
        PlaySpec.Set_SlotBindings(Bindings);
        PlaySpec.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);
        FCk_Handle Owner = InSelf;
        const auto Action = utils_procedural_action::Create_FromClip(Owner, Player, PlaySpec);
        if (ck::Is_NOT_Valid(Action))
        { return false; }

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Attack.Plan = InPlan;
        Attack.Stream = FMars_Crawler_AttackStream();
        Attack.Stream.Action = Action;
        Attack.Stream.Identity = Action.Get_Identity();
        Attack.Cleanup = FMars_Crawler_AttackCleanup();
        Attack.Cleanup.ClaimedIds = Claimed;
        return true;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 5. Settling
    //----------------------------------------------------------------------------------------------------------------------

    private void Settle(FCk_Handle_Crawler& InSelf, float32 InDeltaSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.Phase == EMars_Crawler_AttackPhase::CancelRecover && InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Stream.TerminalSeen)
        {
            EnterCooldown(InSelf, GetRecoverySeconds(InSelf), OutChanges);
            return;
        }

        if (Attack.Phase != EMars_Crawler_AttackPhase::Cooldown)
        { return; }

        Attack.CooldownRemaining = utils_crawler::Get_CountdownAfter(Attack.CooldownRemaining, InDeltaSeconds);
        if (Attack.CooldownRemaining > 0.0f)
        { return; }

        if (Attack.Cleanup.Released == false && ForgetReleasedAction(InSelf) == false)
        { return; }

        if (Attack.Admission.Accepted == false)
        { Attack.Cleanup.ClaimedIds.Empty(); }

        auto Settled = InSelf.Get_Articulation().Get_Health() == ECk_ProceduralArticulation_Health::Operational;
        auto NeedsRecovery = false;
        for (const auto Id : Attack.Cleanup.ClaimedIds)
        {
            const auto Part = utils_crawler::Find_AttackPart(InSelf, Id);
            if (ck::Is_NOT_Valid(Part) || Part.Get_State() != EMars_BodyPart_State::Attached || ck::Is_NOT_Valid(Part.Get_Health()) ||
                Part.Get_Health().Get_IsDepleted() || Part.Get_Leg().Get_IsAttached() == false)
            { continue; }

            const auto Control = InSelf.Get_Articulation().Get_LimbControl(Id).Get_State();
            NeedsRecovery = NeedsRecovery || Control == ECk_ProceduralLimbControl_State::Unplanted;
            Settled = Settled && Control == ECk_ProceduralLimbControl_State::Default &&
                Part.Get_Leg().Get_Foot().Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted;
        }

        if (NeedsRecovery && Attack.Cleanup.Requested == false)
        {
            utils_crawler::Recover_UnplantedLimbs(InSelf);
            Attack.Cleanup.Requested = true;
        }

        Attack.Cleanup.Elapsed = utils_crawler::Get_CountupAfter(Attack.Cleanup.Elapsed, InDeltaSeconds);
        const auto Limit = Math::Max(Attack.Plan.Execution.Locomotion.Get_Return().Get_Timeout().Get_Seconds(),
            Attack.Plan.Execution.Tuning.Get_Transition().Get_ReturnTimeout().Get_Seconds());
        if (Settled == false && Attack.Cleanup.Elapsed < Limit)
        { return; }

        Attack.Result.CleanupOutcome = Settled ? (Attack.Cleanup.Requested ? n"AutonomousRecovered" : n"Settled") : n"CleanupTimeout";
        Attack.Result.Completed = true;
        auto Event = FMars_Attack_HistoryEntry();
        Event.Event = n"Completed";
        Event.AttackId = Attack.Result.AttackId;
        Event.ActionIdentity = Attack.Result.ActionIdentity;
        Event.Reason = Attack.Result.Native.Get_Reason();
        Event.Result = Attack.Result;
        RecordHistory(InSelf, Event);
        Enter(Attack, EMars_Crawler_AttackPhase::Idle, OutChanges);
    }

    // True once the attack's action is gone after its terminal record was read (the player released it when the resolver
    // acknowledged that record), or after its stream became unavailable. Forgets the action and lets the gait take back
    // any claimed limb the return left unplanted.
    private bool ForgetReleasedAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        const auto& Stream = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Stream;
        FCk_Handle Action = Attack.Stream.Action;
        const auto Gone = ck::Is_NOT_Valid(Action) ||
            utils_entity_lifetime::Get_IsPendingDestroy(Action, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
        if (Gone == false || (Stream.TerminalSeen == false && Stream.Unavailable == false))
        { return false; }

        // The owned action really disappeared: no native terminal result was observed, and none is invented.
        if (Stream.TerminalSeen == false && Attack.Result.Evidence.Failure.IsNone())
        { Attack.Result.Evidence.Failure = n"ActionLost"; }

        Attack.Stream.Action = FCk_Handle_ProceduralAction();
        Attack.Stream.Identity = FCk_ProceduralAction_Identity();
        Attack.Cleanup.Released = true;
        // Whatever admission reached (an unadmitted action may still have acquired its claims); Settle then waits for
        // the limbs to plant.
        if (Attack.Cleanup.ClaimedIds.Num() > 0 && utils_crawler::Recover_UnplantedLimbs(InSelf))
        { Attack.Cleanup.Requested = true; }

        return true;
    }

    private float32 GetRecoverySeconds(const FCk_Handle_Crawler& InSelf) const
    { return InSelf.Get_AttackAdmission().Accepted ? InSelf.Get_AttackPlan().Entry.Definition.Cooldown.RecoverySeconds : 0.0f; }

    private void Reject(FCk_Handle_Crawler& InSelf, EMars_Crawler_AttackReject InReason)
    {
        InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).Diagnostics.LastReject = TOptional<EMars_Crawler_AttackReject>(InReason);
        InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Decision.LastReason = FName(f"{InReason :n}");
        auto Event = FMars_Attack_HistoryEntry();
        Event.Event = n"Rejected";
        Event.Reason = FName(f"{InReason :n}");
        RecordHistory(InSelf, Event);
    }

    private void Enter(FMars_Fragment_Crawler_Attack& InOutAttack, EMars_Crawler_AttackPhase InPhase, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto Change = FMars_Crawler_AttackPhaseChange();
        Change.Old = InOutAttack.Phase;
        Change.New = InPhase;
        OutChanges.Add(Change);

        InOutAttack.Phase = InPhase;
    }
}
