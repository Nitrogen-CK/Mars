// Shared rig for the drip dressing tests: static-world slabs (engine cube, BlockAll, WorldStatic) spawned Movable so a
// game world accepts the mesh, and a deferred-spawn helper that turns static mobility off before the construction
// script runs (a game-world Rebuild must not touch Static components). Each test parks at its own spot (X 12000..18000,
// unique Y, Z >= 5000) in the shared PIE world.
namespace utils_drip_test
{
    // A box slab: InCentre and InSize (cm). Returns null if the cube could not load.
    AStaticMeshActor Spawn_Slab(FVector InCentre, FVector InSize)
    {
        auto Cube = engine::load::Cube();
        auto Slab = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, InCentre));
        if (ck::Is_NOT_Valid(Slab) || ck::Is_NOT_Valid(Cube))
        { return nullptr; }

        Slab.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        Slab.StaticMeshComponent.SetStaticMesh(Cube);
        Slab.StaticMeshComponent.SetCollisionProfileName(collision::profile::BlockAll);
        Slab.SetActorScale3D(InSize / 100.0);
        return Slab;
    }

    AMars_DripLeak Begin_Leak(FVector InLocation)
    {
        auto Leak = Cast<AMars_DripLeak>(SpawnActor(AMars_DripLeak, InLocation, FRotator::ZeroRotator, NAME_None, true));
        if (ck::IsValid(Leak))
        {
            Leak.UseStaticMobility = false;
            Leak.Preset = EMars_DripPreset::Custom;
        }
        return Leak;
    }

    void Destroy(AActor InActor)
    {
        if (ck::IsValid(InActor))
        { InActor.DestroyActor(); }
    }
}
