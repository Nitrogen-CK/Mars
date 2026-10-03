// Damage interrupts roaming: a roaming crawler's leg part 0 takes a 5 Sever hit through its zone; the crawler's setup
// writes IsHurt true through the brain, the plan becomes [Flinch, Roam], and the behaviour sub-SM goes Roam -> Idle ->
// Flinch; the flinch stops the navigator (Idle within 0.5 s); after FlinchSeconds (0.6) the Flinch task clears IsHurt
// through the brain, the plan is [Roam] again and the crawler roams on.
//
// Spawned through the real entity script onto a runtime static Jolt floor (no nav field: straight-line moves).
// Isolated origin (150000, 84000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_Crawler_DamageFlinchesThenResumesRoam : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    private FVector _Origin = FVector(150000.0, 84000.0, 600.0);
    private FCk_Handle_Crawler _Crawler;
    private float64 _FlinchAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed and its gait Ready", n"Check_Ready", 0, 10.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam and the navigator Moving", n"Check_RoamingAndMoving", 0, 8.0f);
        Add_Step("hit leg part 0 for 5 Sever through its zone", n"Step_HitLeg");
        Add_Step_WaitUntil("the behaviour sub-SM reaches Flinch", n"Check_InFlinch", 0, 2.0f);
        Add_Step_WaitUntil("the flinch stopped the navigator within 0.5 s", n"Check_NavigatorIdle", 0, 2.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is back in Roam", n"Check_InRoam", 0, 3.0f);
        Add_Step("IsHurt was cleared and the leaf is Roam", n"Step_AssertRecovered");
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
        Spec.FlinchSeconds = 0.6f;
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

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_RoamingAndMoving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam &&
            _Crawler.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Moving);
    }

    UFUNCTION()
    private void Step_HitLeg(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Crawler.Get_Brain().Get_Fact(GameplayTags::ResolveGameplayTag(n"Mars.WS.Crawler.IsHurt")), "IsHurt starts false");

        auto Zone = _Crawler.Get_LegParts()[0].Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(5.0f, GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Sever"))));
    }

    UFUNCTION()
    private void Check_InFlinch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto InFlinch = _Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Flinch;
        if (InFlinch)
        { _FlinchAt = System::GetGameTimeInSeconds(); }

        Res.Set(InFlinch);
    }

    UFUNCTION()
    private void Check_NavigatorIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Elapsed = System::GetGameTimeInSeconds() - _FlinchAt;
        if (_Crawler.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Idle)
        {
            Res.Set(true);
            return;
        }

        if (Elapsed > 0.5)
        { FinishFailure(f"the navigator is still {_Crawler.Get_Navigator().Get_Status() :n} {Elapsed} s into the flinch"); }
    }

    UFUNCTION()
    private void Check_InRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam);
    }

    UFUNCTION()
    private void Step_AssertRecovered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Brain = _Crawler.Get_Brain();
        Assert_False(Brain.Get_Fact(GameplayTags::ResolveGameplayTag(n"Mars.WS.Crawler.IsHurt")), "the flinch cleared IsHurt");
        Assert_True(Brain.Get_LeafClass() == UMars_GoapAction_Crawler_Roam, "the brain's leaf is Roam again");
        Assert_Equals_Float(_Crawler.Get_LegParts()[0].Get_Health().Get_Current(), 25.0f, 0.001f, "leg 0 took the 5");
        Assert_True(System::GetGameTimeInSeconds() - _FlinchAt >= 0.6 - 0.05, "the flinch held for FlinchSeconds");
    }
}
