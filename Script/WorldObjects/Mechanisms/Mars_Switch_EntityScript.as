// Placeable momentary push switch. The origin is the mounting surface and the button faces local +Z (pitch -90 to
// face +X on a wall); pressing moves it by Switch.PressOffset and it releases after Switch.HoldSeconds. Asserts an
// optional MechanismSource while pressed.
class UMars_Switch_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Switch_Spec Switch;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "PressSwitchPrompt", "Press switch");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto SwitchRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsSwitch");

        auto SwitchHandle = utils_switch::Add(SwitchRoot, Switch);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(SwitchRoot, SwitchHandle);
        AddInteractable(SwitchRoot);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_Switch InSwitch)
    {
        auto CubeMesh = engine::load::Cube();
        auto CylinderMesh = engine::load::Cylinder();

        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine shapes are 100 uu with a centered pivot. Plate: 30 x 30 x 6; button: 16 across, 8 tall, on top of it.
        AddMesh(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 3.0), FVector(0.3, 0.3, 0.06)),
            CubeMesh, Material, collision::profile::BlockAll, n"Switch_Plate");

        // On a child of the button node so the node's offset stays a pure press translation.
        auto ButtonNode = InSwitch.Get_ButtonNode();
        auto ButtonTransform = ButtonNode.As_Transform();
        AddMesh(ButtonTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 10.0), FVector(0.16, 0.16, 0.08)),
            CylinderMesh, Material, collision::profile::NoCollision, n"Switch_Button");
    }

    private void AddInteractable(FCk_Handle_Transform& InRoot)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(30.0, 30.0, 20.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 10.0));

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = PromptText;

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant);

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_Switch_Press;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);

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
        // Movable: the component receives the entity transform after registration, and the button moves.
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
