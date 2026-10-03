// Death is a state, and the Dead state does the teardown: a roaming 4-leg crawler (CorpseSeconds 1.5, leg debris 1.0 s)
// takes 200 Blunt on its body zone; the body Health depletes, the monster dies (Dead = 1) and the root HFSM leaves Alive
// for Dead. Within 1 s of entering Dead the Die task has stopped the navigator, disabled the brain, severed all 4 still
// attached legs (4 OnSevered, the gait has 0 legs enabled) and disabled the body zone. The corpse timer then destroys the
// crawler root, the severed limbs (world-owned) die on their own debris timer, and the test's floor is untouched.
//
// Spawned through the real entity script onto a runtime static Jolt floor (no nav field: straight-line moves).
// Isolated origin (160000, 80000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_Crawler_DeathDetachesLegsAndDespawns : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    private FVector _Origin = FVector(160000.0, 80000.0, 600.0);
    private FCk_Handle _Floor;
    private FCk_Handle_Crawler _Crawler;
    private FCk_Handle _CrawlerRoot;

    private int32 _DiedCount = 0;
    private int32 _SeveredCount = 0;
    private TArray<FCk_Handle> _SeveredLegs;
    private TArray<FCk_Handle> _Debris;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed and its gait Ready", n"Check_Ready", 0, 10.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_InRoam", 0, 5.0f);
        Add_Step("bind OnDied and every part's OnSevered; hit the body zone with 200 Blunt", n"Step_BindAndKill");
        Add_Step_WaitUntil("the root state machine is in Dead", n"Check_InDead", 0, 3.0f);
        Add_Step_WaitUntil("the Die task tore the crawler down", n"Check_TornDown", 0, 1.0f);
        Add_Step("one death, four severs, no leg enabled", n"Step_AssertTeardown");
        Add_Step_WaitUntil("the corpse timer destroyed the crawler root", n"Check_RootDestroyed", 0, 2.5f);
        Add_Step("the severed limbs died on their own timer; the floor is untouched", n"Step_AssertDespawned");
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
        // Both overrides keep everything the death releases inside the test (no entity outlives it).
        Spec.Vitals.CorpseSeconds = 1.5f;
        Spec.Vitals.LegDebris.LifetimeSeconds = 1.0f;
        return Spec;
    }

    private void SpawnFloorAndCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec)
    {
        _Floor = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(_Floor, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(1500.0, 1500.0, 10.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(_Floor, FloorSpec);

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
        _CrawlerRoot = FCk_Handle(InEntityScriptHandle);
        _Crawler = _CrawlerRoot.As_Crawler(ECk_SanityCheck::UnChecked);
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

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        ++_DiedCount;
    }

    UFUNCTION()
    private void OnSevered(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased)
    {
        ++_SeveredCount;
        _SeveredLegs.Add(FCk_Handle(InPart));
        for (const auto& Released : InReleased)
        { _Debris.Add(FCk_Handle(Released)); }
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
    private void Step_BindAndKill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Monster = _Crawler.Get_Monster();
        Monster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnDied"));

        auto Parts = _Crawler.Get_LegParts();
        Assert_Equals_Int(Parts.Num(), 4, "the crawler has 4 leg parts");
        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            auto Part = Parts[Index];
            Part.BindTo_OnSevered(FMars_Delegate_BodyPart_OnSevered(this, n"OnSevered"));
        }

        auto BodyZone = Monster.Get_BodyZone();
        BodyZone.Request_Hit(FMars_Request_HitZone_Hit(
            FMars_DamageEvent(200.0f, GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Blunt"))));
    }

    UFUNCTION()
    private void Check_InDead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto RootMachine = _CrawlerRoot.As_StateMachine(ECk_SanityCheck::UnChecked);
        Res.Set(ck::IsValid(RootMachine) && utils_state_machine::IsInState(RootMachine, UMars_SmState_Crawler_Dead));
    }

    UFUNCTION()
    private void Check_TornDown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Crawler))
        {
            FinishFailure("the crawler root died before the teardown was observed");
            return;
        }

        auto Severed = 0;
        for (auto Part : _Crawler.Get_LegParts())
        {
            if (ck::IsValid(Part) && Part.Get_State() == EMars_BodyPart_State::Severed)
            { ++Severed; }
        }

        Res.Set(_Crawler.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Idle &&
            _Crawler.Get_Brain().Get_IsEnabled() == false &&
            Severed == 4 && _SeveredCount == 4 &&
            utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait()) == 0 &&
            _Crawler.Get_Monster().Get_BodyZone().Get_IsEnabled() == false);
    }

    UFUNCTION()
    private void Step_AssertTeardown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Monster = _Crawler.Get_Monster();
        Assert_True(Monster.Get_IsDead(), "the monster is dead");
        Assert_Equals_Int(_DiedCount, 1, "OnDied fired once");
        Assert_Equals_Int(_SeveredCount, 4, "OnSevered fired for each of the 4 legs");
        Assert_Equals_Int(Monster.Get_AttachedPartCount(), 0, "no part is still attached");
        Assert_Equals_Int(_Debris.Num(), 12, "each leg released its 2 segments and its foot");
        Assert_True(Monster.Get_BodyHealth().Get_IsDepleted(), "the body Health is depleted");
        Assert_True(ck::IsValid(_CrawlerRoot), "the corpse is still there before CorpseSeconds");
    }

    UFUNCTION()
    private void Check_RootDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_CrawlerRoot));
    }

    UFUNCTION()
    private void Step_AssertDespawned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < _SeveredLegs.Num(); ++Index)
        { Assert_True(ck::Is_NOT_Valid(_SeveredLegs[Index]), f"severed leg [{Index}] died on its debris timer"); }

        for (int32 Index = 0; Index < _Debris.Num(); ++Index)
        { Assert_True(ck::Is_NOT_Valid(_Debris[Index]), f"debris part [{Index}] died with its severed leg"); }

        Assert_True(ck::IsValid(_Floor), "the floor outlives the crawler");
    }
}
