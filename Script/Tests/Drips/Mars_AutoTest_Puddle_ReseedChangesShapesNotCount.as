// A loose puddle cluster (4 puddles inside 150 cm) projects every puddle onto the floor under it, 1.5 cm above it, in
// both layers. Reseed gives the same count with different shapes (custom data 0, the shape seed), and going back to
// the first seed lays the first shapes again: the layout is deterministic per seed.
class UMars_AutoTest_Puddle_ReseedChangesShapesNotCount : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;
    default _AutoStageOriginField = false;

    private AMars_Puddle _Puddle;
    private AStaticMeshActor _Floor;
    private FVector _Origin = FVector(14000.0, 7900.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn the floor", n"Step_SpawnFloor");
        Add_Step_WaitFrames("let the floor body register", 2);
        Add_Step("spawn the puddles", n"Step_SpawnPuddle");
        Add_Step("reseed changes shapes, not the count", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Floor = utils_drip_test::Spawn_Slab(_Origin, FVector(600.0, 600.0, 20.0));
    }

    UFUNCTION()
    private void Step_SpawnPuddle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Puddle = Cast<AMars_Puddle>(SpawnActor(AMars_Puddle, _Origin + FVector(0.0, 0.0, 40.0), FRotator::ZeroRotator, NAME_None, true));
        if (ck::Is_NOT_Valid(_Puddle))
        { return; }

        _Puddle.UseStaticMobility = false;
        _Puddle.Count = 4;
        _Puddle.Radius = 150.0f;
        _Puddle.Seed = 3;
        FinishSpawningActor(_Puddle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Puddle), "the puddles spawned");
        if (ck::Is_NOT_Valid(_Puddle))
        { return; }

        Assert_Equals_Int(_Puddle.Get_PuddleCount(), 4, "four puddles on the floor");
        Assert_Equals_Int(_Puddle.PuddleGloss.GetInstanceCount(), 4, "in both layers");
        FTransform First;
        _Puddle.PuddleWet.GetInstanceTransform(0, First, true);
        Assert_Equals_Float(First.GetLocation().Z, _Origin.Z + 10.0 + 1.5, 0.05, "projected 1.5 cm above the floor");

        const float SeedA = _Puddle.Get_PuddleValue(0, EMars_PuddleData::Seed);
        _Puddle.Reseed();
        Assert_Equals_Int(_Puddle.Get_PuddleCount(), 4, "reseeding keeps the count");
        Assert_True(_Puddle.Get_PuddleValue(0, EMars_PuddleData::Seed) != SeedA, "and changes the shapes");

        _Puddle.Seed = 3;
        _Puddle.Rebuild();
        Assert_True(_Puddle.Get_PuddleValue(0, EMars_PuddleData::Seed) == SeedA, "the first seed lays the first shapes again");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_drip_test::Destroy(_Puddle);
        utils_drip_test::Destroy(_Floor);
    }
}
