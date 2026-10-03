// Placeable floor lever. The origin is the pivot on the mounting surface and the handle points up local +Z; activating
// pitches it by PulledAngle (positive leans toward local -X). Asserts an optional MechanismSource while active.
class UMars_Lever_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Control_Spec Control;
    // The handle top pitches toward local -X; read only when Control.Interaction is ManuallyCompleted.
    default Control.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    // Handle pitch when active. The Mover lerps it per component, so any angle is safe.
    UPROPERTY(ExposeOnSpawn)
    float32 PulledAngle = 70.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 MoveDuration = 0.35f;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "PullLeverPrompt", "Pull lever");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto LeverRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsLever");

        auto HandleNode = utils_scene_node::Create(LeverRoot, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndRotation = FRotator(PulledAngle, 0.0, 0.0);
        MoverSpec.Duration = MoveDuration;
        MoverSpec.StartPose = Control.StartActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start;
        auto Mover = utils_mover::Add(HandleNode, MoverSpec);

        auto ControlHandle = utils_control::Add(InHandle, Control, Mover);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(LeverRoot, HandleNode);
        AddInteractable(LeverRoot, ControlHandle);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InHandleNode)
    {
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine shapes are 100 uu with a centered pivot; the cylinder's axis is Z, rolled onto Y to form the axle.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator(0.0, 0.0, 90.0), FVector::ZeroVector, FVector(0.24, 0.24, 0.5)),
            engine::load::Cylinder(), Material, collision::profile::BlockAll, n"Lever_Base"));

        // On a child of the handle node so the node's offset stays a pure pull rotation about the pivot. The handle mesh
        // carries a Grip socket near the top of the bar: the first-person gloves reach for it.
        auto HandleTransform = InHandleNode.As_Transform();
        HandleTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 45.0), FVector(0.08, 0.08, 0.9)),
            assets::load::LeverHandle_Mars_SM(), Material, collision::profile::NoCollision, n"Lever_Handle"));
    }

    private void AddInteractable(FCk_Handle_Transform& InRoot, const FCk_Handle_Control& InControl)
    {
        // A rejected Control spec already ensured in utils_control::Add.
        if (ck::Is_NOT_Valid(InControl))
        { return; }

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(40.0, 40.0, 55.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 45.0));

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(InControl.Make_InteractTarget(PromptText));

        utils_interactable::Create(InRoot, Spec);
    }
}
