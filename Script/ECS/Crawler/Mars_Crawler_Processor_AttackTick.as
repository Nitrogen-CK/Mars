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
//      dedicated return eases the body back (and whose limb return hands a pincer's claws back to the gait) while the
//      attack waits in CancelRecover; Dead, PoseFailed and Disabled go straight to Cooldown. A cancel during
//      CancelRecover or Cooldown changes nothing but LastCancel, except a failed or lost action in CancelRecover, which
//      ends the wait;
//   2. commit: a surviving candidate of this generation on the live, enabled, undepleted target, with the crawler alive
//      and unhurt since admission, becomes the attack's one damage request;
//   3. accepted phase: each posed phase an accepted interval reached since the last tick is entered in order (a hitch
//      never skips one), and Recover ends in Cooldown once the accepted motion closed the Offense window;
//   4. admission of a queued start (from Idle only; anything else records the reason in LastReject): the clip is built
//      for this attack's claws and played;
//   5. settling: CancelRecover ends in Cooldown on the action's terminal record; Cooldown counts down and returns to Idle
//      once the player has released the action whose terminal record the resolver acknowledged.
// Existing accepted receipts establish admission/costs before cancellation, even at zero DeltaT. No readiness,
// reuse, global recovery or autonomous-cleanup clock advances without positive time.
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

        const auto Decision = Self.Get_AttackDecision();
        const auto Admission = Self.Get_AttackAdmission();
        const auto Result = Self.Get_AttackResult();
        if (Decision.Signature != OldDecision.Signature || Decision.LastReason != OldDecision.LastReason)
        { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackDecisionChanged.Broadcast(Self, Decision); }
        if (Admission.Accepted && (OldAdmission.Accepted == false || Admission.ActionIdentity.Get_Value() != OldAdmission.ActionIdentity.Get_Value()))
        { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackAdmitted.Broadcast(Self, Admission); }
        if (Result.Completed && (OldResult.Completed == false || Result.ActionIdentity.Get_Value() != OldResult.ActionIdentity.Get_Value()))
        { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackCompleted.Broadcast(Self, Result); }
        for (const auto& Change : Changes)
        { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackPhaseChanged.Broadcast(Self, Change.Old, Change.New); }
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
        if (CancelIntent.IsSet() || ((Selection.Preparation.Active || Selection.Preparation.TimedOut) &&
            (Selection.Preparation.TargetIdentity != utils_crawler::Get_AttackTargetIdentity(InSelf.Get_CombatTarget()) ||
                Selection.Preparation.TargetGeneration != InSelf.Get_CombatTargetGeneration())))
        { Selection.Preparation = FMars_Attack_Preparation(); }

        const auto CancelReason = Find_CancelReason(InSelf, CancelIntent);

        auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        Observations.Displaced.Reset();
        Observations.Obstructed = false;

        if (CancelReason.IsSet())
        { ApplyCancel(InSelf, CancelReason.GetValue(), OutChanges); }

        // A zero-time tick advances no clock, but every intent it drained is still applied (a dropped request would
        // leave the HFSM waiting on a preparation that never started).
        for (auto& Reuse : Selection.Reuse)
        { Reuse.Remaining = Math::Max(Reuse.Remaining - InDeltaSeconds, 0.0f); }
        if (PrepareIntent.IsSet() && CancelIntent.IsSet() == false && InSelf.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle &&
            PrepareIntent.GetValue().Target == InSelf.Get_CombatTarget() && InSelf.Get_IsCombatTargetValid(PrepareIntent.GetValue().Target))
        {
            Selection.Preparation = FMars_Attack_Preparation();
            Selection.Preparation.Active = true;
            Selection.Preparation.TargetIdentity = utils_crawler::Get_AttackTargetIdentity(PrepareIntent.GetValue().Target);
            Selection.Preparation.TargetGeneration = InSelf.Get_CombatTargetGeneration();
        }
        UpdateDecision(InSelf);
        if (Selection.Preparation.Active && Selection.Decision.Evaluation.Selection.Preferred.IsSet() == false)
        {
            Selection.Preparation = FMars_Attack_Preparation();
            auto Event = FMars_Attack_HistoryEntry();
            Event.Event = n"PreparationAbandoned";
            Event.Reason = n"NoPreferred";
            RecordHistory(InSelf, Event);
        }
        if (Selection.Preparation.Active)
        {
            if (Selection.Decision.Evaluation.Selection.Preferred.IsSet())
            { Selection.Preparation.Preferred = Selection.Decision.Evaluation.Selection.Preferred.GetValue(); }
            Selection.Preparation.ElapsedReadinessWait += Math::Max(InDeltaSeconds, 0.0f);
            const auto Preferred = utils_crawler::Find_ResolvedAttack(InSelf.Get_Spec().ResolvedAttacks, Selection.Preparation.Preferred);
            if (Preferred.IsSet() && Selection.Preparation.ElapsedReadinessWait >= Preferred.GetValue().Definition.Prepare.TimeoutSeconds)
            {
                Selection.Preparation.TimedOut = true;
                Selection.Preparation.Active = false;
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
            auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
            if (CancelIntent.IsSet())
            { Attack.LastReject = TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::CancelPending); }
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
        Entry.Sequence = ++Ledger.EventSequence;
        Ledger.History.Add(Entry);
        if (Ledger.History.Num() > 16)
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

    private void LatchAdmission(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        if (Observations.FirstAccepted.IsSet() && Attack.Admission.Accepted == false)
        {
            const auto Stamp = Observations.FirstAccepted.GetValue();
            if (Stamp.Get_Identity().Get_Value() == Attack.ActionIdentity.Get_Value())
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
                Event.ActionIdentity = Attack.ActionIdentity;
                RecordHistory(InSelf, Event);
            }
        }
        Observations.FirstAccepted.Reset();
        if (Observations.Terminal.IsSet())
        {
            Attack.Result.Evidence.Observed = true;
            Attack.Result.Evidence.Source = Observations.TerminalSource;
            Attack.Result.Native = Observations.Terminal.GetValue();
            Attack.LastActionOutcome = Attack.Result.Native.Get_Outcome();
            Attack.LastActionReason = Attack.Result.Native.Get_Reason();
        }
        if (Observations.StreamFailure.IsNone() == false)
        { Attack.Result.Evidence.Failure = Observations.StreamFailure; }
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
            if (Observations.Displaced.IsSet())
            { return Observations.Displaced; }

            if (Observations.Obstructed)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Obstructed); }

            if (InSelf.Get_IsCombatDead())
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Dead); }

            if (InSelf.Get_HurtCount() != Attack.HurtCountAtStart)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Hurt); }

            if (utils_crawler::Evaluate_AttackContinuation(InSelf).Num() > 0 || Observations.RequiredPartFailures.Num() > 0)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::RequiredPartUnavailable); }

            if (utils_procedural_gait::Get_EnabledLegCount(InSelf.Get_Gait()) < Spec.MinLegsToWalk)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Crippled); }

            if (InSelf.Get_IsCombatTargetValid(Attack.Target) == false)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::TargetLost); }

            if (utils_procedural_body_pose::Get_Status(InSelf.Get_BodyPose()) == ECk_ProceduralAnimation_Status::Failed ||
                Observations.ActionStreamFailed || utils_crawler::Get_IsAttackActionLost(InSelf) ||
                Get_HasActionStoppedOnItsOwn(Attack))
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::PoseFailed); }

            if (InSelf.Get_SupportRejection().IsSet())
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Unsupported); }
        }

        // The return cannot be waited for once the action's stream has failed or the action is gone.
        if (Attack.Phase == EMars_Crawler_AttackPhase::CancelRecover &&
            (Observations.ActionStreamFailed || utils_crawler::Get_IsAttackActionLost(InSelf)))
        { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::PoseFailed); }

        return TOptional<EMars_Crawler_AttackCancel>();
    }

    // The library interrupted the clip (support loss, a rejected pose, a watchdog) or finished it short of completion. A
    // completed clip returns to neutral on its own; the accepted Offense exit ends its offense instead.
    private bool Get_HasActionStoppedOnItsOwn(const FMars_Fragment_Crawler_Attack& InAttack) const
    {
        if (ck::Is_NOT_Valid(InAttack.Action) || InAttack.CancelRequested)
        { return false; }

        const auto State = InAttack.Action.Get_State();
        if (State == ECk_ProceduralAction_State::Cancelling)
        { return true; }

        return State == ECk_ProceduralAction_State::Finished &&
            InAttack.Action.Get_Result().Get_Outcome() != ECk_ProceduralAction_Outcome::Completed;
    }

    private void ApplyCancel(FCk_Handle_Crawler& InSelf, EMars_Crawler_AttackCancel InReason, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        const auto Phase = Attack.Phase;
        if (Phase == EMars_Crawler_AttackPhase::Idle)
        { return; }

        Attack.LastCancel = TOptional<EMars_Crawler_AttackCancel>(InReason);
        if (Attack.Result.RequiredPartFailures.Num() == 0)
        {
            const auto ObservedFailures = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).RequiredPartFailures;
            Attack.Result.RequiredPartFailures = ObservedFailures.Num() > 0 ? ObservedFailures : utils_crawler::Evaluate_AttackContinuation(InSelf);
        }
        InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Preparation = FMars_Attack_Preparation();
        auto CancelEvent = FMars_Attack_HistoryEntry();
        CancelEvent.Event = n"Cancelled";
        CancelEvent.AttackId = Attack.Plan.Entry.Identity.Id;
        CancelEvent.ActionIdentity = Attack.ActionIdentity;
        CancelEvent.Reason = FName(f"{InReason :n}");
        if (utils_crawler::Get_IsOffensivePhase(Phase))
        { RecordHistory(InSelf, CancelEvent); }
        if (InReason == EMars_Crawler_AttackCancel::PoseFailed && ck::IsValid(Attack.Action))
        {
            const auto Result = Attack.Action.Get_Result();
            Attack.LastActionOutcome = Result.Get_Outcome();
            Attack.LastActionReason = Result.Get_Reason();
        }

        if (utils_crawler::Get_IsOffensivePhase(Phase))
        {
            InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Candidate.Reset();
            if (Attack.Admission.Accepted)
            { Attack.CueInterrupted = true; }
            ++Attack.Generation;
            Attack.WindowClosed = true;
            utils_crawler::Cancel_AttackAction(InSelf);

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
            utils_crawler::Cancel_AttackAction(InSelf);
            EnterCooldown(InSelf, GetRecoverySeconds(InSelf), OutChanges);
        }
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
        auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        if (Observations.Candidate.IsSet() == false)
        { return; }

        const auto Candidate = Observations.Candidate.GetValue();
        Observations.Candidate.Reset();

        if (Get_IsCommittable(InSelf, Candidate) == false)
        { return; }

        const auto Hit = InSelf.Get_AttackPlan().Entry.Definition.Hit;
        auto Dealer = InSelf.Get_CombatDealer();
        FCk_Handle Root = InSelf;

        auto Event = utils_damage_dealer::Make_Event(Dealer, Hit.Damage, Hit.DamageType);
        Event.Source.Instigator = Root;
        Event.Source.Causer = Root;
        Event.Hit.Location = Candidate.Location;
        Event.Hit.Normal = Candidate.Normal;
        Event.Hit.Impulse = FVector::ZeroVector;
        Dealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(Candidate.HitEntity, Event));

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Attack.DamageCommitted = true;
        Attack.CommittedSampleId = Candidate.SampleId;
        Attack.CommittedEmitter = Candidate.EmitterContact;
    }

    private bool Get_IsCommittable(const FCk_Handle_Crawler& InSelf, const FMars_Crawler_HitCandidate& InCandidate)
    {
        const auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.DamageCommitted || InCandidate.Generation != Attack.Generation || InCandidate.Target != Attack.Target)
        { return false; }

        if (ck::Is_NOT_Valid(InSelf.Get_CombatDealer()) || ck::Is_NOT_Valid(InCandidate.Zone) || InCandidate.Zone.Get_IsEnabled() == false)
        { return false; }

        if (InSelf.Get_IsCombatTargetValid(Attack.Target) == false || InSelf.Get_IsCombatDead())
        { return false; }

        return Attack.Admission.Accepted && InSelf.Get_HurtCount() == Attack.HurtCountAtStart &&
            utils_crawler::Evaluate_AttackContinuation(InSelf).Num() == 0;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 3. Accepted phase
    //----------------------------------------------------------------------------------------------------------------------

    private void FollowAcceptedPhase(FCk_Handle_Crawler& InSelf, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        const auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);

        while (utils_crawler::Get_IsOffensivePhase(Attack.Phase) && int32(Attack.Phase) < int32(Observations.AcceptedPhase))
        { Enter(Attack, EMars_Crawler_AttackPhase(int32(Attack.Phase) + 1), OutChanges); }

        if (Attack.Phase == EMars_Crawler_AttackPhase::Recover && Observations.OffenseEnded)
        { EnterCooldown(InSelf, GetRecoverySeconds(InSelf), OutChanges); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 4. Admission
    //----------------------------------------------------------------------------------------------------------------------

    private void Admit(FCk_Handle_Crawler& InSelf, const FMars_Request_Crawler_StartAttack& InRequest, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        if (InSelf.Get_AttackPhase() != EMars_Crawler_AttackPhase::Idle)
        { Reject(InSelf, EMars_Crawler_AttackReject::Busy); return; }
        if (InRequest.Target != InSelf.Get_CombatTarget() || InSelf.Get_IsCombatTargetValid(InRequest.Target) == false)
        { Reject(InSelf, EMars_Crawler_AttackReject::TargetInvalid); return; }
        if (InSelf.Get_IsWarded(InRequest.Target))
        { Reject(InSelf, EMars_Crawler_AttackReject::Warded); return; }
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
            { Reject(InSelf, EMars_Crawler_AttackReject::AttackUnknown); return; }
            if (InRequest.SelectionGeneration != Advice.SelectionGeneration)
            { Reject(InSelf, EMars_Crawler_AttackReject::SelectionStale); return; }
            if (Advice.Selection.Selected.IsSet() == false || Advice.Selection.Selected.GetValue() != Id)
            { Reject(InSelf, EMars_Crawler_AttackReject::SelectionNotPermitted); return; }
        }
        auto Ready = false;
        for (const auto& Evaluation : Advice.Evaluations)
        { Ready = Ready || (Evaluation.AttackId == Id && Evaluation.Availability == EMars_Attack_Availability::Ready); }
        if (Ready == false)
        { Reject(InSelf, EMars_Crawler_AttackReject::NotReady); return; }
        auto Plan = FMars_Attack_ResolvedPlan();
        Plan.Entry = utils_crawler::Find_ResolvedAttack(InSelf.Get_Spec().ResolvedAttacks, Id).GetValue();
        Plan.Execution = InSelf.Get_Spec().ResolvedAttacks.Execution;
        Plan.GameRevision = InSelf.Get_Spec().ResolvedAttacks.GameRevision;
        Plan.Target = InRequest.Target;
        Plan.TargetGeneration = InSelf.Get_CombatTargetGeneration();
        Plan.SelectionGeneration = Advice.SelectionGeneration;
        if (utils_crawler::Create_AttackAction(InSelf, Plan) == false)
        { Reject(InSelf, EMars_Crawler_AttackReject::NotReady); return; }

        const auto Root = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());
        const auto Up = utils_surface_motion::Get_SupportNormal(InSelf.Get_Motion()).GetSafeNormal();
        const auto Forward = Root.GetRotation().GetForwardVector();
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(InSelf.Get_Presentation());
        const auto Neutral = utils_crawler::Get_HitCenter(Presentation, Plan.Entry.Definition.Hit.Emitters[0].LocalCenter);

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        ++Attack.Generation;
        Attack.Admission = FMars_Attack_Admission();
        Attack.Admission.AttackId = Plan.Entry.Identity.Id;
        Attack.Admission.ActionIdentity = Attack.ActionIdentity;
        Attack.Admission.AttemptGeneration = Attack.Generation;
        Attack.Admission.SelectionGeneration = Plan.SelectionGeneration;
        Attack.CueInterrupted = false;
        Attack.Result = FMars_Attack_Result();
        Attack.Result.AttackId = Plan.Entry.Identity.Id;
        Attack.Result.ActionIdentity = Attack.ActionIdentity;
        InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackSelection).Preparation = FMars_Attack_Preparation();
        Attack.LastReject.Reset();
        Attack.HurtCountAtStart = InSelf.Get_HurtCount();
        Attack.RootAtStart = Root.GetLocation();
        Attack.NeutralRootLocal = Presentation.GetRelativeTransform(Root);
        Attack.CommittedDirection = (Forward - Up * Forward.DotProduct(Up)).GetSafeNormal();
        Attack.Target = InRequest.Target;
        Attack.DamageCommitted = false;
        Attack.CommittedSampleId = 0;
        Attack.CommittedEmitter = FMars_Crawler_EmitterContact();
        Attack.WindowClosed = false;

        auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        Observations = FMars_Fragment_Crawler_AttackObservations();
        Observations.Candidate.Reset();
        Observations.Obstructed = false;
        Observations.Displaced.Reset();
        Observations.ActionStreamFailed = false;
        Observations.LongestSweep = 0.0f;
        Observations.PreviousHitCenter = Neutral;
        Observations.AcceptedHitCenter = Neutral;
        Observations.AckSampleId = 0;
        Observations.AcceptedInterval = FCk_ProceduralAction_Interval();
        Observations.AcceptedPhase = EMars_Crawler_AttackPhase::Idle;
        Observations.OffenseEnded = false;

        Enter(Attack, EMars_Crawler_AttackPhase::Windup, OutChanges);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 5. Settling
    //----------------------------------------------------------------------------------------------------------------------

    private void Settle(FCk_Handle_Crawler& InSelf, float32 InDeltaSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.Phase == EMars_Crawler_AttackPhase::CancelRecover && Attack.TerminalSeen)
        {
            EnterCooldown(InSelf, GetRecoverySeconds(InSelf), OutChanges);
            return;
        }

        if (Attack.Phase != EMars_Crawler_AttackPhase::Cooldown)
        { return; }

        Attack.CooldownRemaining = Math::Max(Attack.CooldownRemaining - InDeltaSeconds, 0.0f);
        if (Attack.CooldownRemaining > 0.0f)
        { return; }
        if (Attack.Cleanup.Released == false && utils_crawler::Forget_ReleasedAttackAction(InSelf) == false)
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
        Attack.Cleanup.Elapsed += InDeltaSeconds;
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

    private float32 GetRecoverySeconds(const FCk_Handle_Crawler& InSelf) const
    { return InSelf.Get_AttackAdmission().Accepted ? InSelf.Get_AttackPlan().Entry.Definition.Cooldown.RecoverySeconds : 0.0f; }

    private void Reject(FCk_Handle_Crawler& InSelf, EMars_Crawler_AttackReject InReason)
    {
        InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).LastReject = TOptional<EMars_Crawler_AttackReject>(InReason);
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
