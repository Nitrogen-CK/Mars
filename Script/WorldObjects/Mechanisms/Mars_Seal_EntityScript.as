enum EMars_Seal_Glyph
{
    Square,
    Circle,
    // Apex toward the seal's local -X: up when the seal is pitched -90 onto a wall.
    Triangle
}

// Placeable seal: a wall plate with a push button carrying a glyph tinted GlyphColor, shaped by Glyph. The origin is the mounting
// surface and the button faces local +Z (pitch -90 to face +X on a wall). Momentary by default: pressing pulses the
// active state for Control.ActiveSeconds. Asserts an optional MechanismSource while active.
class UMars_Seal_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Control_Spec Control;
    default Control.Behavior = EMars_Control_Behavior::Momentary;
    default Control.ActiveSeconds = 0.4f;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UPROPERTY(ExposeOnSpawn)
    FLinearColor GlyphColor = FLinearColor(0.2f, 0.8f, 1.0f, 1.0f);

    UPROPERTY(ExposeOnSpawn)
    EMars_Seal_Glyph Glyph = EMars_Seal_Glyph::Square;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "PressSealPrompt", "Press seal");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto SealRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsSeal");

        auto ButtonNode = utils_scene_node::Create(SealRoot, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = FVector(0.0, 0.0, -6.0);
        MoverSpec.Duration = 0.12f;
        MoverSpec.StartAtEnd = Control.StartActive;
        auto Mover = utils_mover::Add(ButtonNode, MoverSpec);

        auto ControlHandle = utils_control::Add(InHandle, Control, Mover);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(SealRoot, ButtonNode);
        AddInteractable(SealRoot, ControlHandle);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InButtonNode)
    {
        auto CubeMesh = engine::load::Cube();
        auto CylinderMesh = engine::load::Cylinder();
        auto ConeMesh = engine::load::Cone();

        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine shapes are 100 uu with a centered pivot. Plate: 40 x 40 x 6; button: 20 across, 8 tall, on top of it;
        // glyph: about 12 across, 1 thick, on the button face.
        AddMesh(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 3.0), FVector(0.4, 0.4, 0.06)),
            MakeArchetype(CubeMesh, Material, collision::profile::BlockAll), n"Seal_Plate");

        // On children of the button node so the node's offset stays a pure press translation.
        auto ButtonTransform = InButtonNode.As_Transform();
        AddMesh(ButtonTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 10.0), FVector(0.2, 0.2, 0.08)),
            MakeArchetype(CylinderMesh, Material, collision::profile::NoCollision), n"Seal_Button");

        auto GlyphMesh = CubeMesh;
        auto GlyphTransform = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 14.5), FVector(0.12, 0.12, 0.01));
        if (Glyph == EMars_Seal_Glyph::Circle)
        {
            GlyphMesh = CylinderMesh;
            GlyphTransform.SetScale3D(FVector(0.13, 0.13, 0.01));
        }
        else if (Glyph == EMars_Seal_Glyph::Triangle)
        {
            // Pitch 90 lays the cone's axis (its +Z, apex) along the button's -X and its local X along the button's face
            // normal, which the 0.01 flattens.
            GlyphMesh = ConeMesh;
            GlyphTransform = FTransform(FRotator(90.0, 0.0, 0.0), FVector(0.0, 0.0, 14.5), FVector(0.01, 0.15, 0.13));
        }

        auto GlyphArchetype = MakeArchetype(GlyphMesh, Material, collision::profile::NoCollision);
        if (ck::IsValid(GlyphArchetype))
        {
            // On the archetype: the hosted component is instanced from it later and shares its override material.
            auto GlyphMaterial = GlyphArchetype.CreateDynamicMaterialInstance(0);
            if (ck::IsValid(GlyphMaterial))
            { GlyphMaterial.SetVectorParameterValue(n"PrimaryColor", GlyphColor); }
        }
        AddMesh(ButtonTransform, GlyphTransform, GlyphArchetype, n"Seal_Glyph");
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

    // NewObject needs a UObject outer, hence a private method on the entity script.
    private UStaticMeshComponent MakeArchetype(UStaticMesh InMesh, UMaterialInterface InMaterial, FName InCollisionProfile)
    {
        if (ck::Is_NOT_Valid(InMesh))
        { return nullptr; }

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable: the component receives the entity transform after registration, and the button moves.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(InMesh);
        if (ck::IsValid(InMaterial))
        { Archetype.SetMaterial(0, InMaterial); }
        Archetype.SetCollisionProfileName(InCollisionProfile);
        return Archetype;
    }

    private void AddMesh(
        FCk_Handle_Transform& InAttachTo,
        FTransform InLocalTransform,
        UStaticMeshComponent InArchetype,
        FName InDebugName)
    {
        if (ck::Is_NOT_Valid(InArchetype))
        { return; }

        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);
        auto NodeEntity = FCk_Handle(Node);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            InArchetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        utils_unreal_component::Add(NodeEntity, ComponentParams);
    }
}
