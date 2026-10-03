// The crawler rig: a 4-leg crawler spawned through its real entity script, without visuals, 65 uu above a runtime static
// Jolt floor (3000 x 3000 uu, top face at _Origin.Z). There is no nav field, so moves run in straight lines. Each test
// sets _Origin to an isolated spot: the Mars autotest map has no floor of its own there.
UCLASS(Abstract)
class UMars_AutoTestRig_Crawler : UCk_AutoTest_Base
{
    protected FVector _Origin;
    protected FCk_Handle_Crawler _Crawler;

    // 4 legs, roaming the box of InRoamHalfExtent around _Origin.
    protected FMars_Crawler_Spec Make_CrawlerSpec(FVector InRoamHalfExtent) const
    {
        return FMars_Crawler_Spec(4, FBox(_Origin - InRoamHalfExtent, _Origin + InRoamHalfExtent));
    }

    // Returns the floor.
    protected FCk_Handle SpawnFloorAndCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec)
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
        return Floor;
    }

    protected FVector BodyLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(_Crawler.As_Transform());
    }

    // False until the crawler is constructed; a failed gait fails the test.
    protected bool Get_IsGaitReady()
    {
        if (ck::Is_NOT_Valid(_Crawler))
        { return false; }

        const auto Gait = _Crawler.Get_Gait();
        if (utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Failed)
        {
            FinishFailure(f"the crawler's gait failed: {utils_procedural_gait::Get_Failure(Gait) :n}");
            return false;
        }

        return utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Ready;
    }

    UFUNCTION()
    protected void OnCrawlerConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Crawler = InEntityScriptHandle.As_Crawler();
    }

    // The gait is Ready and the monster has registered its 4 parts.
    UFUNCTION()
    protected void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsGaitReady() && _Crawler.Get_Monster().Get_Parts().Num() == 4);
    }

    UFUNCTION()
    protected void Check_GaitReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsGaitReady());
    }

    UFUNCTION()
    protected void Check_InRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam);
    }
}
