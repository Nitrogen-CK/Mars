// Placeable spike trap. The origin is the centre of the floor tile's underside; spikes rest hidden in the tile and rise
// by 60 uu on the spike node's Mover. A looping Trap cycle (Safe / Warn / Active) raises them on Warn and arms the push
// hazard over the tile on Active. An optional MechanismSink gates the cycle per Trap.Powered.
class UMars_SpikeTrap_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Trap_Spec Trap = utils_trap::Make_SpikeTrapSpec();

    // No sink is added while InputChannels is empty.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSink_Spec Sink;

    // A zero PushImpulse takes the spike trap's upward push. Not a `default`: the spawn-params generator emits a
    // non-default script struct as a positional constructor call, which script structs do not have.
    UPROPERTY(ExposeOnSpawn)
    FMars_Hazard_Spec Hazard;

    UPROPERTY(ExposeOnSpawn)
    float32 TileSize = 200.0f;

    private const float64 SpikeRise = 60.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto TrapRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsSpikeTrap");

        auto SpikeNode = utils_scene_node::Create(TrapRoot, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = FVector(0.0, 0.0, SpikeRise);
        MoverSpec.Duration = 0.25f;
        auto Mover = utils_mover::Add(SpikeNode, MoverSpec);

        auto TriggerSpec = FMars_Trigger_Spec();
        TriggerSpec.Shape = EMars_Trigger_Shape::Box;
        TriggerSpec.BoxHalfExtents = FVector(TileSize * 0.5, TileSize * 0.5, 50.0);
        TriggerSpec.LocalOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 50.0), FVector::OneVector);
        TriggerSpec.DetectionFilter = GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Player"));
        auto Trigger = utils_trigger::Add(TrapRoot, TriggerSpec);

        auto HazardSpec = Hazard;
        if (HazardSpec.PushImpulse.IsNearlyZero())
        { HazardSpec.PushImpulse = FVector(0.0, 0.0, 700.0); }
        auto HazardHandle = utils_hazard::Add(InHandle, HazardSpec, Trigger);

        utils_trap::Add(InHandle, utils_trap::Resolve_Spec(Trap, utils_trap::Make_SpikeTrapSpec()), HazardHandle, Mover);

        if (Sink.InputChannels.Num() > 0)
        { utils_mechanism_sink::Add(InHandle, Sink); }

        AddVisuals(TrapRoot, SpikeNode);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InSpikeNode)
    {
        auto CubeMesh = engine::load::Cube();
        if (ck::Is_NOT_Valid(CubeMesh))
        { return; }

        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
        auto HazardMaterial = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine cube is 100 uu with its pivot at the centre.
        const float64 TileThickness = 10.0;
        AddBox(InRoot, FVector(0.0, 0.0, TileThickness * 0.5), FVector(TileSize, TileSize, TileThickness) * 0.01,
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"SpikeTrap_Tile");

        // Tips rest just below the tile's top face, so the retracted spikes are hidden inside it.
        const int32 SpikesPerSide = 4;
        const float64 SpikeWidth = 12.0;
        const float64 SpikeHeight = SpikeRise;
        const float64 SpikeTipAtRest = TileThickness - 2.0;
        const auto Spacing = TileSize * 0.8 / SpikesPerSide;
        const auto FirstOffset = -Spacing * (SpikesPerSide - 1) * 0.5;

        auto SpikeTransform = InSpikeNode.As_Transform();
        for (int32 X = 0; X < SpikesPerSide; ++X)
        {
            for (int32 Y = 0; Y < SpikesPerSide; ++Y)
            {
                const auto Location = FVector(FirstOffset + Spacing * X, FirstOffset + Spacing * Y, SpikeTipAtRest - SpikeHeight * 0.5);
                AddBox(SpikeTransform, Location, FVector(SpikeWidth, SpikeWidth, SpikeHeight) * 0.01,
                    CubeMesh, HazardMaterial, collision::profile::NoCollision, n"SpikeTrap_Spike");
            }
        }
    }

    // NewObject needs a UObject outer, hence a private method on the entity script.
    private void AddBox(
        FCk_Handle_Transform& InAttachTo,
        FVector InLocation,
        FVector InScale,
        UStaticMesh InMesh,
        UMaterialInterface InMaterial,
        FName InCollisionProfile,
        FName InDebugName)
    {
        auto Node = utils_scene_node::Create(InAttachTo, FTransform(FRotator::ZeroRotator, InLocation, InScale));
        auto NodeEntity = FCk_Handle(Node);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable even when static: the component is registered first and then receives the entity transform,
        // which a Static component refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(InMesh);
        if (ck::IsValid(InMaterial))
        { Archetype.SetMaterial(0, InMaterial); }
        Archetype.SetCollisionProfileName(InCollisionProfile);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        utils_unreal_component::Add(NodeEntity, ComponentParams);
    }
}
