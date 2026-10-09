// A block set up as the map builders' Spawn_Block sets one up (engine cube, scale, PhysMaterialOverride = Stone) answers
// the ground probe from above with that exact phys mat and its Surface.Stone tag. Runtime-spawned, so it is Movable to
// take a mesh; the builders' blocks are Static, which the override does not care about.
class UMars_AutoTest_SurfaceFx_GroundTraceReturnsOverridePhysMat : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;

    private AStaticMeshActor _Block;
    private UPhysicalMaterial _Stone;

    // A parking spot of its own, clear of the origin floor and other tests' content.
    private FVector _BlockCenter = FVector(-9600.0, -9600.0, 2000.0);
    private FVector _BlockScale = FVector(4.0, 4.0, 1.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn a stone block", n"Step_Spawn");
        Add_Step_WaitFrames("let the block's body register", 2);
        Add_Step("probe down onto it", n"Step_Probe");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Spawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Cube = Cast<UStaticMesh>(LoadObject(UStaticMesh, "/Engine/BasicShapes/Cube.Cube"));
        Assert_True(ck::IsValid(Cube), "the engine cube loads");

        _Stone = System::LoadAsset_Blocking(TSoftObjectPtr<UPhysicalMaterial>(FSoftObjectPath("/Game/Mars/Physics/Stone_Mars_PhysMat.Stone_Mars_PhysMat")));
        Assert_True(ck::IsValid(_Stone), "Stone_Mars_PhysMat loads");

        _Block = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, _BlockCenter));
        Assert_True(ck::IsValid(_Block), "the block spawns");
        if (ck::Is_NOT_Valid(_Block) || ck::Is_NOT_Valid(Cube) || ck::Is_NOT_Valid(_Stone))
        { return; }

        _Block.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        _Block.StaticMeshComponent.SetStaticMesh(Cube);
        _Block.SetActorScale3D(_BlockScale);
        _Block.StaticMeshComponent.SetPhysMaterialOverride(_Stone);
    }

    UFUNCTION()
    private void Step_Probe(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Block))
        { return; }

        auto Query = FMars_SurfaceFx_GroundQuery();
        Query.Origin = _BlockCenter + FVector(0.0, 0.0, 200.0);
        Query.DepthCm = 300.0;

        auto Ground = FMars_SurfaceFx_Ground();
        const auto Hit = utils_surface_fx::TryGet_SurfaceUnder(Query, Ground);
        _Block.DestroyActor();

        Assert_True(Hit, "the probe hits the block");
        if (Hit == false)
        { return; }

        const auto TopZ = _BlockCenter.Z + 50.0 * _BlockScale.Z;
        Assert_Equals_Float(Ground.Contact.Location.Z, TopZ, 1.0, "the probe hits the block's top face");
        auto Returned = FString("null");
        if (ck::IsValid(Ground.PhysicalMaterial))
        { Returned = Ground.PhysicalMaterial.GetName().ToString(); }

        Assert_True(Ground.PhysicalMaterial == _Stone, f"the probe returns the override phys mat (got [{Returned}])");
        Assert_True(Ground.SurfaceTags.HasTagExact(GameplayTags::Surface_Stone),
            f"the probe's surface tags carry Surface.Stone (first tag [{Ground.SurfaceTags.First()}])");
    }
}
