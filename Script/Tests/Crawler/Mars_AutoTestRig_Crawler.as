// The crawler rig: a crawler spawned through its real entity script, without visuals, 65 uu above a runtime static Jolt
// floor (3000 x 3000 uu, top face at _Origin.Z). There is no nav field, so moves run in straight lines. Each test sets
// _Origin to an isolated spot: the Mars autotest map has no floor of its own there.
UCLASS(Abstract)
class UMars_AutoTestRig_Crawler : UCk_AutoTest_Base
{
    // Composition, physics falls and the debris and corpse timers outrun the default poll budget at lane frame rate.
    protected const int32 k_SlowPolls = 900;

    protected FVector _Origin;
    protected FCk_Handle_Crawler _Crawler;

    // 4 legs, roaming the box of InRoamHalfExtent around _Origin.
    protected FMars_Crawler_Spec Make_CrawlerSpec(FVector InRoamHalfExtent) const
    {
        return FMars_Crawler_Spec(4, FBox(_Origin - InRoamHalfExtent, _Origin + InRoamHalfExtent));
    }

    // A static Jolt box at InTransform, BlockAll, like the floor. Returns its entity (a World hit's attribution).
    protected FCk_Handle SpawnStaticBox(FCk_Handle InHandle, FTransform InTransform, FVector InHalfExtents)
    {
        auto Box = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Box, InTransform, ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Box, BoxSpec);
        return Box;
    }

    // Returns the floor.
    protected FCk_Handle SpawnFloorAndCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec)
    {
        auto Floor = SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), FVector(1500.0, 1500.0, 10.0));

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
        OnCrawlerSpawned();
    }

    // A derived rig's hook, right after _Crawler is set.
    protected void OnCrawlerSpawned() {}

    // The gait is Ready and the monster has registered one part per leg.
    UFUNCTION()
    protected void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsGaitReady() && _Crawler.Get_Monster().Get_Parts().Num() == _Crawler.Get_Spec().LegCount);
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
