// One phase change, broadcast once the tick has written everything.
struct FMars_Crawler_AttackPhaseChange
{
    EMars_Crawler_AttackPhase Old = EMars_Crawler_AttackPhase::Idle;
    EMars_Crawler_AttackPhase New = EMars_Crawler_AttackPhase::Idle;
}

// The attack's one clock (armed crawlers only). Every tick runs a fixed pass:
//   1. cancellation: the queued cancel, then the resolver's displacement and obstruction, then the direct guards (Dead,
//      Hurt, Crippled, TargetLost, PoseFailed, Unsupported), then the pose timeout; the first reason wins. An offensive
//      phase (Windup, Strike, Recover) drops its candidate, bumps the generation and eases back from the last requested
//      offset in CancelRecover; Dead, PoseFailed and Disabled go straight to neutral and Cooldown. A cancel during
//      CancelRecover or Cooldown changes nothing but LastCancel, except a pose timeout, which ends the wait;
//   2. commit: a surviving candidate of this generation on the live, enabled, undepleted target, with the crawler alive
//      and unhurt since admission, becomes the attack's one damage request;
//   3. endpoint: the resolver's acknowledgment of the pending sample; an acknowledged endpoint enters the next phase and
//      the rest of this tick's time is discarded (a hitch never skips a phase). A sample still unacknowledged keeps its
//      phase clock still and runs the pose timeout instead;
//   4. admission of a queued start (from Idle only; anything else records the reason in LastReject);
//   5. pose: advance the phase clock, evaluate the authored offset and submit it as one new body pose sample, or in
//      Cooldown submit identity once and count down.
// A tick with no positive time runs step 1 only. The acknowledgment is the published sample, never the request's
// completion.
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

        const auto PoseHeld = ConsumeAcknowledgment(InSelf, InDeltaSeconds, OutChanges);

        if (StartIntent.IsSet())
        {
            auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
            if (CancelIntent.IsSet())
            { Attack.LastReject = TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::CancelPending); }
            else
            { Admit(InSelf, StartIntent.GetValue(), OutChanges); }
        }

        if (PoseHeld)
        { return; }

        Pose(InSelf, InDeltaSeconds, OutChanges);
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

            if (utils_procedural_body_pose::Get_Status(InSelf.Get_BodyPose()) == ECk_ProceduralAnimation_Status::Failed)
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::PoseFailed); }

            if (InSelf.Get_SupportRejection().IsSet())
            { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::Unsupported); }
        }

        if (Attack.PendingSampleId != 0 && Attack.PoseTimeoutElapsed > Spec.Combat.Timing.PoseTimeoutSeconds)
        { return TOptional<EMars_Crawler_AttackCancel>(EMars_Crawler_AttackCancel::PoseTimeout); }

        return TOptional<EMars_Crawler_AttackCancel>();
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
            Attack.PendingSampleId = 0;
            Attack.PoseTimeoutElapsed = 0.0f;
            Attack.WindowClosed = true;

            const auto SkipsRecovery = InReason == EMars_Crawler_AttackCancel::Dead || InReason == EMars_Crawler_AttackCancel::PoseFailed ||
                InReason == EMars_Crawler_AttackCancel::Disabled;
            if (SkipsRecovery)
            {
                EnterNeutralCooldown(InSelf, 0.0f, OutChanges);
                return;
            }

            Attack.CancelRecoverStart = Attack.RequestedActionOffset;
            Enter(Attack, EMars_Crawler_AttackPhase::CancelRecover, OutChanges);
            return;
        }

        if (InReason != EMars_Crawler_AttackCancel::PoseTimeout)
        { return; }

        if (Phase == EMars_Crawler_AttackPhase::CancelRecover)
        {
            EnterNeutralCooldown(InSelf, InSelf.Get_Spec().Combat.Timing.CooldownSeconds, OutChanges);
            return;
        }

        // Cooldown: the neutral sample is abandoned, so the cooldown can finish.
        Attack.PendingSampleId = 0;
        Attack.PoseTimeoutElapsed = 0.0f;
    }

    // Identity once, if the body pose still admits it, then Cooldown with no further neutral sample.
    private void EnterNeutralCooldown(FCk_Handle_Crawler& InSelf, float32 InCooldownSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        const auto SampleId = Submit(InSelf, FTransform::Identity);

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Attack.PendingSampleId = SampleId;
        Attack.PoseTimeoutElapsed = 0.0f;
        Attack.NeutralSubmitted = true;
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
    // 3. Endpoint
    //----------------------------------------------------------------------------------------------------------------------

    // True when this tick poses nothing more: a phase just ended on its acknowledged endpoint, or the pending sample is
    // still unacknowledged.
    private bool ConsumeAcknowledgment(FCk_Handle_Crawler& InSelf, float32 InDeltaSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.PendingSampleId == 0)
        { return false; }

        if (InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).AckSampleId != Attack.PendingSampleId)
        {
            Attack.PoseTimeoutElapsed += InDeltaSeconds;
            return true;
        }

        Attack.PendingSampleId = 0;
        Attack.PoseTimeoutElapsed = 0.0f;
        if (Attack.EndpointSubmitted == false)
        { return false; }

        switch (Attack.Phase)
        {
            case EMars_Crawler_AttackPhase::Windup:
                Enter(Attack, EMars_Crawler_AttackPhase::Strike, OutChanges);
                break;
            case EMars_Crawler_AttackPhase::Strike:
                Enter(Attack, EMars_Crawler_AttackPhase::Recover, OutChanges);
                break;
            default:
                Enter(Attack, EMars_Crawler_AttackPhase::Cooldown, OutChanges);
                Attack.CooldownRemaining = InSelf.Get_Spec().Combat.Timing.CooldownSeconds;
                Attack.NeutralSubmitted = false;
                break;
        }

        return true;
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

        const auto Root = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());
        const auto Up = utils_surface_motion::Get_SupportNormal(InSelf.Get_Motion()).GetSafeNormal();
        const auto Forward = Root.GetRotation().GetForwardVector();
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(InSelf.Get_Presentation());
        const auto Neutral = utils_crawler::Get_HitCenter(Presentation, InSelf.Get_Spec().Combat.Hit.LocalCenter);

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        ++Attack.Generation;
        Attack.HurtCountAtStart = InSelf.Get_HurtCount();
        Attack.RootAtStart = Root.GetLocation();
        Attack.CommittedDirection = (Forward - Up * Forward.DotProduct(Up)).GetSafeNormal();
        Attack.Target = InRequest.Target;
        Attack.DamageCommitted = false;
        Attack.CommittedSampleId = 0;
        Attack.WindowClosed = false;
        Attack.PendingSampleId = 0;
        Attack.PoseTimeoutElapsed = 0.0f;
        Attack.RequestedActionOffset = FTransform::Identity;

        auto& Observations = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
        Observations.Candidate.Reset();
        Observations.Obstructed = false;
        Observations.Displaced.Reset();
        Observations.LongestSweep = 0.0f;
        Observations.PreviousHitCenter = Neutral;
        Observations.AcceptedHitCenter = Neutral;

        Enter(Attack, EMars_Crawler_AttackPhase::Windup, OutChanges);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 5. Pose
    //----------------------------------------------------------------------------------------------------------------------

    private void Pose(FCk_Handle_Crawler& InSelf, float32 InDeltaSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        const auto Combat = InSelf.Get_Spec().Combat;
        const auto Phase = InSelf.Get_AttackPhase();

        if (Phase == EMars_Crawler_AttackPhase::Idle)
        { return; }

        if (Phase == EMars_Crawler_AttackPhase::Cooldown)
        {
            CoolDown(InSelf, InDeltaSeconds, OutChanges);
            return;
        }

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        const auto Duration = utils_crawler::Make_PhaseDuration(Combat.Timing, Phase);
        Attack.PhaseElapsed = Math::Min(Attack.PhaseElapsed + InDeltaSeconds, Duration);
        const auto Alpha = Attack.PhaseElapsed / Duration;
        const auto Offset = utils_crawler::Evaluate_ActionOffset(Combat.Pose, FMars_Crawler_PoseQuery(Phase, Alpha, Attack.CancelRecoverStart));
        const auto Endpoint = Attack.PhaseElapsed >= Duration;

        const auto SampleId = Submit(InSelf, Offset);
        if (SampleId != 0)
        {
            auto& Submitted = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
            Submitted.PendingSampleId = SampleId;
            Submitted.EndpointSubmitted = Endpoint;
            return;
        }

        // The body pose no longer admits input: an offensive phase ends as PoseFailed, a recovery stops waiting.
        if (Phase == EMars_Crawler_AttackPhase::CancelRecover)
        {
            EnterNeutralCooldown(InSelf, Combat.Timing.CooldownSeconds, OutChanges);
            return;
        }

        ApplyCancel(InSelf, EMars_Crawler_AttackCancel::PoseFailed, OutChanges);
    }

    private void CoolDown(FCk_Handle_Crawler& InSelf, float32 InDeltaSeconds, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.NeutralSubmitted == false)
        {
            Attack.NeutralSubmitted = true;
            const auto SampleId = Submit(InSelf, FTransform::Identity);
            InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).PendingSampleId = SampleId;
        }

        auto& Cooling = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Cooling.CooldownRemaining = Math::Max(Cooling.CooldownRemaining - InDeltaSeconds, 0.0f);
        if (Cooling.CooldownRemaining <= 0.0f && Cooling.PendingSampleId == 0)
        { Enter(Cooling, EMars_Crawler_AttackPhase::Idle, OutChanges); }
    }

    // One body pose sample with a fresh id; 0 (and nothing sent) when the body pose no longer admits input.
    private int64 Submit(FCk_Handle_Crawler& InSelf, FTransform InOffset)
    {
        auto BodyPose = InSelf.Get_BodyPose();
        if (ck::Is_NOT_Valid(BodyPose) || utils_procedural_body_pose::Get_Status(BodyPose) == ECk_ProceduralAnimation_Status::Failed)
        { return 0; }

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        ++Attack.NextSampleId;
        Attack.RequestedActionOffset = InOffset;
        utils_procedural_body_pose::Request_SetActionOffset(BodyPose, FCk_Request_ProceduralBodyPose_SetActionOffset(InOffset, Attack.NextSampleId));
        return Attack.NextSampleId;
    }

    private void Enter(FMars_Fragment_Crawler_Attack& InOutAttack, EMars_Crawler_AttackPhase InPhase, TArray<FMars_Crawler_AttackPhaseChange>& OutChanges)
    {
        auto Change = FMars_Crawler_AttackPhaseChange();
        Change.Old = InOutAttack.Phase;
        Change.New = InPhase;
        OutChanges.Add(Change);

        InOutAttack.Phase = InPhase;
        InOutAttack.PhaseElapsed = 0.0f;
        InOutAttack.EndpointSubmitted = false;
    }
}
