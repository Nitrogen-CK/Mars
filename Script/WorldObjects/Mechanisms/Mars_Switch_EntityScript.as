// Placeable push switch. The origin is the mounting surface and the button faces local +Z (pitch -90 to face +X on a
// wall); activating moves the button by PressOffset. Momentary by default: it releases Control.ActiveSeconds after the
// last press. Asserts an optional MechanismSource while active.
class UMars_Switch_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Control_Spec Control;
    default Control.Behavior = EMars_Control_Behavior::Momentary;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    // Button node local offset while active.
    UPROPERTY(ExposeOnSpawn)
    FVector PressOffset = FVector(0.0, 0.0, -6.0);

    UPROPERTY(ExposeOnSpawn)
    float32 MoveDuration = 0.15f;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "PressSwitchPrompt", "Press switch");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto SwitchRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsSwitch");

        auto ButtonNode = utils_scene_node::Create(SwitchRoot, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = PressOffset;
        MoverSpec.Duration = MoveDuration;
        MoverSpec.StartPose = Control.StartActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start;
        auto Mover = utils_mover::Add(ButtonNode, MoverSpec);

        auto ControlHandle = utils_control::Add(InHandle, Control, Mover);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(SwitchRoot, ButtonNode);
        AddInteractable(SwitchRoot, ControlHandle);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InButtonNode)
    {
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine shapes are 100 uu with a centered pivot. Plate: 30 x 30 x 6; button: 16 across, 8 tall, on top of it.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 3.0), FVector(0.3, 0.3, 0.06)),
            engine::load::Cube(), Material, collision::profile::BlockAll, n"Switch_Plate"));

        // On a child of the button node so the node's offset stays a pure press translation.
        auto ButtonTransform = InButtonNode.As_Transform();
        ButtonTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 10.0), FVector(0.16, 0.16, 0.08)),
            engine::load::Cylinder(), Material, collision::profile::NoCollision, n"Switch_Button"));
    }

    private void AddInteractable(FCk_Handle_Transform& InRoot, const FCk_Handle_Control& InControl)
    {
        // A rejected Control spec already ensured in utils_control::Add.
        if (ck::Is_NOT_Valid(InControl))
        { return; }

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(30.0, 30.0, 20.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 10.0));

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(InControl.Make_InteractTarget(PromptText));

        utils_interactable::Create(InRoot, Spec);
    }
}
