enum EMars_Gate_Leaf
{
    // One slab: nothing behind the gate shows.
    Solid,
    // A portcullis of upright bars and two rails: what lies behind the gate shows through, nothing passes.
    Bars
}

// Placeable gate: a static frame (two posts + lintel) around a ~200 x 220 opening, and a leaf on the gate's moving
// node that blocks the opening when closed and rises by Gate.OpenOffset when open. Opened by an optional
// MechanismSink; reports its open state through an optional MechanismSource.
class UMars_Gate_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Gate_Spec Gate;

    // No sink is added while InputChannels is empty.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSink_Spec Sink;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UPROPERTY(ExposeOnSpawn)
    EMars_Gate_Leaf Leaf = EMars_Gate_Leaf::Solid;

    // Set: a close waits until no player and no dropped backpack stands in the doorway (a box over the opening reaching
    // k_ThresholdDepth either side of the leaf). Fills Gate.Threshold unless the spec already sets one.
    UPROPERTY(ExposeOnSpawn)
    bool WaitsForClearThreshold = false;

    // Engine cube is 100 uu, pivot at its center. The opening spans local Y (width) and Z (height).
    private const float64 k_OpeningWidth = 200.0;
    private const float64 k_OpeningHeight = 220.0;
    private const float64 k_ThresholdDepth = 80.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto GateRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsGate");

        auto GateSpec = Gate;
        if (WaitsForClearThreshold && GateSpec.Threshold.IsSet() == false)
        { GateSpec.Threshold = Make_ThresholdSpec(); }

        auto GateHandle = utils_gate::Add(GateRoot, GateSpec);

        if (Sink.InputChannels.Num() > 0)
        { utils_mechanism_sink::Add(InHandle, Sink); }

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(GateRoot, GateHandle);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private FMars_Trigger_Spec Make_ThresholdSpec() const
    {
        auto Spec = FMars_Trigger_Spec();
        Spec.Shape = EMars_Trigger_Shape::Box;
        Spec.BoxHalfExtents = FVector(k_ThresholdDepth, k_OpeningWidth * 0.5, k_OpeningHeight * 0.5);
        Spec.LocalOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, k_OpeningHeight * 0.5));
        Spec.DetectionFilter.AddTag(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Player"));
        Spec.DetectionFilter.AddTag(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Backpack"));
        return Spec;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_Gate InGate)
    {
        auto CubeMesh = engine::load::Cube();
        if (ck::Is_NOT_Valid(CubeMesh))
        { return; }

        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();

        const float64 OpeningWidth = k_OpeningWidth;
        const float64 OpeningHeight = k_OpeningHeight;
        const float64 FrameThickness = 20.0;
        const float64 FrameDepth = 40.0;
        const float64 LeafThickness = 10.0;

        const auto PostY = (OpeningWidth + FrameThickness) * 0.5;
        const auto FrameHeight = OpeningHeight + FrameThickness;
        const auto PostScale = FVector(FrameDepth, FrameThickness, FrameHeight) * 0.01;

        AddBox(InRoot, FVector(0.0, -PostY, FrameHeight * 0.5), PostScale,
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"GateFrame_PostLeft");
        AddBox(InRoot, FVector(0.0, PostY, FrameHeight * 0.5), PostScale,
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"GateFrame_PostRight");
        AddBox(InRoot, FVector(0.0, 0.0, OpeningHeight + FrameThickness * 0.5),
            FVector(FrameDepth, OpeningWidth + FrameThickness * 2.0, FrameThickness) * 0.01,
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"GateFrame_Lintel");

        // The leaf sits on children of the moving node so the node's offset stays a pure open/closed translation.
        auto MovingNode = InGate.Get_MovingNode();
        auto MovingTransform = MovingNode.As_Transform();
        if (Leaf == EMars_Gate_Leaf::Bars)
        {
            AddBars(MovingTransform, CubeMesh, WallMaterial);
            return;
        }

        AddBox(MovingTransform, FVector(0.0, 0.0, OpeningHeight * 0.5),
            FVector(LeafThickness, OpeningWidth, OpeningHeight) * 0.01,
            CubeMesh, WallMaterial, collision::profile::BlockAllDynamic, n"GateLeaf");
    }

    // Upright bars k_BarSpacing apart (gaps no capsule or loose item fits through) and two rails across them.
    private void AddBars(FCk_Handle_Transform& InMovingTransform, UStaticMesh InCubeMesh, UMaterialInterface InMaterial)
    {
        const float64 BarThickness = 8.0;
        const float64 BarSpacing = 25.0;
        const float64 RailHeight = 10.0;

        const auto BarCount = int32(k_OpeningWidth / BarSpacing);
        const auto FirstY = -(BarCount - 1) * BarSpacing * 0.5;
        for (int32 Index = 0; Index < BarCount; ++Index)
        {
            AddBox(InMovingTransform, FVector(0.0, FirstY + Index * BarSpacing, k_OpeningHeight * 0.5),
                FVector(BarThickness, BarThickness, k_OpeningHeight) * 0.01,
                InCubeMesh, InMaterial, collision::profile::BlockAllDynamic, n"GateLeaf_Bar");
        }

        const auto RailScale = FVector(BarThickness + 4.0, k_OpeningWidth, RailHeight) * 0.01;
        AddBox(InMovingTransform, FVector(0.0, 0.0, k_OpeningHeight - RailHeight * 0.5), RailScale,
            InCubeMesh, InMaterial, collision::profile::BlockAllDynamic, n"GateLeaf_RailTop");
        AddBox(InMovingTransform, FVector(0.0, 0.0, k_OpeningHeight * 0.4), RailScale,
            InCubeMesh, InMaterial, collision::profile::BlockAllDynamic, n"GateLeaf_RailMid");
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
        // Movable even for the frame: the component is registered first and then receives the entity transform,
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
