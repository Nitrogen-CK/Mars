// Losing legs below MinLegsToWalk cripples: a roaming 4-leg crawler (MinLegsToWalk 3) has legs 0 and 1 depleted through
// their Health (30 Sever each); both sever, the gait reports 2 of 4 enabled, the crawler's setup writes CanWalk false
// through the brain, the only plan is [Cower], and the behaviour sub-SM reaches Cower (the first sever may pass through
// Flinch on the way: the test waits for Cower, not for the path). CanWalk reads false, the navigator is Idle and the
// body stays within 50 uu of where it cowered for 2 s.
//
// Spawned through the real entity script onto a runtime static Jolt floor (no nav field: straight-line moves).
// Isolated origin (150000, 88000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_Crawler_CrippledCowers : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    private FVector _Origin = FVector(150000.0, 88000.0, 600.0);
    private FCk_Handle_Crawler _Crawler;
    private FVector _CowerLocation;
    private float64 _CowerAt = 0.0;
    private float64 _WorstDrift = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed and its gait Ready", n"Check_Ready", 0, 10.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_InRoam", 0, 5.0f);
        Add_Step("deplete legs 0 and 1 through their Health", n"Step_DepleteTwoLegs");
        Add_Step_WaitUntil("both legs are severed", n"Check_BothSevered", 0, 3.0f);
        Add_Step_WaitUntil("the behaviour sub-SM reaches Cower", n"Check_InCower", 0, 3.0f);
        Add_Step("CanWalk is false, the leaf is Cower and the navigator Idle", n"Step_AssertCowering");
        Add_Step_WaitUntil("the body holds within 50 uu for 2 s", n"Check_HoldsStill", 0, 4.0f);
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared rig (one scenario per file: copied, not shared)
    //----------------------------------------------------------------------------------------------------------------------

    private FMars_Crawler_Spec Make_Spec()
    {
        const auto Half = FVector(300.0, 300.0, 200.0);
        auto Spec = FMars_Crawler_Spec(4, FBox(_Origin - Half, _Origin + Half));
        Spec.RoamDwellSeconds = 0.3f;
        Spec.MinLegsToWalk = 3;
        // The severed limbs are world-owned; they must die on their debris timer before the 2 s hold ends (no leak).
        Spec.Vitals.LegDebris.LifetimeSeconds = 1.0f;
        return Spec;
    }

    private void SpawnFloorAndCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(1500.0, 1500.0, 10.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        auto SpawnParams = UMars_Crawler_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        SpawnParams.Spec = InSpec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Crawler_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnCrawlerConstructed"));
    }

    UFUNCTION()
    private void OnCrawlerConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Crawler = FCk_Handle(InEntityScriptHandle).As_Crawler(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Crawler))
        {
            Res.Set(false);
            return;
        }

        const auto Gait = _Crawler.Get_Gait();
        if (utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Failed)
        {
            FinishFailure(f"the crawler's gait failed: {utils_procedural_gait::Get_Failure(Gait) :n}");
            return;
        }

        Res.Set(utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Ready);
    }

    private FVector BodyLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(utils_transform::DoCastChecked(FCk_Handle(_Crawler)));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_InRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam);
    }

    UFUNCTION()
    private void Step_DepleteTwoLegs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Sever = GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Sever");
        for (int32 Index = 0; Index < 2; ++Index)
        {
            auto Health = _Crawler.Get_LegParts()[Index].Get_Health();
            Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(30.0f, Sever)));
        }
    }

    UFUNCTION()
    private void Check_BothSevered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Parts = _Crawler.Get_LegParts();
        Res.Set(Parts[0].Get_State() == EMars_BodyPart_State::Severed && Parts[1].Get_State() == EMars_BodyPart_State::Severed);
    }

    UFUNCTION()
    private void Check_InCower(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Cower);
    }

    UFUNCTION()
    private void Step_AssertCowering(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Brain = _Crawler.Get_Brain();
        Assert_False(Brain.Get_Fact(GameplayTags::ResolveGameplayTag(n"Mars.WS.Crawler.CanWalk")), "CanWalk reads false");
        Assert_True(Brain.Get_LeafClass() == UMars_GoapAction_Crawler_Cower, "the brain's leaf is Cower");
        Assert_Equals_Int(utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait()), 2, "the gait has 2 legs enabled");
        Assert_True(_Crawler.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Idle, "the navigator is Idle");

        _CowerLocation = BodyLocation();
        _CowerAt = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Check_HoldsStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _WorstDrift = Math::Max(_WorstDrift, (BodyLocation() - _CowerLocation).Size2D());
        if (_WorstDrift > 50.0)
        {
            FinishFailure(f"the cowering body drifted {_WorstDrift} uu");
            return;
        }

        if (_Crawler.Get_BehaviorStateClass() != UMars_SmState_Crawler_Cower)
        {
            FinishFailure("the crawler left Cower while crippled");
            return;
        }

        Res.Set(System::GetGameTimeInSeconds() - _CowerAt >= 2.0);
    }
}
