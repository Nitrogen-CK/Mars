// Placeable pressure plate. The origin is the floor; the slab sinks while at least Occupancy.RequiredCount filtered
// entities stand in the trigger volume, and rises Occupancy.ReleaseDelaySeconds after they leave. Asserts an optional
// MechanismSource while occupied.
class UMars_PressurePlate_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Trigger_Spec Trigger;
    default Trigger.BoxHalfExtents = FVector(60.0, 60.0, 30.0);
    default Trigger.LocalOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 30.0));
    default Trigger.DetectionFilter = GameplayTag::MakeGameplayTagContainerFromTag(
        GameplayTags::ResolveGameplayTag(n"Probe.Mars.Player"));

    UPROPERTY(ExposeOnSpawn)
    FMars_Occupancy_Spec Occupancy;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UPROPERTY(ExposeOnSpawn)
    FVector PlateSize = FVector(120.0, 120.0, 8.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto PlateRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsPressurePlate");

        auto PlateNode = utils_scene_node::Create(PlateRoot, FTransform::Identity);
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = FVector(0.0, 0.0, -8.0);
        MoverSpec.Duration = 0.25f;
        auto MoverHandle = utils_mover::Add(PlateNode, MoverSpec);

        auto TriggerHandle = utils_trigger::Add(PlateRoot, Trigger);
        utils_occupancy::Add(InHandle, Occupancy, TriggerHandle, MoverHandle);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(PlateRoot, PlateNode);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InPlateNode)
    {
        auto CubeMesh = engine::load::Cube();

        // Engine cube is 100 uu with a centered pivot. The slab rides a child of the plate node so the node's offset
        // stays a pure press translation.
        auto PlateNode = InPlateNode;
        auto PlateTransform = PlateNode.As_Transform();
        AddMesh(PlateTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PlateSize.Z * 0.5), PlateSize * 0.01),
            CubeMesh, assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::BlockAll, n"PressurePlate_Slab");

        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
        const float64 FrameWidth = 10.0;
        const auto FrameHeight = PlateSize.Z * 0.5;
        const auto SideX = (PlateSize.X + FrameWidth) * 0.5;
        const auto SideY = (PlateSize.Y + FrameWidth) * 0.5;
        const auto AlongXScale = FVector(PlateSize.X + FrameWidth * 2.0, FrameWidth, FrameHeight) * 0.01;
        const auto AlongYScale = FVector(FrameWidth, PlateSize.Y, FrameHeight) * 0.01;

        AddMesh(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, -SideY, FrameHeight * 0.5), AlongXScale),
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"PressurePlate_FrameLeft");
        AddMesh(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, SideY, FrameHeight * 0.5), AlongXScale),
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"PressurePlate_FrameRight");
        AddMesh(InRoot, FTransform(FRotator::ZeroRotator, FVector(-SideX, 0.0, FrameHeight * 0.5), AlongYScale),
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"PressurePlate_FrameBack");
        AddMesh(InRoot, FTransform(FRotator::ZeroRotator, FVector(SideX, 0.0, FrameHeight * 0.5), AlongYScale),
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"PressurePlate_FrameFront");
    }

    // NewObject needs a UObject outer, hence a private method on the entity script.
    private void AddMesh(
        FCk_Handle_Transform& InAttachTo,
        FTransform InLocalTransform,
        UStaticMesh InMesh,
        UMaterialInterface InMaterial,
        FName InCollisionProfile,
        FName InDebugName)
    {
        if (ck::Is_NOT_Valid(InMesh))
        { return; }

        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);
        auto NodeEntity = FCk_Handle(Node);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable: the component receives the entity transform after registration, and the slab moves.
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
