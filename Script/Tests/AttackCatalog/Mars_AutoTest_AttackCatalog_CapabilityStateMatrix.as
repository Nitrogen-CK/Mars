class UMars_AutoTest_AttackCatalog_CapabilityStateMatrix : UMars_AutoTestRig_AttackCatalogPure
{
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("A02 independent anatomy capability and readiness facts", n"Step_Capability");
        Add_Step("A03 claimed parts imply requirements and braces stay unclaimed", n"Step_Prerequisites");
        Add_Step("A04 healthy unclaimed support capacity differs from temporary standing support", n"Step_Support");
        Add_Step("A07 every range, cooldown, stance and geometry blocker remains visible", n"Step_Readiness");
        Add_Step("A09 synthetic noncrawler observations exercise the same pure library", n"Step_Reuse");
        Run_Steps(InHandle);
    }

    private void Assert_Block(const FMars_Attack_EvaluationQuery& InQuery, EMars_Attack_BlockerCode InCode, EMars_Attack_Availability InExpected)
    {
        const auto Evaluation = utils_attack::Evaluate(InQuery);
        Assert_True(Evaluation.Availability == InExpected && utils_attack::Get_HasBlocker(Evaluation, InCode),
            f"{InCode :n} reports {InExpected :n} with its named reason");
    }

    UFUNCTION()
    private void Step_Capability(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Ready = Make_ReadyQuery();
        Assert_True(utils_attack::Evaluate(Ready).Availability == EMars_Attack_Availability::Ready, "healthy owned attached enabled anatomy is ready");
        auto Query = Ready;
        Query.Roles[0].Part.Live = false;
        Assert_Block(Query, EMars_Attack_BlockerCode::PartMissing, EMars_Attack_Availability::Unavailable);
        Query = Ready;
        Query.Roles[0].Part.PendingDestroy = true;
        Assert_Block(Query, EMars_Attack_BlockerCode::PartPendingDestroy, EMars_Attack_Availability::Unavailable);
        Query = Ready;
        Query.Roles[0].Part.OwnerMatches = false;
        Assert_Block(Query, EMars_Attack_BlockerCode::PartWrongOwner, EMars_Attack_Availability::Unavailable);
        Query = Ready;
        Query.Roles[0].Part.State = EMars_BodyPart_State::Severed;
        Assert_Block(Query, EMars_Attack_BlockerCode::PartSevered, EMars_Attack_Availability::Unavailable);
        Query.Roles[0].Part.State = EMars_BodyPart_State::Broken;
        Assert_Block(Query, EMars_Attack_BlockerCode::PartBroken, EMars_Attack_Availability::Unavailable);
        Query = Ready;
        Query.Roles[0].Part.Depleted = true;
        Assert_Block(Query, EMars_Attack_BlockerCode::PartDepleted, EMars_Attack_Availability::Unavailable);
        Query = Ready;
        Query.Roles[0].Limb.Enabled = false;
        Assert_Block(Query, EMars_Attack_BlockerCode::LimbDisabled, EMars_Attack_Availability::Unavailable);
        Query = Ready;
        Query.Roles[0].Limb.Attached = false;
        Assert_Block(Query, EMars_Attack_BlockerCode::LimbDetached, EMars_Attack_Availability::Unavailable);
        Query = Ready;
        Query.Roles[0].Part.Condition = EMars_BodyPart_Condition::Ruined;
        Assert_True(utils_attack::Evaluate(Query).Availability == EMars_Attack_Availability::Ready, "default Ruined ceiling preserves capability");
        Query.Entry.Slots[0].MaxCondition = EMars_BodyPart_Condition::Damaged;
        Assert_Block(Query, EMars_Attack_BlockerCode::ConditionDisallowed, EMars_Attack_Availability::Unavailable);
        Query = Ready;
        Query.Roles[0].Limb.Control = ECk_ProceduralLimbControl_State::Controlled;
        Assert_Block(Query, EMars_Attack_BlockerCode::ControlBusy, EMars_Attack_Availability::Waiting);
        Query.Roles[0].Limb.Control = ECk_ProceduralLimbControl_State::Returning;
        Assert_Block(Query, EMars_Attack_BlockerCode::LimbReturning, EMars_Attack_Availability::Waiting);
        Query.Roles[0].Limb.Control = ECk_ProceduralLimbControl_State::Unplanted;
        Assert_Block(Query, EMars_Attack_BlockerCode::LimbUnplanted, EMars_Attack_Availability::Waiting);
    }

    UFUNCTION()
    private void Step_Prerequisites(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = Make_ReadyQuery();
        Assert_Equals_Int(Query.Entry.Parts.Num(), 0, "a claimed slot needs no redundant authored part requirement");
        Query.Roles[0].Part.Depleted = true;
        Assert_Block(Query, EMars_Attack_BlockerCode::PartDepleted, EMars_Attack_Availability::Unavailable);
        Query = Make_ReadyQuery();
        auto Brace = FMars_Attack_ResolvedPart();
        Brace.Binding = Make_Binding(GameplayTags::AttackRole_Mars_Test_Brace, n"Brace0");
        Query.Entry.Parts.Add(Brace);
        Query.Roles.Add(Make_HealthyRole(Brace.Binding));
        Query.Roles[1].Limb.Control = ECk_ProceduralLimbControl_State::Controlled;
        Assert_True(utils_attack::Evaluate(Query).Availability == EMars_Attack_Availability::Ready,
            "an extra prerequisite is checked for capability without promising control ownership");
        Query.Roles[1].Part.State = EMars_BodyPart_State::Broken;
        Assert_Block(Query, EMars_Attack_BlockerCode::PartBroken, EMars_Attack_Availability::Unavailable);
    }

    UFUNCTION()
    private void Step_Support(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = Make_ReadyQuery();
        auto Locomotion = Query.Execution.Locomotion;
        Locomotion.Set_Support(FCk_ProceduralLimbControl_Support(ECk_ProceduralLimbControl_SupportMode::CountOnly, 2));
        Query.Execution.Locomotion = Locomotion;
        Query.Self.SupportLimbs.Add(Make_Support(n"Jaw0"));
        Query.Self.SupportLimbs.Add(Make_Support(n"Leg1"));
        Query.Self.SupportLimbs.Add(Make_Support(n"Leg2"));
        const auto Ready = utils_attack::Evaluate(Query);
        Assert_True(Ready.EnabledSupport == 2 && Ready.StandingSupport == 2 && Ready.Availability == EMars_Attack_Availability::Ready,
            "the claimed limb is excluded from capacity and standing counts");
        Query.Self.SupportLimbs[2].Limb.Planted = false;
        auto Evaluation = utils_attack::Evaluate(Query);
        Assert_True(Evaluation.EnabledSupport == 2 && Evaluation.StandingSupport == 1 && Evaluation.Capable,
            "ordinary gait swing changes readiness without changing capacity");
        Assert_Block(Query, EMars_Attack_BlockerCode::SupportStance, EMars_Attack_Availability::Waiting);
        Query.Self.SupportLimbs[2].Limb.Planted = true;
        Query.Self.SupportLimbs[2].Limb.Control = ECk_ProceduralLimbControl_State::Returning;
        Evaluation = utils_attack::Evaluate(Query);
        Assert_True(Evaluation.EnabledSupport == 2 && Evaluation.StandingSupport == 1 && Evaluation.Capable,
            "temporary borrowed/returning support is Waiting, not missing capability");
        Query.Self.SupportLimbs[2].Limb.Control = ECk_ProceduralLimbControl_State::Default;
        Query.Self.SupportLimbs[2].Part.Depleted = true;
        Assert_Block(Query, EMars_Attack_BlockerCode::SupportCapacity, EMars_Attack_Availability::Unavailable);
        Query.Self.SupportLimbs[2].Part.Depleted = false;
        Query.Self.SupportLimbs[2].Part.OwnerMatches = false;
        Assert_Block(Query, EMars_Attack_BlockerCode::SupportCapacity, EMars_Attack_Availability::Unavailable);
        Query.Self.SupportLimbs[2].Part.OwnerMatches = true;
        Query.Self.SupportLimbs[2].Part.State = EMars_BodyPart_State::Severed;
        Assert_Block(Query, EMars_Attack_BlockerCode::SupportCapacity, EMars_Attack_Availability::Unavailable);
        Query.Self.SupportLimbs[2].Part.State = EMars_BodyPart_State::Attached;
        Query.Self.SupportLimbs[2].Limb.Trusted = false;
        Assert_Block(Query, EMars_Attack_BlockerCode::SupportStance, EMars_Attack_Availability::Waiting);
    }

    UFUNCTION()
    private void Step_Readiness(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = Make_ReadyQuery();
        Query.Entry.Definition.Prepare.MinDistance = 10.0f;
        Query.Target.Distance = 5.0f;
        Assert_Block(Query, EMars_Attack_BlockerCode::TooClose, EMars_Attack_Availability::Waiting);
        Query.Target.Distance = 150.0f;
        Query.Target.HeightDifference = 70.0f;
        Query.Target.FacingDegrees = 30.0f;
        Query.Self.State.RootSpeed = 20.0f;
        Query.Self.State.Grounded = false;
        Query.Self.State.SlopeDegrees = 80.0f;
        Query.Cooldown.EntryRemaining = 1.0f;
        Query.Cooldown.GlobalRemaining = 2.0f;
        Query.Self.WindupClear = false;
        const auto Evaluation = utils_attack::Evaluate(Query);
        Assert_True(Evaluation.Capable && Evaluation.Availability == EMars_Attack_Availability::Waiting, "temporary blockers preserve capability");
        auto Codes = TArray<EMars_Attack_BlockerCode>();
        Codes.Add(EMars_Attack_BlockerCode::OutOfRange);
        Codes.Add(EMars_Attack_BlockerCode::Height);
        Codes.Add(EMars_Attack_BlockerCode::Facing);
        Codes.Add(EMars_Attack_BlockerCode::Moving);
        Codes.Add(EMars_Attack_BlockerCode::Ungrounded);
        Codes.Add(EMars_Attack_BlockerCode::Slope);
        Codes.Add(EMars_Attack_BlockerCode::Cooldown);
        Codes.Add(EMars_Attack_BlockerCode::GlobalCooldown);
        Codes.Add(EMars_Attack_BlockerCode::WindupBlocked);
        for (const auto Code : Codes)
        { Assert_True(utils_attack::Get_HasBlocker(Evaluation, Code), f"all applicable checks retain [{Code :n}]"); }
    }

    UFUNCTION()
    private void Step_Reuse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Query = Make_ReadyQuery();
        Query.Entry.Identity.Id = GameplayTags::Attack_Mars_Test_SerpentBite;
        Query.Roles[0].Role = GameplayTags::AttackRole_Mars_Test_SerpentJaw;
        Query.Roles[0].LimbId = n"MandibleA";
        Query.Entry.Slots[0].Binding.Role = GameplayTags::AttackRole_Mars_Test_SerpentJaw;
        Query.Entry.Slots[0].Binding.LimbId = n"MandibleA";
        const auto Evaluation = utils_attack::Evaluate(Query);
        Assert_True(Evaluation.AttackId == GameplayTags::Attack_Mars_Test_SerpentBite && Evaluation.Availability == EMars_Attack_Availability::Ready,
            "a synthetic noncrawler morphology uses copied data with no entity registry, crawler handles or live query");
        const auto Before = Evaluation;
        Query.Roles.Insert(Make_HealthyRole(Make_Binding(GameplayTags::AttackRole_Mars_Test_Unrelated, n"ExtraLimb")), 0);
        const auto After = utils_attack::Evaluate(Query);
        Assert_True(Before.Availability == After.Availability && After.Blockers.Num() == 0,
            "anatomy observation record ordering cannot reassign a stable role");
    }
}
