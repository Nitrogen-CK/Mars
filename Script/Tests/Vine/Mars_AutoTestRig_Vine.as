// The vine rig: engine cubes as the room (BlockAll, so Visibility traces stop on them), vines built from a fresh
// profile per test (utils_vine::Fill_Preset plus engine shapes: Cylinder stems along Z, Plane leaves, Cylinder cards,
// Cube knots, Cone tips), each test in a private corner of the shared test world. No kit asset, no profile asset, no
// material instance and no PCG are touched, so the tests stay silent under -nullrhi. A vine is spawned deferred after
// the room has had two frames to register its bodies, so its construction script solves once with the test's values.
struct FMars_VineTest_Spawn
{
    FVector Location;
    FRotator Rotation;
    UMars_VineProfile Profile;
    EMars_VineLayout Layout = EMars_VineLayout::Drop;
    EMars_VineEnd End = EMars_VineEnd::Ground;
    FMars_Vine_Shape Shape;
    int32 Seed = 7;
}

UCLASS(Abstract)
class UMars_AutoTestRig_Vine : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;
    default _AutoStageOriginField = false;

    // Each test sets its own slot: its corner is k_Origin + Slot x 6000 cm along X.
    protected int32 _Slot = 0;
    protected TArray<AActor> _Spawned;

    protected FVector Get_Origin() const
    {
        return FVector(-80000.0, 70000.0, 40000.0) + FVector(6000.0 * float(_Slot), 0.0, 0.0);
    }

    // An engine cube (100 cm) centred at InCenter, scaled by InScale, colliding.
    protected AStaticMeshActor SpawnSlab(FVector InCenter, FVector InScale)
    {
        auto Cube = engine::load::Cube();
        auto Slab = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, InCenter));
        if (ck::Is_NOT_Valid(Slab) || ck::Is_NOT_Valid(Cube))
        {
            FinishFailure("a slab (the engine cube) did not spawn");
            return nullptr;
        }

        Slab.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        Slab.StaticMeshComponent.SetStaticMesh(Cube);
        Slab.StaticMeshComponent.SetCollisionProfileName(collision::profile::BlockAll);
        Slab.SetActorScale3D(InScale);
        _Spawned.Add(Slab);
        return Slab;
    }

    // A slab whose top face is at InTopZ, centred on InXY, InSize cm wide and InThick cm thick.
    protected AStaticMeshActor SpawnFloor(FVector InXY, float InTopZ, FVector InSize)
    {
        return SpawnSlab(FVector(InXY.X, InXY.Y, InTopZ - InSize.Z * 0.5), InSize / 100.0);
    }

    // A slab whose bottom face is at InBottomZ.
    protected AStaticMeshActor SpawnCeiling(FVector InXY, float InBottomZ, FVector InSize)
    {
        return SpawnSlab(FVector(InXY.X, InXY.Y, InBottomZ + InSize.Z * 0.5), InSize / 100.0);
    }

    protected UMars_VineProfile Make_Profile(EMars_VinePreset InPreset)
    {
        auto Profile = Cast<UMars_VineProfile>(NewObject(this, UMars_VineProfile));
        utils_vine::Fill_Preset(Profile, InPreset);
        Profile.Stem.Meshes.Mesh = engine::load::Cylinder();
        Profile.Stem.Meshes.ForwardAxis = ESplineMeshAxis::Z;
        Profile.Stem.Meshes.TipMesh = engine::load::Cone();
        if (InPreset == EMars_VinePreset::GiantRoot)
        { Profile.Stem.Meshes.KnotMesh = engine::load::Cube(); }
        if (InPreset == EMars_VinePreset::Ivy)
        {
            Profile.Leaves.Meshes.Add(engine::load::Plane());
            Profile.Leaves.Weights.Add(1.0f);
            Profile.Leaves.Scale = FVector2D(0.05, 0.08);
        }
        Profile.Strands.Meshes.Add(engine::load::Cylinder());
        return Profile;
    }

    protected AMars_Vine SpawnVine(const FMars_VineTest_Spawn& InSpawn)
    {
        auto Vine = Cast<AMars_Vine>(SpawnActor(AMars_Vine, InSpawn.Location, InSpawn.Rotation, NAME_None, true));
        if (ck::Is_NOT_Valid(Vine))
        {
            FinishFailure("the vine did not spawn");
            return nullptr;
        }

        Vine.Profile = InSpawn.Profile;
        Vine.Layout = InSpawn.Layout;
        Vine.End = InSpawn.End;
        Vine.Shape = InSpawn.Shape;
        Vine.Seed = InSpawn.Seed;
        FinishSpawningActor(Vine);
        _Spawned.Add(Vine);
        return Vine;
    }

    protected FMars_VineTest_Spawn Make_Spawn(UMars_VineProfile InProfile, EMars_VineLayout InLayout, EMars_VineEnd InEnd)
    {
        FMars_VineTest_Spawn Spawn;
        Spawn.Profile = InProfile;
        Spawn.Layout = InLayout;
        Spawn.End = InEnd;
        Spawn.Location = Get_Origin();
        return Spawn;
    }

    // The world points of every path of InKind.
    protected TArray<FMars_Vine_Path> Get_WorldPaths(AMars_Vine InVine, EMars_VinePathKind InKind)
    {
        TArray<FMars_Vine_Path> Out;
        if (ck::Is_NOT_Valid(InVine))
        { return Out; }

        const auto Frame = InVine.GetActorTransform();
        for (int32 Index = 0; Index < InVine.Get_PathCount(); ++Index)
        {
            FMars_Vine_Path Path;
            InVine.Get_Path(Index, Path);
            if (Path.Kind != InKind)
            { continue; }
            for (int32 Point = 0; Point < Path.Points.Num(); ++Point)
            {
                Path.Points[Point] = Frame.TransformPosition(Path.Points[Point]);
                if (Path.Normals[Point].IsNearlyZero() == false)
                { Path.Normals[Point] = Frame.TransformVectorNoScale(Path.Normals[Point]); }
            }
            Out.Add(Path);
        }
        return Out;
    }

    protected float Get_LowestZ(const FMars_Vine_Path& InPath)
    {
        auto Lowest = 1.0e9;
        for (auto Point : InPath.Points)
        { Lowest = Math::Min(Lowest, Point.Z); }
        return Lowest;
    }

    // Total instances over the vine's emitted HISMs.
    protected int32 Get_InstanceCount(AMars_Vine InVine)
    {
        TArray<UPrimitiveComponent> Emitted;
        InVine.Get_EmittedComponents(Emitted);
        int32 Count = 0;
        for (auto Component : Emitted)
        {
            auto Hism = Cast<UHierarchicalInstancedStaticMeshComponent>(Component);
            if (ck::IsValid(Hism))
            { Count += Hism.GetInstanceCount(); }
        }
        return Count;
    }

    UFUNCTION()
    protected void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (auto Actor : _Spawned)
        {
            if (ck::IsValid(Actor))
            { Actor.DestroyActor(); }
        }
        _Spawned.Reset();
    }
}
