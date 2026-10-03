// A hit on a leg spills to the body: 10 Sever through leg 0's zone (Sever x1 on a limb) leaves the leg at 20 and, with the
// crawler's SpillToBody of 0.5, takes 5 off the body (115 of 120). The other legs are untouched.
//
// Isolated origin (130000, 88000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_BodyPart_SpillDamagesBody : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FVector _Origin = FVector(130000.0, 88000.0, 600.0);
    private FCk_Handle_Crawler _Crawler;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", 0, 10.0f);
        Add_Step("hit leg 0's zone with 10 Sever", n"Step_HitLeg0");
        Add_Step_WaitUntil("the body reads 115 (half the hit spilled)", n"Check_BodyAt115", 0, 2.0f);
        Add_Step("leg 0 took the full hit; the other legs took nothing", n"Step_AssertLegs");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared rig (one scenario per file: copied, not shared)
    //----------------------------------------------------------------------------------------------------------------------

    private FMars_Crawler_Spec Make_Spec()
    {
        const auto Half = FVector(400.0, 400.0, 200.0);
        return FMars_Crawler_Spec(4, FBox(_Origin - Half, _Origin + Half));
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

        Res.Set(utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Ready &&
            _Crawler.Get_Monster().Get_Parts().Num() == 4);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_HitLeg0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Zone = _Crawler.Get_LegParts()[0].Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(10.0f, GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Sever"))));
    }

    UFUNCTION()
    private void Check_BodyAt115(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), 115.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertLegs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Parts = _Crawler.Get_LegParts();
        Assert_Equals_Float(Parts[0].Get_Health().Get_Current(), 20.0f, 0.001f, "leg 0 took the full 10");
        for (int32 Index = 1; Index < Parts.Num(); ++Index)
        { Assert_Equals_Float(Parts[Index].Get_Health().Get_Current(), 30.0f, 0.001f, f"leg {Index} is untouched"); }

        Assert_True(Parts[0].Get_State() == EMars_BodyPart_State::Attached, "a non-lethal hit leaves the leg attached");
        Assert_Equals_Float(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), 115.0f, 0.001f, "the body took exactly the spill");
    }
}
