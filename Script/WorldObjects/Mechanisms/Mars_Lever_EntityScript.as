// Placeable floor lever. The origin is the pivot on the mounting surface and the handle points up local +Z; pulling
// pitches it by Lever.PulledAngle (positive leans toward local -X). Asserts an optional MechanismSource while pulled.
class UMars_Lever_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Lever_Spec Lever;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "PullLeverPrompt", "Pull lever");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto LeverRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsLever");

        auto LeverHandle = utils_lever::Add(LeverRoot, Lever);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(LeverRoot, LeverHandle);
        AddInteractable(LeverRoot);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_Lever InLever)
    {
        auto CubeMesh = engine::load::Cube();
        auto CylinderMesh = engine::load::Cylinder();

        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine shapes are 100 uu with a centered pivot; the cylinder's axis is Z, rolled onto Y to form the axle.
        AddMesh(InRoot, FTransform(FRotator(0.0, 0.0, 90.0), FVector::ZeroVector, FVector(0.24, 0.24, 0.5)),
            CylinderMesh, Material, collision::profile::BlockAll, n"Lever_Base");

        // On a child of the handle node so the node's offset stays a pure pull rotation about the pivot.
        auto HandleNode = InLever.Get_HandleNode();
        auto HandleTransform = HandleNode.As_Transform();
        AddMesh(HandleTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 45.0), FVector(0.08, 0.08, 0.9)),
            CubeMesh, Material, collision::profile::NoCollision, n"Lever_Handle");
    }

    private void AddInteractable(FCk_Handle_Transform& InRoot)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(40.0, 40.0, 55.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 45.0));

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = PromptText;

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant);

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_Lever_Pull;

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
        // Movable: the component receives the entity transform after registration, and the handle moves.
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
