// Placeable valve hand wheel. The origin is the mounting surface and local +X points out of it; a pipe stub carries
// the wheel WheelDistance out along +X. Hold to turn (Control.HoldSeconds); activating rolls the wheel by TurnDegrees.
// Asserts an optional MechanismSource while active.
class UMars_HandWheel_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Control_Spec Control;
    default Control.Interaction = EMars_Control_Interaction::Timed;
    default Control.HoldSeconds = 2.0f;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    // Wheel roll when active; values past 360 turn that many times.
    UPROPERTY(ExposeOnSpawn)
    float32 TurnDegrees = 720.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 MoveDuration = 1.2f;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "TurnWheelPrompt", "Turn wheel");

    private const float64 WheelDistance = 30.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto WheelRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsHandWheel");

        const auto WheelLocation = FVector(WheelDistance, 0.0, 0.0);
        auto WheelNode = utils_scene_node::Create(WheelRoot, FTransform(FRotator::ZeroRotator, WheelLocation));

        // The Mover owns the node's whole offset, so both poses carry the wheel's location.
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = WheelLocation;
        MoverSpec.EndLocation = WheelLocation;
        MoverSpec.EndRotation = FRotator(0.0, 0.0, TurnDegrees);
        MoverSpec.Duration = MoveDuration;
        MoverSpec.StartAtEnd = Control.StartActive;
        auto Mover = utils_mover::Add(WheelNode, MoverSpec);

        utils_control::Add(InHandle, Control, Mover);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(WheelRoot, WheelNode);
        AddInteractable(WheelRoot);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InWheelNode)
    {
        auto CubeMesh = engine::load::Cube();

        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine shapes are 100 uu with a centered pivot. Pipe: 12 x 12 from the wall to the wheel.
        AddMesh(InRoot, FTransform(FRotator::ZeroRotator, FVector(WheelDistance * 0.5, 0.0, 0.0), FVector(WheelDistance * 0.01, 0.12, 0.12)),
            CubeMesh, Material, collision::profile::BlockAll, n"HandWheel_Pipe");

        // Wheel: 50 across, 5 thick; the cylinder's Z axis is pitched onto X, the roll axis. The spoke makes the turn
        // readable on an otherwise symmetric disc.
        // A cylinder with Grip_R / Grip_L sockets on the rim at 2 and 10 o'clock: the first-person gloves take it with both hands.
        auto WheelTransform = InWheelNode.As_Transform();
        const auto WheelMeshPath = "/Game/Mars/Gameplay/Mechanisms/HandWheel_Mars_SM.HandWheel_Mars_SM";
        auto WheelMesh = Cast<UStaticMesh>(LoadObject(this, WheelMeshPath));
        if (ck::EnsureIfNot(ck::IsValid(WheelMesh), f"[HandWheel] Wheel mesh [{WheelMeshPath}] did not load - the hand wheel has no wheel to see or grip"))
        { return; }

        AddMesh(WheelTransform, FTransform(FRotator(90.0, 0.0, 0.0), FVector::ZeroVector, FVector(0.5, 0.5, 0.05)),
            WheelMesh, Material, collision::profile::NoCollision, n"HandWheel_Wheel");
        AddMesh(WheelTransform, FTransform(FRotator::ZeroRotator, FVector(4.0, 0.0, 0.0), FVector(0.04, 0.46, 0.06)),
            CubeMesh, Material, collision::profile::NoCollision, n"HandWheel_Spoke");
    }

    private void AddInteractable(FCk_Handle_Transform& InRoot)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(20.0, 30.0, 30.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(WheelDistance, 0.0, 0.0));

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(utils_control::Make_InteractTarget(Control, PromptText));

        utils_interactable::Create(InRoot, Spec);
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
        // Movable: the component receives the entity transform after registration, and the wheel turns.
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
