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
//      dedicated return eases the body back while the attack waits in CancelRecover; Dead, PoseFailed and Disabled go
//      straight to Cooldown. A cancel during CancelRecover or Cooldown changes nothing but LastCancel, except a failed or
//      lost action in CancelRecover, which ends the wait;
//   2. commit: a surviving candidate of this generation on the live, enabled, undepleted target, with the crawler alive
//      and unhurt since admission, becomes the attack's one damage request;
//   3. accepted phase: each posed phase an accepted interval reached since the last tick is entered in order (a hitch
//      never skips one), and Recover ends in Cooldown once the accepted motion closed the Offense window;
//   4. admission of a queued start (from Idle only; anything else records the reason in LastReject);
//   5. settling: CancelRecover ends in Cooldown on the action's terminal record; Cooldown counts down and returns to Idle
//      once the terminal stream is acknowledged and the action released.
// A tick with no positive time runs step 1 only.
class UMars_Processor_Crawler_AttackTick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Crawler_HandleRequests");

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
        Tick(Self, float32(InDeltaT.Get_Seconds()), Changes);

        if (Changes.Num() == 0 || Self.Has_Fragment(FMars_Fragment_Crawler_Signals) == false)
        { return; }

        for (const auto& Change : Changes)
        { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackPhaseChanged.Broadcast(Self, Change.Old, Change.New); }
    }

    private void Tick(FCk_Handle_Crawler& InSelf, float32 InDeltaSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Intents = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackIntents);
        const auto StartIntent = Intents.PendingStart;
        const auto CancelIntent = Intents.PendingCancel;
        Intents.PendingStart.Reset();
        Intents.PendingCancel.Reset();

        const auto CancelReason = Find_CancelReason(InSelf, CancelIntent);

        auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        Observations.Displaced.Reset();
        Observations.Obstructed = false;

        if (CancelReason.IsSet())
        { ApplyCancel(InSelf, CancelReason.GetValue(), OutChanges); }

        if (InDeltaSeconds <= 0.0f)
        { return; }

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

        if (utils_crawler::Get_IsOffensivePhase(Phase))
        {
            InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Candidate.Reset();
            ++Attack.Generation;
            Attack.WindowClosed = true;
            utils_crawler::Cancel_AttackAction(InSelf);

            const auto SkipsRecovery = InReason == EMars_Crawler_AttackCancel::Dead || InReason == EMars_Crawler_AttackCancel::PoseFailed ||
                InReason == EMars_Crawler_AttackCancel::Disabled;
            if (SkipsRecovery)
            {
                EnterCooldown(InSelf, 0.0f, OutChanges);
                return;
            }

            Enter(InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack), EMars_Crawler_AttackPhase::CancelRecover, OutChanges);
            return;
        }

        if (Phase == EMars_Crawler_AttackPhase::CancelRecover && InReason == EMars_Crawler_AttackCancel::PoseFailed)
        {
            utils_crawler::Cancel_AttackAction(InSelf);
            EnterCooldown(InSelf, InSelf.Get_Spec().Combat.Timing.CooldownSeconds, OutChanges);
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

        const auto Hit = InSelf.Get_Spec().Combat.Hit;
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

        return InSelf.Get_HurtCount() == Attack.HurtCountAtStart;
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
        { EnterCooldown(InSelf, InSelf.Get_Spec().Combat.Timing.CooldownSeconds, OutChanges); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 4. Admission
    //----------------------------------------------------------------------------------------------------------------------

    private void Admit(FCk_Handle_Crawler& InSelf, const FMars_Request_Crawler_StartAttack& InRequest, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        const auto Rejection = InSelf.Get_StartRejection(InRequest.Target);
        if (Rejection.IsSet())
        {
            InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).LastReject = Rejection;
            return;
        }

        if (utils_crawler::Create_AttackAction(InSelf) == false)
        {
            InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).LastReject =
                TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::NotReady);
            return;
        }

        const auto Root = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());
        const auto Up = utils_surface_motion::Get_SupportNormal(InSelf.Get_Motion()).GetSafeNormal();
        const auto Forward = Root.GetRotation().GetForwardVector();
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(InSelf.Get_Presentation());
        const auto Neutral = utils_crawler::Get_HitCenter(Presentation, InSelf.Get_Spec().Combat.Hit.LocalCenter);

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        ++Attack.Generation;
        Attack.HurtCountAtStart = InSelf.Get_HurtCount();
        Attack.RootAtStart = Root.GetLocation();
        Attack.NeutralRootLocal = Presentation.GetRelativeTransform(Root);
        Attack.CommittedDirection = (Forward - Up * Forward.DotProduct(Up)).GetSafeNormal();
        Attack.Target = InRequest.Target;
        Attack.DamageCommitted = false;
        Attack.CommittedSampleId = 0;
        Attack.WindowClosed = false;

        auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
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
            EnterCooldown(InSelf, InSelf.Get_Spec().Combat.Timing.CooldownSeconds, OutChanges);
            return;
        }

        if (Attack.Phase != EMars_Crawler_AttackPhase::Cooldown)
        { return; }

        Attack.CooldownRemaining = Math::Max(Attack.CooldownRemaining - InDeltaSeconds, 0.0f);
        if (Attack.CooldownRemaining <= 0.0f && utils_crawler::Release_TerminalAttackAction(InSelf))
        { Enter(InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack), EMars_Crawler_AttackPhase::Idle, OutChanges); }
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
