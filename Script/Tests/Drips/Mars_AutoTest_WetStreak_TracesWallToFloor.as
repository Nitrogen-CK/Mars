// A wet streak placed 30 cm in front of a wall (face at X0, 300 cm tall, on a floor whose top is Z0 + 10) at Z0 + 210,
// facing out of the wall, finds the wall behind it and runs down it to the floor: 200 cm long, the decal's X projects
// into the wall (-X), and its decal colour carries (Seed, Dampness, Flow / 100, Mineral) for the material.
class UMars_AutoTest_WetStreak_TracesWallToFloor : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_WetStreak _Streak;
    private AStaticMeshActor _Floor;
    private AStaticMeshActor _Wall;
    private FVector _Origin = FVector(14000.0, 8700.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the floor and the wall", n"Step_SpawnRoom");
        Add_Step_WaitFrames("let the bodies register", 2);
        Add_Step("spawn the streak", n"Step_SpawnStreak");
        Add_Step("the streak runs down the wall", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnRoom(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Floor = utils_drip_test::Spawn_Slab(_Origin, FVector(400.0, 400.0, 20.0));
        _Wall = utils_drip_test::Spawn_Slab(_Origin + FVector(-10.0, 0.0, 160.0), FVector(20.0, 400.0, 300.0));
    }

    UFUNCTION()
    private void Step_SpawnStreak(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Streak = Cast<AMars_WetStreak>(SpawnActor(AMars_WetStreak, _Origin + FVector(30.0, 0.0, 210.0), FRotator::ZeroRotator,
            NAME_None, true));
        if (ck::Is_NOT_Valid(_Streak))
        { return; }

        _Streak.Seed = 5;
        _Streak.Streak.Dampness = 0.6f;
        _Streak.Streak.Flow = 25.0f;
        _Streak.Streak.Mineral = 0.3f;
        FinishSpawningActor(_Streak);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Streak) && ck::IsValid(_Wall), "the rig spawned");
        if (ck::Is_NOT_Valid(_Streak))
        { return; }

        Assert_Equals_Float(float(_Streak.TracedLength), 200.0, 1.0, "the streak runs from its height down to the floor");
        const FVector Into = _Streak.StreakDecal.GetForwardVector();
        Assert_True(Into.DotProduct(FVector(-1.0, 0.0, 0.0)) > 0.99, f"the decal projects into the wall (X {Into.ToString()})");
        const FVector Centre = _Streak.StreakDecal.GetWorldLocation();
        Assert_Equals_Float(Centre.Z, _Origin.Z + 110.0, 1.0, "the decal is centred halfway down the streak");
        Assert_Equals_Float(Centre.X, _Origin.X, 0.5, "on the wall face");

        const FLinearColor Colour = _Streak.StreakDecal.DecalColor;
        Assert_Equals_Float(Colour.R, utils_drip::Roll(5, 0, 11), 1e-4, "decal colour R carries the seed");
        Assert_Equals_Float(Colour.G, 0.6, 1e-4, "G the dampness");
        Assert_Equals_Float(Colour.B, 0.25, 1e-4, "B the flow / 100");
        Assert_Equals_Float(Colour.A, 0.3, 1e-4, "A the mineral");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Streak);
        utils_drip_test::Destroy(_Wall);
        utils_drip_test::Destroy(_Floor);
    }
}
