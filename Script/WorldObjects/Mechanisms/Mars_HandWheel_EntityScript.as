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
    default Control.Interaction = ECk_Interaction_CompletionPolicy::Timed;
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
        MoverSpec.StartPose = Control.StartActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start;
        auto Mover = utils_mover::Add(WheelNode, MoverSpec);

        auto ControlHandle = utils_control::Add(InHandle, Control, Mover);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(WheelRoot, WheelNode);
        AddInteractable(WheelRoot, ControlHandle);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InWheelNode)
    {
        auto CubeMesh = engine::load::Cube();
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine shapes are 100 uu with a centered pivot. Pipe: 12 x 12 from the wall to the wheel.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(WheelDistance * 0.5, 0.0, 0.0), FVector(WheelDistance * 0.01, 0.12, 0.12)),
            CubeMesh, Material, collision::profile::BlockAll, n"HandWheel_Pipe"));

        // Wheel: 50 across, 5 thick; the mesh's Z axis is pitched onto X, the roll axis. Grip_R / Grip_L sockets on the
        // rim at 2 and 10 o'clock let the first-person gloves take it with both hands. The spoke makes the turn readable
        // on an otherwise symmetric disc.
        auto WheelTransform = InWheelNode.As_Transform();
        WheelTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator(90.0, 0.0, 0.0), FVector::ZeroVector, FVector(0.5, 0.5, 0.05)),
            assets::load::HandWheel_Mars_SM(), Material, collision::profile::NoCollision, n"HandWheel_Wheel"));
        WheelTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(4.0, 0.0, 0.0), FVector(0.04, 0.46, 0.06)),
            CubeMesh, Material, collision::profile::NoCollision, n"HandWheel_Spoke"));
    }

    private void AddInteractable(FCk_Handle_Transform& InRoot, const FCk_Handle_Control& InControl)
    {
        // A rejected Control spec already ensured in utils_control::Add.
        if (ck::Is_NOT_Valid(InControl))
        { return; }

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(20.0, 30.0, 30.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(WheelDistance, 0.0, 0.0));

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(InControl.Make_InteractTarget(PromptText));

        utils_interactable::Create(InRoot, Spec);
    }
}
