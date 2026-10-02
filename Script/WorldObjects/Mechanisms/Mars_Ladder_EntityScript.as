// Placeable ladder. The origin is the foot on the floor; local +X points out of the ladder toward the climber (place it
// against a wall or platform face with +X facing the room). Walk into it to climb; see FMars_Ladder_Spec for the frame.
// Visuals: two rails and a rung every 30 uu, from engine cubes. The rails block; the rungs do not (the climber's capsule
// rides the climb line, and rung collision would fight it).
class UMars_Ladder_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Not a `default` in subclasses: set non-default fields in their DoConstruct (the spawn-params generator emits a
    // non-default script struct as a positional constructor call).
    UPROPERTY(ExposeOnSpawn)
    FMars_Ladder_Spec Ladder;

    private const float64 RungSpacing = 30.0;
    private const float64 RailThickness = 8.0;
    private const float64 RungThickness = 6.0;

    // Set by AddVisuals for its AddBox calls.
    private UStaticMesh _CubeMesh;
    private UMaterialInterface _Material;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto LadderRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_ladder::Add(LadderRoot, Ladder);

        AddVisuals(LadderRoot);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        _CubeMesh = engine::load::Cube();
        if (ck::Is_NOT_Valid(_CubeMesh))
        { return; }

        _Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine cube is 100 uu with its pivot at the centre.
        const auto Height = float64(Ladder.Height);
        const auto HalfWidth = float64(Ladder.Width) * 0.5;
        const auto RailScale = FVector(RailThickness, RailThickness, Height) * 0.01;
        AddBox(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, -HalfWidth, Height * 0.5), RailScale),
            collision::profile::BlockAll);
        AddBox(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, HalfWidth, Height * 0.5), RailScale),
            collision::profile::BlockAll);

        const auto RungScale = FVector(RungThickness, Ladder.Width, RungThickness) * 0.01;
        for (float64 RungZ = RungSpacing; RungZ <= Height; RungZ += RungSpacing)
        { AddBox(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, RungZ), RungScale), collision::profile::NoCollision); }
    }

    // NewObject needs a UObject outer, hence a private method on the entity script. InOffset carries the box's location
    // and scale relative to the ladder root; the mesh and material are AddVisuals'.
    private void AddBox(FCk_Handle_Transform& InAttachTo, FTransform InOffset, FName InCollisionProfile)
    {
        auto Node = utils_scene_node::Create(InAttachTo, InOffset);
        auto NodeEntity = FCk_Handle(Node);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable even when static: the component is registered first and then receives the entity transform,
        // which a Static component refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(_CubeMesh);
        if (ck::IsValid(_Material))
        { Archetype.SetMaterial(0, _Material); }
        Archetype.SetCollisionProfileName(InCollisionProfile);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Ladder_Part");
        utils_unreal_component::Add(NodeEntity, ComponentParams);
    }
}
