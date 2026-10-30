// A leak that traced its strand down to a floor (400 cm) keeps that strand when a later rebuild misses (the floor is
// gone, as in an unloaded World Partition cell): the length, the ring and the puddle stay, and the strand says
// MissedKeptCached. A fresh leak over nothing (no cache) falls back to -MaxLength (Air), lays no impact and says
// MissedNoCache.
class UMars_AutoTest_DripLeak_AMissKeepsTheLastTracedLength : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_DripLeak _Leak;
    private AMars_DripLeak _Fresh;
    private AStaticMeshActor _Floor;
    private FVector _Origin = FVector(14000.0, 6300.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the floor", n"Step_SpawnFloor");
        Add_Step_WaitFrames("let the floor body register", 2);
        Add_Step("spawn the leak over it", n"Step_SpawnLeak");
        Add_Step("the first trace lands", n"Step_AssertTraced");
        Add_Step("remove the floor", n"Step_RemoveFloor");
        Add_Step_WaitFrames("let the floor body go", 2);
        Add_Step("a rebuild that misses keeps the strand", n"Step_AssertKept");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Floor = utils_drip_test::Spawn_Slab(_Origin, FVector(400.0, 400.0, 20.0));
    }

    UFUNCTION()
    private void Step_SpawnLeak(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Leak = utils_drip_test::Begin_Leak(_Origin + FVector(0.0, 0.0, 410.0));
        if (ck::IsValid(_Leak))
        { FinishSpawningActor(_Leak); }
    }

    UFUNCTION()
    private void Step_AssertTraced(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Leak), "the leak spawned");
        if (ck::Is_NOT_Valid(_Leak))
        { return; }

        Assert_Equals_Float(_Leak.Get_CardValue(0, EMars_DripCardData::Length), 400.0, 0.5, "the first trace lands on the floor");
        Assert_Equals_Int(_Leak.Rings.GetInstanceCount(), 1, "with a ring");
    }

    UFUNCTION()
    private void Step_RemoveFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Floor);
        _Floor = nullptr;
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Leak))
        { return; }

        _Leak.Rebuild();
        Assert_Equals_Float(_Leak.Get_CardValue(0, EMars_DripCardData::Length), 400.0, 0.5, "a miss keeps the cached length");
        Assert_Equals_Int(_Leak.Rings.GetInstanceCount(), 1, "and the ring");
        Assert_Equals_Int(_Leak.PuddleWet.GetInstanceCount(), 1, "and the puddle");
        Assert_True(_Leak.CachedStrands.Num() == 1 && _Leak.CachedStrands[0].State == EMars_DripTraceState::MissedKeptCached,
            "the strand says MissedKeptCached");

        _Fresh = utils_drip_test::Begin_Leak(_Origin + FVector(0.0, 600.0, 410.0));
        if (ck::Is_NOT_Valid(_Fresh))
        { return; }

        FinishSpawningActor(_Fresh);
        Assert_Equals_Float(_Fresh.Get_CardValue(0, EMars_DripCardData::Length), -1500.0, 1e-3, "no cache: -MaxLength (Air)");
        Assert_Equals_Int(_Fresh.Rings.GetInstanceCount(), 0, "no impact without a hit");
        Assert_True(_Fresh.CachedStrands.Num() == 1 && _Fresh.CachedStrands[0].State == EMars_DripTraceState::MissedNoCache,
            "the strand says MissedNoCache");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Leak);
        utils_drip_test::Destroy(_Fresh);
        utils_drip_test::Destroy(_Floor);
    }
}
