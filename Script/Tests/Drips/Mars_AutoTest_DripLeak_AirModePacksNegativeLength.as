// A leak in Air mode (drip into darkness) never traces down: its cards carry Length = -AirLength (-600, the shader
// reads a negative length as "no impact, fade over the last quarter"), it lays no ring and no puddle, and the strand
// records state Air. The floor 400 cm below proves the down-trace really was skipped.
class UMars_AutoTest_DripLeak_AirModePacksNegativeLength : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_DripLeak _Leak;
    private AStaticMeshActor _Floor;
    private FVector _Origin = FVector(14000.0, 5500.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the floor", n"Step_SpawnFloor");
        Add_Step_WaitFrames("let the floor body register", 2);
        Add_Step("spawn the air leak", n"Step_SpawnLeak");
        Add_Step("the strand drips into the air", n"Step_Assert");
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
        if (ck::Is_NOT_Valid(_Leak))
        { return; }

        _Leak.Trace.Air = true;
        _Leak.Trace.AirLength = 600.0f;
        FinishSpawningActor(_Leak);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Leak), "the leak spawned");
        if (ck::Is_NOT_Valid(_Leak))
        { return; }

        Assert_Equals_Float(_Leak.Get_CardValue(0, EMars_DripCardData::Length), -600.0, 1e-3, "the cards pack -AirLength");
        Assert_Equals_Float(_Leak.Get_CardValue(0, EMars_DripCardData::Surface), float(int32(EMars_DripSurface::Air)), 1e-6,
            "the surface slot says Air");
        Assert_Equals_Int(_Leak.Rings.GetInstanceCount(), 0, "no ring in the air");
        Assert_Equals_Int(_Leak.PuddleWet.GetInstanceCount(), 0, "no puddle in the air");
        Assert_True(_Leak.CachedStrands.Num() == 1 && _Leak.CachedStrands[0].State == EMars_DripTraceState::Air,
            "the strand records state Air");

        FTransform Card;
        _Leak.Drops.GetInstanceTransform(0, Card, true);
        Assert_Equals_Float(Card.GetLocation().Z, _Origin.Z + 410.0 - 600.0, 0.05, "the cards sit at the end of the air fall");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Leak);
        utils_drip_test::Destroy(_Floor);
    }
}
