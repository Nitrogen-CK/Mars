// Placeable chain bridge: a plank deck standing up across a channel's mouth and a windlass on the near bank whose chain
// runs along the ground to the deck's hinge posts. Gripping the wheel (Use) and dragging the look down or left hauls the
// deck down; dragging back pays it out. The deck stays where it is left (a ratchet). Once it lands it stays down and the
// optional Source asserts; further turning does nothing.
// The origin is the hinge line on the near bank's edge, at floor level; local +Y runs across the water, where the deck
// lies when down.
struct FMars_ChainBridge_Spec
{
    UPROPERTY()
    float64 DeckLength = 420.0;

    UPROPERTY()
    float64 DeckWidth = 300.0;

    UPROPERTY()
    float64 DeckThickness = 20.0;

    // How far the deck stands up from flat at the start, in degrees.
    UPROPERTY()
    float32 RaisedPitch = 80.0f;

    // Wheel turns for the full drop; one degree of pull is one degree of wheel roll.
    UPROPERTY()
    float32 TurnsToLower = 3.0f;

    // The windlass post's base in the bridge's frame; its +X is the face the wheel is on, toward the operator.
    UPROPERTY()
    FTransform WheelOffset = FTransform(FRotator(0.0, -90.0, 0.0), FVector(-300.0, -150.0, 0.0));

    // The deck's and the wheel's Mover duration for a full move.
    UPROPERTY()
    float32 LowerDuration = 1.5f;
}

mixin FMars_Validation Validate(const FMars_ChainBridge_Spec& Self)
{
    if (Self.TurnsToLower <= 0.0f)
    { return FMars_Validation(f"TurnsToLower [{Self.TurnsToLower}] must be positive"); }

    if (Self.DeckLength <= 0.0)
    { return FMars_Validation(f"DeckLength [{Self.DeckLength}] must be positive"); }

    if (Self.RaisedPitch <= 0.0f || Self.RaisedPitch > 90.0f)
    { return FMars_Validation(f"RaisedPitch [{Self.RaisedPitch}] must be in (0, 90]"); }

    if (Self.LowerDuration < 0.0f)
    { return FMars_Validation(f"LowerDuration [{Self.LowerDuration}] must not be negative"); }

    return FMars_Validation();
}

class UMars_ChainBridge_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_ChainBridge_Spec Bridge;

    // Optional: unwired while OutputChannel is unset (utils_mechanism_source::TryAdd). Asserted once the deck is down.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "CrankWindlassPrompt", "Crank windlass");

    private const float64 PostHalfSize = 20.0;
    private const float64 PostHeight = 120.0;
    private const float64 WheelHeight = 100.0;
    private const float64 WheelDistance = 30.0;
    private const float64 HingePostSize = 30.0;
    private const float64 HingePostHeight = 100.0;
    private const float64 LinkSize = 12.0;
    private const float64 LinkSpacing = 24.0;

    private FCk_Handle_Mover _Deck;
    private FCk_Handle_Mover _Wheel;
    private FCk_Handle_MechanismSource _Source;
    // Hauled degrees in [0, TurnsToLower * 360]; positive hauls the deck down.
    private float32 _HauledDegrees = 0.0f;
    private bool _IsDown = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsChainBridge");

        const auto Validation = Bridge.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[ChainBridge] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        _Source = utils_mechanism_source::TryAdd(InHandle, Source);

        AddDeck(Root);
        AddHingePosts(Root);
        AddWindlass(Root);
        AddChain(Root);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private float32 Get_FullDegrees() const
    {
        return Bridge.TurnsToLower * 360.0f;
    }

    private float64 Get_HingePostX() const
    {
        return Bridge.DeckWidth * 0.5 + HingePostSize * 0.5;
    }

    // Raised is a roll about the hinge (local X): a negative roll stands +Y up.
    private void AddDeck(FCk_Handle_Transform& InRoot)
    {
        auto DeckNode = utils_scene_node::Create(InRoot, FTransform::Identity);
        auto DeckEntity = DeckNode.H();
        utils_entity_tag::Add(DeckEntity, n"TAG_MarsChainBridgeDeck");

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartRotation = FRotator(0.0, 0.0, -Bridge.RaisedPitch);
        MoverSpec.Duration = Bridge.LowerDuration;
        _Deck = utils_mover::Add(DeckNode, MoverSpec);

        // Near edge on the hinge, top at Z 0 when flat. The moving deck is dynamic, like a gate's leaf.
        auto DeckTransform = DeckNode.As_Transform();
        DeckTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, Bridge.DeckLength * 0.5, -Bridge.DeckThickness * 0.5),
                FVector(Bridge.DeckWidth, Bridge.DeckLength, Bridge.DeckThickness) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Platform_Mars_MI(), collision::profile::BlockAllDynamic, n"ChainBridge_Deck"));
    }

    private void AddHingePosts(FCk_Handle_Transform& InRoot)
    {
        const auto Scale = FVector(HingePostSize, HingePostSize, HingePostHeight) * 0.01;
        for (const auto Side : Get_Sides())
        {
            InRoot.Add_MeshPart(this, FMars_MeshPart(
                FTransform(FRotator::ZeroRotator, FVector(Side * Get_HingePostX(), -HingePostSize * 0.5, HingePostHeight * 0.5), Scale),
                engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"ChainBridge_HingePost"));
        }
    }

    private TArray<float64> Get_Sides() const
    {
        TArray<float64> Sides;
        Sides.Add(-1.0);
        Sides.Add(1.0);
        return Sides;
    }

    // The windlass node sits on the post's +X face at wheel height, like a hand wheel's mounting surface: the Control and
    // the interactable live on it (so PullAxis reads in its frame), the rolling wheel on a child.
    private void AddWindlass(FCk_Handle_Transform& InRoot)
    {
        const auto Mount = FTransform(FVector(PostHalfSize, 0.0, WheelHeight)) * Bridge.WheelOffset;
        auto WindlassNode = utils_scene_node::Create(InRoot, Mount);
        auto WindlassEntity = WindlassNode.H();
        utils_entity_tag::Add(WindlassEntity, n"TAG_MarsChainBridgeWindlass");
        auto WindlassTransform = WindlassNode.As_Transform();

        auto CubeMesh = engine::load::Cube();
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        WindlassTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(-PostHalfSize, 0.0, PostHeight * 0.5 - WheelHeight),
                FVector(PostHalfSize * 2.0, PostHalfSize * 2.0, PostHeight) * 0.01),
            CubeMesh, assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"ChainBridge_WindlassPost"));
        WindlassTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(WheelDistance * 0.5, 0.0, 0.0), FVector(WheelDistance * 0.01, 0.12, 0.12)),
            CubeMesh, Material, collision::profile::BlockAll, n"ChainBridge_Pipe"));

        // One alpha drives the deck and the wheel: the wheel's end pose is the whole haul's roll.
        const auto WheelLocation = FVector(WheelDistance, 0.0, 0.0);
        auto WheelNode = utils_scene_node::Create(WindlassTransform, FTransform(FRotator::ZeroRotator, WheelLocation));
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = WheelLocation;
        MoverSpec.EndLocation = WheelLocation;
        MoverSpec.EndRotation = FRotator(0.0, 0.0, Get_FullDegrees());
        MoverSpec.Duration = Bridge.LowerDuration;
        _Wheel = utils_mover::Add(WheelNode, MoverSpec);

        // As the hand wheel: the mesh's Z pitched onto X (the roll axis), Grip_R / Grip_L sockets on the rim, a spoke.
        auto WheelTransform = WheelNode.As_Transform();
        WheelTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator(90.0, 0.0, 0.0), FVector::ZeroVector, FVector(0.5, 0.5, 0.05)),
            assets::load::HandWheel_Mars_SM(), Material, collision::profile::NoCollision, n"ChainBridge_Wheel"));
        WheelTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(4.0, 0.0, 0.0), FVector(0.04, 0.46, 0.06)),
            CubeMesh, Material, collision::profile::NoCollision, n"ChainBridge_Spoke"));

        // Positive roll turns the wheel counter-clockwise as the operator (on +X) sees it, which a drag left (local +Y) or
        // down (local -Z) on its rim does.
        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.Mode = EMars_Control_ManipulationMode::FreeTurn;
        ControlSpec.Manipulation.PullAxis = FVector(0.0, 1.0, -1.0);
        auto Control = utils_control::Add(WindlassEntity, ControlSpec);

        // A rejected Control spec already ensured in utils_control::Add.
        if (ck::Is_NOT_Valid(Control))
        { return; }

        Control.BindTo_OnTurned(FMars_Delegate_Control_OnTurned(this, n"OnWheelTurned"));

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(20.0, 30.0, 30.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, WheelLocation);

        auto InteractSpec = FMars_Interactable_Spec();
        InteractSpec.ProbeInfo = Probe;
        InteractSpec.Targets.Add(Control.Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, PromptText)));
        utils_interactable::Create(WindlassTransform, InteractSpec);
    }

    // Dressing only: a dotted run along the ground from the windlass post to each hinge post, then up each post to the
    // deck's near corner.
    private void AddChain(FCk_Handle_Transform& InRoot)
    {
        const auto WindlassBase = Bridge.WheelOffset.GetLocation() + FVector(0.0, 0.0, LinkSize * 0.5);
        for (const auto Side : Get_Sides())
        {
            const auto PostBase = FVector(Side * Get_HingePostX(), -HingePostSize * 0.5, LinkSize * 0.5);
            AddLinks(InRoot, FMars_ChainBridge_LinkRun(WindlassBase, PostBase, PostHalfSize));

            const auto PostTop = FVector(Side * Get_HingePostX(), -HingePostSize * 0.5, HingePostHeight);
            const auto DeckCorner = FVector(Side * Bridge.DeckWidth * 0.5, 0.0, 0.0);
            AddLinks(InRoot, FMars_ChainBridge_LinkRun(PostTop, DeckCorner, 0.0));
        }
    }

    // Links every LinkSpacing from the run's start, keeping InRun.EndClearance clear at both ends (inside the posts).
    private void AddLinks(FCk_Handle_Transform& InRoot, const FMars_ChainBridge_LinkRun& InRun)
    {
        const auto Span = InRun.To - InRun.From;
        const auto Length = Span.Size();
        if (Length <= InRun.EndClearance * 2.0)
        { return; }

        const auto Direction = Span / Length;
        const auto Rotation = Direction.Rotation();
        const auto Scale = FVector(LinkSize, LinkSize, LinkSize) * 0.01;
        for (auto Distance = Math::Max(InRun.EndClearance, LinkSpacing * 0.5); Distance <= Length - InRun.EndClearance; Distance += LinkSpacing)
        {
            InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform(Rotation, InRun.From + Direction * Distance, Scale),
                engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"ChainBridge_Link"));
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnWheelTurned(FCk_Handle_Control InControl, float32 InDegrees)
    {
        if (_IsDown)
        { return; }

        const auto FullDegrees = Get_FullDegrees();
        _HauledDegrees = Math::Clamp(_HauledDegrees + InDegrees, 0.0f, FullDegrees);
        const auto Alpha = _HauledDegrees / FullDegrees;
        _Deck.Request_Scrub(FMars_Request_Mover_Scrub(Alpha));
        _Wheel.Request_Scrub(FMars_Request_Mover_Scrub(Alpha));

        if (Alpha < 1.0f)
        { return; }

        // Down for good: the end pose becomes both Movers' target, so they rest there.
        _IsDown = true;
        _Deck.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::End));
        _Wheel.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::End));

        if (ck::IsValid(_Source))
        { _Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(EMars_MechanismSource_Output::Asserted)); }
    }
}

// One straight run of chain links, in the bridge's frame.
struct FMars_ChainBridge_LinkRun
{
    FVector From;
    FVector To;
    float64 EndClearance = 0.0;

    FMars_ChainBridge_LinkRun() {}

    FMars_ChainBridge_LinkRun(FVector InFrom, FVector InTo, float64 InEndClearance)
    {
        From = InFrom;
        To = InTo;
        EndClearance = InEndClearance;
    }
}
