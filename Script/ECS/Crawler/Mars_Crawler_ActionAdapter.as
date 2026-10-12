// The crawler owns damage, cooldown and cancellation policy. This adapter plays the jab's clip as one scoped action with
// explicit receipt delivery (the resolver needs every accepted interval): the clip is rebuilt at every admission into the
// clip object the entity script owns, with a claw slot bound to each front leg a pincer claims, homed on where that foot
// stands. It cancels the action, and releases it after the copied terminal stream has been acknowledged; a released
// pincer asks the gait to take back any claw its return left unplanted.
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

    // Asks the gait to take back every limb an earlier action's return left unplanted (the return ran out of time or of
    // landing probes). Sent when a pincer's action is released and again before the next attack's action is created, when
    // the crawler stands still: a leg left out of the gait is never the last word.
    void Recover_UnplantedLimbs(FCk_Handle_Crawler& InSelf)
    {
        auto Root = InSelf.As_Transform();
        auto Subject = utils_procedural_articulation::DoCastChecked(Root);
        if (utils_procedural_articulation::Get_UnplantedLimbIds(Subject).Num() > 0)
        { utils_procedural_articulation::Request_RecoverUnplantedLimbs(Subject, FCk_Request_ProceduralArticulation_RecoverUnplantedLimbs()); }
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

    // Recovers unplanted limbs, finds the claws, homes each on its foot in the root's frame, builds the clip into the
    // spec's clip object and plays it with the claw slots bound to their legs. False (nothing created) without a player
    // or clip object, on a builder rejection (an ensure naming the first diagnostic) or when the action is not created.
    bool Create_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        const auto Player = InSelf.Get_ActionPlayer();
        const auto Spec = InSelf.Get_Spec();
        auto Clip = Spec.Combat.AttackClip.Get();
        if (ck::Is_NOT_Valid(Player) || ck::Is_NOT_Valid(Clip))
        { return false; }

        Recover_UnplantedLimbs(InSelf);

        auto Build = FMars_Crawler_ClipBuild();
        Build.Combat = Spec.Combat;
        Build.Claws = Find_AttackClaws(InSelf);
        const auto RootAtAdmission = utils_transform::Get_EntityCurrentTransform(InSelf.As_Transform());
        for (auto& Claw : Build.Claws)
        {
            const auto Foot = utils_procedural_leg::Get_Foot(Claw.Leg);
            Claw.Home = TOptional<FVector>(RootAtAdmission.InverseTransformPosition(Foot.Get_Position()));
        }

        const auto Report = Build_AttackClip(Build, Clip);
        if (ck::EnsureIfNot(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            f"[Crawler] [{InSelf.ToString()}] the attack clip did not build: {Get_FirstDiagnosticText(Report)}"))
        { return false; }

        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        for (const auto& Claw : Build.Claws)
        { Bindings.Add(FCk_ProceduralAction_SlotBinding(Get_ClawSlotId(Claw), Claw.LegId)); }

        auto PlaySpec = FCk_ProceduralAction_LoadedPlaySpec(Clip);
        PlaySpec.Set_SlotBindings(Bindings);
        PlaySpec.Set_Tuning(Make_AttackTuning(Spec));

        FCk_Handle Owner = InSelf;
        auto Scope = utils_entity_lifetime::Request_CreateEntity(Owner);
        const auto Action = utils_procedural_action::Create_FromLoadedClip(Scope, Player, PlaySpec);
        if (ck::Is_NOT_Valid(Action))
        {
            utils_entity_lifetime::Request_DestroyEntity(Scope);
            return false;
        }

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Attack.ActionScope = Scope;
        Attack.Action = Action;
        Attack.ActionIdentity = Action.Get_Identity();
        Attack.Claws = Build.Claws;
        Attack.ReceiptCursor = 0;
        Attack.CancelRequested = false;
        Attack.TerminalSeen = false;
        Attack.TerminalConsumeIssued = false;
        Attack.TerminalConsumeSucceeded = false;
        return true;
    }

    // Once per attack; the action's own return owns neutralization from wherever the body and the claws are.
    void Cancel_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.CancelRequested || Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action) ||
            Attack.Action.Get_State() == ECk_ProceduralAction_State::Finished)
        { return; }

        Attack.CancelRequested = true;
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
        const auto HeldClaws = Attack.Claws.Num() > 0;
        Attack.Claws.Empty();
        if (HeldClaws)
        { Recover_UnplantedLimbs(InSelf); }
        return true;
    }
}
