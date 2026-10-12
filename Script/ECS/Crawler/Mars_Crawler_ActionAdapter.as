// The crawler owns the phase clock and damage policy. This adapter only translates its body offsets, and the pincer's
// claw points, to one scoped public manual action and releases that action after the copied terminal stream has been
// acknowledged.
namespace utils_crawler
{
    // A crawler lifting both claws keeps at least this many enabled legs on the ground.
    const int32 PincerMinStandingLegs = 2;

    // How long the gait may take to step a released claw back onto the ground before the leg is given up as unplanted.
    const float32 PincerReturnTimeoutSeconds = 3.0f;

    bool Get_IsAttackActionLost(const FCk_Handle_Crawler& InSelf)
    {
        const auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        FCk_Handle Scope = Attack.ActionScope;
        FCk_Handle Action = Attack.Action;
        return Attack.ActionIdentity.Get_Value() != 0 &&
            (ck::Is_NOT_Valid(Action) || ck::Is_NOT_Valid(Scope) ||
                utils_entity_lifetime::Get_IsPendingDestroy(Action, ECk_EntityLifetime_DestructionPhase::BeginDestroy) ||
                utils_entity_lifetime::Get_IsPendingDestroy(Scope, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    // Asks the gait to take back every attached leg an earlier action's return left unplanted (the return ran out of time
    // or of landing probes). Sent when an attack's action is released and again before the next one is created, when the
    // crawler stands still: a leg left out of the gait is never the last word.
    void Recover_UnplantedLegs(FCk_Handle_Crawler& InSelf)
    {
        auto Root = InSelf.As_Transform();
        auto Subject = utils_procedural_articulation::DoCastChecked(Root);

        auto Unplanted = TArray<FName>();
        for (const auto& Part : InSelf.Get_LegParts())
        {
            FCk_Handle LegEntity = Part;
            if (ck::Is_NOT_Valid(LegEntity))
            { continue; }

            const auto Leg = LegEntity.As_ProceduralLeg(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Leg) || utils_procedural_leg::Get_IsAttached(Leg) == false)
            { continue; }

            const auto LegId = utils_procedural_leg::Get_Id(Leg);
            if (Subject.Get_LimbControl(LegId).Get_State() == ECk_ProceduralLimbControl_State::Unplanted)
            { Unplanted.Add(LegId); }
        }

        if (Unplanted.Num() > 0)
        { utils_procedural_articulation::Request_RecoverLimbs(Subject, FCk_Request_ProceduralArticulation_RecoverLimbs(Unplanted)); }
    }

    // The two front legs the pincer would claim, right (the rig's first leg) then left (its last); empty when the profile
    // has no pincer, when either front leg is gone, disabled or not the gait's to lend (still returning from, or left
    // unplanted by, an earlier action), or when lifting both would leave fewer than PincerMinStandingLegs enabled legs
    // standing. An empty answer is a body-only jab, never a rejected attack.
    TArray<FMars_Crawler_AttackClaw> Find_AttackClaws(const FCk_Handle_Crawler& InSelf)
    {
        auto Root = InSelf.As_Transform();
        const auto Subject = utils_procedural_articulation::DoCastChecked(Root);

        const auto Spec = InSelf.Get_Spec();
        const auto Parts = InSelf.Get_LegParts();
        if (Spec.Combat.Pincer.Enabled == false || Parts.Num() != Spec.LegCount)
        { return TArray<FMars_Crawler_AttackClaw>(); }

        if (utils_procedural_gait::Get_EnabledLegCount(InSelf.Get_Gait()) - 2 < PincerMinStandingLegs)
        { return TArray<FMars_Crawler_AttackClaw>(); }

        auto Indices = TArray<int32>();
        Indices.Add(0);
        Indices.Add(Parts.Num() - 1);

        auto Claws = TArray<FMars_Crawler_AttackClaw>();
        for (const auto Index : Indices)
        {
            FCk_Handle LegEntity = Parts[Index];
            if (ck::Is_NOT_Valid(LegEntity))
            { return TArray<FMars_Crawler_AttackClaw>(); }

            const auto Leg = LegEntity.As_ProceduralLeg(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Leg) || utils_procedural_leg::Get_Status(Leg) != ECk_ProceduralLeg_Status::Enabled)
            { return TArray<FMars_Crawler_AttackClaw>(); }

            const auto LegId = utils_procedural_leg::Get_Id(Leg);
            if (Subject.Get_LimbControl(LegId).Get_State() != ECk_ProceduralLimbControl_State::Default)
            { return TArray<FMars_Crawler_AttackClaw>(); }

            auto Claw = FMars_Crawler_AttackClaw();
            Claw.Leg = Leg;
            Claw.LegId = LegId;
            Claw.Side = Index == 0 ? 1.0f : -1.0f;
            Claws.Add(Claw);
        }

        return Claws;
    }

    // The enabled legs other than InClaws whose foot is planted on trusted ground: what would hold the crawler up with the
    // claws lifted, by the gait's own count (a swinging foot and a guessed plant hold nothing).
    int32 Count_StandingLegs(const FCk_Handle_Crawler& InSelf, const TArray<FMars_Crawler_AttackClaw>& InClaws)
    {
        int32 Standing = 0;
        for (const auto& Part : InSelf.Get_LegParts())
        {
            FCk_Handle LegEntity = Part;
            if (ck::Is_NOT_Valid(LegEntity))
            { continue; }

            const auto Leg = LegEntity.As_ProceduralLeg(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Leg) || utils_procedural_leg::Get_Status(Leg) != ECk_ProceduralLeg_Status::Enabled)
            { continue; }

            auto IsClaw = false;
            for (const auto& Claw : InClaws)
            { IsClaw = IsClaw || Claw.LegId == utils_procedural_leg::Get_Id(Leg); }

            const auto Foot = utils_procedural_leg::Get_Foot(Leg);
            if (IsClaw == false && Foot.Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted && Foot.Get_Contact() == ECk_ProceduralLeg_FootContact::Trusted)
            { ++Standing; }
        }

        return Standing;
    }

    // A pincer may start: every claw's own foot is planted (its home is then a spot on the ground, not a point of a step
    // in flight) and enough of the other legs stand to hold the crawler up without them.
    bool Get_IsPincerStanceReady(const FCk_Handle_Crawler& InSelf, const TArray<FMars_Crawler_AttackClaw>& InClaws)
    {
        for (const auto& Claw : InClaws)
        {
            if (utils_procedural_leg::Get_Foot(Claw.Leg).Get_Phase() != ECk_ProceduralLeg_FootPhase::Planted)
            { return false; }
        }

        return Count_StandingLegs(InSelf, InClaws) >= PincerMinStandingLegs;
    }

    bool Create_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        const auto Player = InSelf.Get_ActionPlayer();
        if (ck::Is_NOT_Valid(Player))
        { return false; }

        Recover_UnplantedLegs(InSelf);

        const auto Claws = Find_AttackClaws(InSelf);
        auto ClawIds = TArray<FName>();
        for (const auto& Claw : Claws)
        { ClawIds.Add(Claw.LegId); }

        FCk_Handle Owner = InSelf;
        auto Scope = utils_entity_lifetime::Request_CreateEntity(Owner);
        auto Control = FCk_ProceduralAction_ControlSpec(ClawIds);
        Control.Set_BodyChannel(ECk_EnableDisable::Enable);
        Control.Set_InputTimeout(FCk_Time(InSelf.Get_Spec().Combat.Timing.PoseTimeoutSeconds + 1.0f));
        const auto Action = utils_procedural_action::Create_Manual(Scope, Player, Control);
        if (ck::Is_NOT_Valid(Action))
        {
            utils_entity_lifetime::Request_DestroyEntity(Scope);
            return false;
        }

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Attack.ActionScope = Scope;
        Attack.Action = Action;
        Attack.ActionIdentity = Action.Get_Identity();
        Attack.Claws = Claws;
        Attack.ReceiptCursor = 0;
        Attack.EndRequested = false;
        Attack.TerminalSeen = false;
        Attack.TerminalConsumeIssued = false;
        Attack.TerminalConsumeSucceeded = false;
        return true;
    }

    // One complete batch for InQuery: the body offset and, for a pincer, a point for every claimed claw. A claw's home is
    // its planted foot on the first batch, the first moment the action owns the leg. Returns the batch's sample id, or 0
    // when the action admits no input; nothing is recorded then.
    int64 Submit_AttackPose(FCk_Handle_Crawler& InSelf, const FMars_Crawler_PoseQuery& InQuery)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action) ||
            Attack.Action.Get_State() != ECk_ProceduralAction_State::Ready ||
            Attack.EndRequested)
        { return 0; }

        const auto Combat = InSelf.Get_Spec().Combat;
        const auto Offset = Evaluate_ActionOffset(Combat.Pose, InQuery);
        const auto RootTransform = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());

        auto Claws = Attack.Claws;
        auto Targets = TArray<FCk_ProceduralAction_LimbTarget>();
        for (auto& Claw : Claws)
        {
            if (Claw.Home.IsSet() == false)
            {
                const auto Foot = utils_procedural_leg::Get_Foot(Claw.Leg);
                Claw.Home = TOptional<FVector>(RootTransform.InverseTransformPosition(Foot.Get_Position()));
            }

            Claw.Requested = Evaluate_ClawPoint(Combat, Claw, InQuery);
            Targets.Add(FCk_ProceduralAction_LimbTarget(Claw.LegId, FTransform(Claw.Requested)));
        }

        auto Batch = FCk_ProceduralAction_PoseBatch();
        Batch.Set_BodyChannel(ECk_EnableDisable::Enable);
        Batch.Set_BodyOffset(Offset);
        if (Targets.Num() > 0)
        { Batch.Set_Limbs(Targets); }

        const auto SampleId = Attack.NextSampleId + 1;
        auto Request = FCk_Request_ProceduralAction_SubmitPoseBatch(Batch);
        Request.Set_CorrelationToken(SampleId);
        const auto Enqueued = utils_procedural_action::Request_SubmitPoseBatch(Attack.Action, Request);
        if (ck::Is_NOT_Valid(Enqueued))
        { return 0; }

        Attack.NextSampleId = SampleId;
        Attack.RequestedActionOffset = Offset;
        Attack.Claws = Claws;
        return SampleId;
    }

    void End_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.EndRequested || Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action))
        { return; }

        Attack.EndRequested = true;
        Attack.Action.Request_End(FCk_Request_ProceduralAction_End());
    }

    void Cancel_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.EndRequested || Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action))
        { return; }

        Attack.EndRequested = true;
        Attack.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel());
    }

    bool Release_TerminalAttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.TerminalSeen == false || Attack.TerminalConsumeSucceeded == false ||
            (ck::IsValid(Attack.Action) && Attack.Action.Get_State() != ECk_ProceduralAction_State::Finished))
        { return false; }

        if (ck::IsValid(Attack.Action) && Get_IsAttackActionLost(InSelf) == false)
        { Attack.Action.Request_Release(FCk_Request_ProceduralAction_Release()); }
        if (ck::IsValid(Attack.ActionScope) &&
            utils_entity_lifetime::Get_IsPendingDestroy(Attack.ActionScope,
                ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
        { utils_entity_lifetime::Request_DestroyEntity(Attack.ActionScope); }
        Attack.Action = FCk_Handle_ProceduralAction();
        Attack.ActionScope = FCk_Handle();
        Attack.ActionIdentity = FCk_ProceduralAction_Identity();
        if (Attack.Claws.Num() > 0)
        { Recover_UnplantedLegs(InSelf); }
        Attack.Claws.Empty();
        return true;
    }
}
