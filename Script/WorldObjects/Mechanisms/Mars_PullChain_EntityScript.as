// Placeable pull chain. The origin is the bracket on the mounting surface; local +X points out of it and the chain hangs
// along -Z, ending in a grip bar ChainLength below the bracket. Use grips the bar and the look input pulls it down by
// PullDistance; past the threshold the chain engages and springs back up, so every pull is one engagement. Asserts an
// optional MechanismSource for Control.ActiveSeconds after each pull (a short pulse that a Countdown reads as a charge).
class UMars_PullChain_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Pulled, momentary, springing back. A re-pull needs a new grip, which takes longer than ActiveSeconds, so each pull
    // is a fresh rising edge on the source.
    UPROPERTY(ExposeOnSpawn)
    FMars_Control_Spec Control;
    default Control.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
    default Control.Behavior = EMars_Control_Behavior::Momentary;
    default Control.ActiveSeconds = 0.25f;
    default Control.Manipulation.PullAxis = FVector(0.0, 0.0, -1.0);
    default Control.Manipulation.AlphaPerDegree = 0.03f;
    default Control.Manipulation.ReturnsToRest = true;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    // How far the grip bar travels down when pulled all the way (cm).
    UPROPERTY(ExposeOnSpawn)
    float32 PullDistance = 40.0f;

    // Bracket to grip bar (cm).
    UPROPERTY(ExposeOnSpawn)
    float32 ChainLength = 110.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 MoveDuration = 0.3f;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "PullChainPrompt", "Pull chain");

    // The chain hangs this far out from the mounting surface (cm).
    private const float64 ChainOffsetX = 18.0;
    private const float64 GripLength = 24.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto ChainRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsPullChain");

        auto ChainNode = utils_scene_node::Create(ChainRoot, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = FVector(0.0, 0.0, -PullDistance);
        MoverSpec.Duration = MoveDuration;
        auto Mover = utils_mover::Add(ChainNode, MoverSpec);

        auto ControlHandle = utils_control::Add(InHandle, Control, Mover);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(ChainRoot, ChainNode);
        AddInteractable(ChainRoot, ControlHandle);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InChainNode)
    {
        auto CubeMesh = engine::load::Cube();
        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine cube is 100 uu, pivot at its center. The bracket arm reaches out to a housing the chain runs through.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(ChainOffsetX * 0.5, 0.0, 0.0), FVector(ChainOffsetX, 8.0, 8.0) * 0.01),
            CubeMesh, WallMaterial, collision::profile::NoCollision, n"PullChain_Bracket"));
        // Tall enough to hide the reserve chain that a full pull draws out.
        const auto HousingHeight = PullDistance + 14.0;
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(ChainOffsetX, 0.0, HousingHeight * 0.5 - 7.0), FVector(14.0, 14.0, HousingHeight) * 0.01),
            CubeMesh, WallMaterial, collision::profile::NoCollision, n"PullChain_Housing"));

        // Links and grip ride the chain node, so the node's offset stays a pure pull translation. The links start inside the
        // housing so pulling draws more chain out of it.
        auto ChainTransform = InChainNode.As_Transform();
        const float64 LinkPitch = 8.0;
        // From the top of the reserve inside the housing down to the grip bar, inclusive.
        const auto LinkCount = Math::FloorToInt(float(ChainLength + PullDistance) / LinkPitch) + 1;
        for (int32 Index = 0; Index < LinkCount; ++Index)
        {
            const auto LinkZ = PullDistance - Index * LinkPitch;

            // Alternating links turned 90 degrees, like a real chain.
            const auto LinkYaw = (Index % 2 == 0) ? 0.0 : 90.0;
            ChainTransform.Add_MeshPart(this, FMars_MeshPart(
                FTransform(FRotator(0.0, LinkYaw, 0.0), FVector(ChainOffsetX, 0.0, LinkZ), FVector(1.5, 4.0, 7.0) * 0.01),
                CubeMesh, Material, collision::profile::NoCollision, n"PullChain_Link"));
        }

        // The grip bar carries a Grip socket, so the first-person gloves take hold of it and follow it down.
        ChainTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(ChainOffsetX, 0.0, -ChainLength - GripLength * 0.5), FVector(0.06, 0.06, GripLength * 0.01)),
            assets::load::LeverHandle_Mars_SM(), Material, collision::profile::NoCollision, n"PullChain_Grip"));
    }

    private void AddInteractable(FCk_Handle_Transform& InRoot, const FCk_Handle_Control& InControl)
    {
        // A rejected Control spec already ensured in utils_control::Add.
        if (ck::Is_NOT_Valid(InControl))
        { return; }

        // Covers the grip bar over its whole travel.
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(20.0, 20.0, 15.0 + PullDistance * 0.5)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(ChainOffsetX, 0.0, -ChainLength - GripLength * 0.5 - PullDistance * 0.5));

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(InControl.Make_InteractTarget(PromptText));

        utils_interactable::Create(InRoot, Spec);
    }
}
