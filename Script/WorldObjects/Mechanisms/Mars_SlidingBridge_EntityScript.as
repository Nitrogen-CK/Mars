// One rigid cage span. Root local +Y crosses the gap; the seated deck spans Y [0, DeckLength], top Z 0.
// Retraction translates the entire cage by -Travel. Fixed bank floors, guard jambs/transoms and storage enclosure belong
// to the map. The terminal latch resets only with a fresh entity/world; this local prototype does not replicate.
struct FMars_SlidingBridge_Spec
{
    UPROPERTY()
    float64 DeckLength = 1050.0;

    UPROPERTY()
    float64 DeckWidth = 250.0;

    UPROPERTY()
    float64 DeckThickness = 20.0;

    UPROPERTY()
    float64 Travel = 1050.0;

    UPROPERTY()
    float64 CageHeight = 220.0;

    UPROPERTY()
    float64 CageWallThickness = 10.0;

    UPROPERTY()
    float64 CanopyThickness = 8.0;

    UPROPERTY()
    float32 TurnsToExtend = 3.0f;

    UPROPERTY()
    float32 MoveDuration = 1.5f;

    UPROPERTY()
    FTransform WheelOffset = FTransform(FRotator(0.0, -90.0, 0.0), FVector(-300.0, -150.0, 0.0));

    // The near guard is behind the entire stored leaf, preventing boarding while the span can move.
    UPROPERTY()
    FVector NearGuardOffset = FVector(0.0, -1100.0, -30.0);

    UPROPERTY()
    FVector FarGuardOffset = FVector(0.0, 1085.0, -30.0);

    UPROPERTY()
    float64 GuardWidth = 230.0;

    UPROPERTY()
    float64 GuardHeight = 220.0;

    UPROPERTY()
    float64 GuardThickness = 8.0;

    UPROPERTY()
    float64 GuardRaise = 220.0;

    UPROPERTY()
    float32 GuardMoveDuration = 0.8f;

    // Optional routed conduit/chain, in root-local coordinates. No implicit straight run through bank walls.
    UPROPERTY()
    TArray<FVector> DrivePath;
}

mixin FMars_Validation Validate(const FMars_SlidingBridge_Spec& Self)
{
    if (Math::IsFinite(Self.DeckLength) == false || Self.DeckLength <= 0.0
        || Math::IsFinite(Self.DeckWidth) == false || Self.DeckWidth <= 0.0
        || Math::IsFinite(Self.DeckThickness) == false || Self.DeckThickness <= 0.0
        || Math::IsFinite(Self.Travel) == false || Self.Travel < Self.DeckLength)
    { return FMars_Validation("Deck dimensions must be finite and positive; Travel must fully store the leaf"); }

    if (Math::IsFinite(Self.CageHeight) == false || Math::IsFinite(Self.CageWallThickness) == false
        || Math::IsFinite(Self.CanopyThickness) == false || Self.CageWallThickness <= 0.0
        || Self.CanopyThickness <= 0.0 || Self.CageHeight <= Self.CanopyThickness
        || Self.DeckWidth <= Self.CageWallThickness * 2.0)
    { return FMars_Validation("The cage must have finite positive walls, canopy and clear interior"); }

    if (Math::IsFinite(Self.TurnsToExtend) == false || Self.TurnsToExtend <= 0.0f
        || Math::IsFinite(Self.TurnsToExtend * 360.0f) == false
        || Math::IsFinite(Self.MoveDuration) == false || Self.MoveDuration < 0.0f
        || Math::IsFinite(Self.GuardMoveDuration) == false || Self.GuardMoveDuration < 0.0f)
    { return FMars_Validation("Turns must be finite and positive; mover durations finite and non-negative"); }

    if (Math::IsFinite(Self.GuardWidth) == false || Self.GuardWidth < Self.DeckWidth - Self.CageWallThickness * 2.0
        || Math::IsFinite(Self.GuardHeight) == false || Self.GuardHeight <= 0.0
        || Math::IsFinite(Self.GuardThickness) == false || Self.GuardThickness <= 0.0
        || Math::IsFinite(Self.GuardRaise) == false || Self.GuardRaise < Self.GuardHeight)
    { return FMars_Validation("Finite guard leaves must seal the clear width and raise at least their height"); }

    if (Self.NearGuardOffset.ContainsNaN() || Self.FarGuardOffset.ContainsNaN()
        || Math::Abs(Self.NearGuardOffset.X) > 0.01 || Math::Abs(Self.FarGuardOffset.X) > 0.01
        || Self.NearGuardOffset.Y + Self.GuardThickness * 0.5 >= -Self.Travel
        || Self.FarGuardOffset.Y - Self.GuardThickness * 0.5 <= Self.DeckLength
        || Self.NearGuardOffset.Z > 0.0 || Self.FarGuardOffset.Z > 0.0)
    { return FMars_Validation("Guards must align with the passage and stand beyond both the stored and seated leaf"); }

    if (Self.WheelOffset.ContainsNaN())
    { return FMars_Validation("WheelOffset must be finite"); }

    for (const auto Point : Self.DrivePath)
    {
        if (Point.ContainsNaN())
        { return FMars_Validation("DrivePath points must be finite"); }
    }

    return FMars_Validation();
}

class UMars_SlidingBridge_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_SlidingBridge_Spec Bridge;

    // StartAsserted is deliberately overridden: availability requires physical seating and both cleared guards.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "HaulSlidingBridgePrompt", "Haul bridge");

    // Overrides use centimetres and the root-local seated frame above, at identity scale. Supply matching simple
    // collision: one deck box, two side-screen boxes and a canopy box; deck top Z 0, cage clear width 230 and underside
    // Z 212 with the default spec. All mesh overrides, including guards, retain their authored material slots and supply
    // their own matching simple collision; there is no additional fallback hull when an override is set.
    UPROPERTY(ExposeOnSpawn)
    UStaticMesh DeckMeshOverride = nullptr;

    UPROPERTY(ExposeOnSpawn)
    UStaticMesh CageMeshOverride = nullptr;

    UPROPERTY(ExposeOnSpawn)
    UMaterialInterface MaterialOverride = nullptr;

    // Guard-local pivot at bottom Z 0; centred on X/Y. Default bounds X [-115,115], Y [-4,4], Z [0,220], with one box UCX.
    UPROPERTY(ExposeOnSpawn)
    UStaticMesh GuardMeshOverride = nullptr;

    UPROPERTY(ExposeOnSpawn)
    UStaticMesh WheelMeshOverride = nullptr;

    // Relative to the moving wheel node; used only with WheelMeshOverride.
    UPROPERTY(ExposeOnSpawn)
    FTransform WheelMeshLocalTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    UMaterialInterface WheelMaterialOverride = nullptr;

    private FCk_Handle_Transform _Root;
    private FCk_Handle_Mover _Deck;
    private FCk_Handle_Mover _Wheel;
    private FCk_Handle_Control _Windlass;
    private FCk_Handle_Gate _NearGuard;
    private FCk_Handle_Gate _FarGuard;
    private FCk_Handle_MechanismSource _Source;
    private FCk_Handle_Timer _VerificationTimer;
    private float32 _HauledDegrees = 0.0f;
    private bool _FullHaulRequested = false;
    private bool _GuardsRequested = false;
    private bool _Available = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsSlidingBridge");
        const auto Validation = Bridge.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[SlidingBridge] rejected the spec: {Validation.Get_Error()}"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto SourceSpec = Source;
        SourceSpec.StartAsserted = false;
        _Source = utils_mechanism_source::TryAdd(InHandle, SourceSpec);
        AddDeck();
        _NearGuard = AddGuard(Bridge.NearGuardOffset, n"TAG_MarsSlidingBridgeNearGuard");
        _FarGuard = AddGuard(Bridge.FarGuardOffset, n"TAG_MarsSlidingBridgeFarGuard");
        AddWindlass();
        AddDrivePath();
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Windlass))
        { _Windlass.UnbindFrom_OnTurned(FMars_Delegate_Control_OnTurned(this, n"OnWheelTurned")); }
        StopVerification();
    }

    private UMaterialInterface Get_Material() const
    {
        if (ck::IsValid(MaterialOverride))
        { return MaterialOverride; }
        return assets::load::ProtoGrid_Platform_Mars_MI();
    }

    private void AddDeck()
    {
        auto DeckNode = utils_scene_node::Create(_Root, FTransform(FVector(0.0, -Bridge.Travel, 0.0)));
        auto DeckEntity = DeckNode.H();
        utils_entity_tag::Add(DeckEntity, n"TAG_MarsSlidingBridgeDeck");
        auto Spec = FMars_Mover_Spec();
        Spec.StartLocation = FVector(0.0, -Bridge.Travel, 0.0);
        Spec.Duration = Bridge.MoveDuration;
        _Deck = utils_mover::Add(DeckNode, Spec);
        auto DeckTransform = DeckNode.As_Transform();

        FCk_Handle_UnrealComponent DeckPart;
        if (ck::IsValid(DeckMeshOverride))
        {
            DeckPart = DeckTransform.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity, DeckMeshOverride,
                nullptr, collision::profile::BlockAllDynamic, n"SlidingBridge_Deck"));
        }
        else
        {
            DeckPart = AddBox(DeckTransform, FTransform(FVector(0.0, Bridge.DeckLength * 0.5, -Bridge.DeckThickness * 0.5)),
                FVector(Bridge.DeckWidth, Bridge.DeckLength, Bridge.DeckThickness));
        }
        auto DeckPartEntity = DeckPart.H();
        utils_entity_tag::Add(DeckPartEntity, n"TAG_MarsSlidingBridgeDeckCollision");

        if (ck::IsValid(CageMeshOverride))
        {
            DeckTransform.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity, CageMeshOverride,
                nullptr, collision::profile::BlockAllDynamic, n"SlidingBridge_Cage"));
            return;
        }

        // Visible solid screens are the low-component fallback. Their collision matches their visible geometry.
        const auto SideX = (Bridge.DeckWidth - Bridge.CageWallThickness) * 0.5;
        AddBox(DeckTransform, FTransform(FVector(-SideX, Bridge.DeckLength * 0.5, Bridge.CageHeight * 0.5)),
            FVector(Bridge.CageWallThickness, Bridge.DeckLength, Bridge.CageHeight));
        AddBox(DeckTransform, FTransform(FVector(SideX, Bridge.DeckLength * 0.5, Bridge.CageHeight * 0.5)),
            FVector(Bridge.CageWallThickness, Bridge.DeckLength, Bridge.CageHeight));
        AddBox(DeckTransform, FTransform(FVector(0.0, Bridge.DeckLength * 0.5, Bridge.CageHeight - Bridge.CanopyThickness * 0.5)),
            FVector(Bridge.DeckWidth, Bridge.DeckLength, Bridge.CanopyThickness));
    }

    private FCk_Handle_UnrealComponent AddBox(FCk_Handle_Transform& InParent, FTransform InOffset, FVector InSize)
    {
        auto Offset = InOffset;
        Offset.SetScale3D(InSize * 0.01);
        return InParent.Add_MeshPart(this, FMars_MeshPart(Offset, engine::load::Cube(), Get_Material(),
            collision::profile::BlockAllDynamic, n"SlidingBridge_Solid"));
    }

    private FCk_Handle_Gate AddGuard(FVector InOffset, FName InTag)
    {
        auto Anchor = utils_scene_node::Create(_Root, FTransform(InOffset));
        auto Entity = Anchor.H();
        utils_entity_tag::Add(Entity, InTag);
        auto AnchorTransform = Anchor.As_Transform();
        auto Spec = FMars_Gate_Spec();
        Spec.OpenOffset = FVector(0.0, 0.0, Bridge.GuardRaise);
        Spec.MoveDuration = Bridge.GuardMoveDuration;
        auto Gate = utils_gate::Add(AnchorTransform, Spec);
        auto Leaf = Gate.Get_MovingNode().As_Transform();
        if (ck::IsValid(GuardMeshOverride))
        {
            Leaf.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity, GuardMeshOverride, nullptr,
                collision::profile::BlockAllDynamic, n"SlidingBridge_Guard"));
        }
        else
        {
            AddBox(Leaf, FTransform(FVector(0.0, 0.0, Bridge.GuardHeight * 0.5)),
                FVector(Bridge.GuardWidth, Bridge.GuardThickness, Bridge.GuardHeight));
        }
        return Gate;
    }

    private void AddWindlass()
    {
        auto Node = utils_scene_node::Create(_Root,
            FTransform(FVector(20.0, 0.0, 100.0)) * Bridge.WheelOffset);
        auto Entity = Node.H();
        utils_entity_tag::Add(Entity, n"TAG_MarsSlidingBridgeWindlass");
        auto Mount = Node.As_Transform();
        AddBox(Mount, FTransform(FVector(-20.0, 0.0, -40.0)), FVector(40.0, 40.0, 120.0));
        AddBox(Mount, FTransform(FVector(15.0, 0.0, 0.0)), FVector(30.0, 12.0, 12.0));

        const auto WheelLocation = FVector(30.0, 0.0, 0.0);
        auto WheelNode = utils_scene_node::Create(Mount, FTransform(WheelLocation));
        auto Spec = FMars_Mover_Spec();
        Spec.StartLocation = WheelLocation;
        Spec.EndLocation = WheelLocation;
        Spec.EndRotation = FRotator(0.0, 0.0, Bridge.TurnsToExtend * 360.0f);
        Spec.Duration = Bridge.MoveDuration;
        _Wheel = utils_mover::Add(WheelNode, Spec);
        auto WheelTransform = WheelNode.As_Transform();
        auto WheelMesh = WheelMeshOverride;
        auto WheelLocalTransform = WheelMeshLocalTransform;
        if (ck::Is_NOT_Valid(WheelMesh))
        {
            WheelMesh = assets::load::HandWheel_Mars_SM();
            WheelLocalTransform = FTransform(FRotator(90.0, 0.0, 0.0), FVector::ZeroVector, FVector(0.5, 0.5, 0.05));
        }
        UMaterialInterface WheelMaterial = assets::load::ProtoGrid_Interactable_Mars_MI();
        if (ck::IsValid(WheelMaterialOverride))
        { WheelMaterial = WheelMaterialOverride; }
        WheelTransform.Add_MeshPart(this, FMars_MeshPart(WheelLocalTransform, WheelMesh, WheelMaterial,
            collision::profile::NoCollision, n"SlidingBridge_Wheel"));
        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.Mode = EMars_Control_ManipulationMode::FreeTurn;
        ControlSpec.Manipulation.PullAxis = FVector(0.0, 1.0, -1.0);
        _Windlass = utils_control::Add(Entity, ControlSpec);
        if (ck::Is_NOT_Valid(_Windlass))
        { return; }
        _Windlass.BindTo_OnTurned(FMars_Delegate_Control_OnTurned(this, n"OnWheelTurned"));
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(20.0, 30.0, 30.0)));
        Probe.ProbeOffset = FTransform(WheelLocation);
        auto InteractSpec = FMars_Interactable_Spec();
        InteractSpec.ProbeInfo = Probe;
        InteractSpec.Targets.Add(_Windlass.Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, PromptText)));
        utils_interactable::Create(Mount, InteractSpec);
    }

    private void AddDrivePath()
    {
        for (int32 Index = 1; Index < Bridge.DrivePath.Num(); ++Index)
        {
            const auto From = Bridge.DrivePath[Index - 1];
            const auto To = Bridge.DrivePath[Index];
            const auto Span = To - From;
            if (Span.IsNearlyZero())
            { continue; }
            _Root.Add_MeshPart(this, FMars_MeshPart(
                FTransform(Span.Rotation(), (From + To) * 0.5, FVector(Span.Size(), 6.0, 6.0) * 0.01),
                engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(),
                collision::profile::NoCollision, n"SlidingBridge_DrivePath"));
        }
    }

    UFUNCTION()
    private void OnWheelTurned(FCk_Handle_Control InControl, float32 InDegrees)
    {
        if (ck::Is_NOT_Valid(_Root) || ck::Is_NOT_Valid(_Deck) || ck::Is_NOT_Valid(_Wheel)
            || _FullHaulRequested || Math::IsFinite(InDegrees) == false)
        { return; }
        const auto FullDegrees = Bridge.TurnsToExtend * 360.0f;
        _HauledDegrees = Math::Clamp(_HauledDegrees + InDegrees, 0.0f, FullDegrees);
        const auto Alpha = _HauledDegrees / FullDegrees;
        _Deck.Request_Scrub(FMars_Request_Mover_Scrub(Alpha));
        _Wheel.Request_Scrub(FMars_Request_Mover_Scrub(Alpha));
        if (Alpha < 1.0f)
        { return; }

        // Refuse payout from this point, but do not equate requested alpha with physical support.
        _FullHaulRequested = true;
        _Deck.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::End));
        _Wheel.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::End));
        auto Spec = FCk_Timer_Spec(FCk_Time(0.05f));
        Spec.Set_StartingState(ECk_Timer_State::Running).Set_Behavior(ECk_Timer_Behavior::ResetOnDone);
        _VerificationTimer = utils_timer::Add(_Root.H(), Spec);
        if (ck::IsValid(_VerificationTimer))
        {
            auto TimerEntity = _VerificationTimer.H();
            utils_entity_tag::Add(TimerEntity, n"TAG_MarsSlidingBridgeVerification");
            _VerificationTimer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnVerifySeat"));
        }
    }

    // Compare basis points as well as the origin: position alone would miss a stale rotation or scale.
    private bool Get_TransformsMatch(FTransform InActual, FTransform InWanted) const
    {
        return InActual.GetLocation().Distance(InWanted.GetLocation()) < 0.1
            && InActual.TransformPosition(FVector(100.0, 0.0, 0.0)).Distance(InWanted.TransformPosition(FVector(100.0, 0.0, 0.0))) < 0.1
            && InActual.TransformPosition(FVector(0.0, 100.0, 0.0)).Distance(InWanted.TransformPosition(FVector(0.0, 100.0, 0.0))) < 0.1
            && InActual.TransformPosition(FVector(0.0, 0.0, 100.0)).Distance(InWanted.TransformPosition(FVector(0.0, 0.0, 100.0))) < 0.1;
    }

    private bool Get_DeckSeated() const
    {
        if (ck::Is_NOT_Valid(_Deck) || _Deck.Get_Target() != EMars_Mover_Pose::End
            || _Deck.Get_IsResting() == false || _Deck.Get_Alpha() != 1.0f)
        { return false; }
        const auto Wanted = utils_transform::Get_EntityCurrentTransform(_Root);
        if (Get_TransformsMatch(utils_transform::Get_EntityCurrentTransform(_Deck.As_Transform()), Wanted) == false)
        { return false; }

        // Nine interior support witnesses. A lower approach/bed is not a seated deck: hit height must match its top.
        const auto InsideX = (Bridge.DeckWidth - Bridge.CageWallThickness * 2.0) * 0.45;
        for (int32 Along = 1; Along <= 3; ++Along)
        {
            for (int32 Across = -1; Across <= 1; ++Across)
            {
                const auto Top = Wanted.TransformPosition(FVector(Across * InsideX, Along * Bridge.DeckLength * 0.25, 0.0));
                const auto Hit = utils_jolt_static_world::Get_RayCastStaticWorld(Top + FVector(0.0, 0.0, 10.0), Top - FVector(0.0, 0.0, 40.0));
                if (Hit.Get_HasHit() == false || Math::Abs(Hit.Get_Position().Z - Top.Z) > 2.0)
                { return false; }
            }
        }
        return true;
    }

    private bool Get_GuardCleared(FCk_Handle_Gate InGuard, FVector InAnchor) const
    {
        if (ck::Is_NOT_Valid(InGuard) || InGuard.Get_IsOpen() == false)
        { return false; }
        auto Mover = InGuard.Get_MovingNode().As_Mover();
        if (ck::Is_NOT_Valid(Mover) || Mover.Get_Target() != EMars_Mover_Pose::End
            || Mover.Get_IsResting() == false || Mover.Get_Alpha() != 1.0f)
        { return false; }
        const auto Wanted = FTransform(InAnchor + FVector(0.0, 0.0, Bridge.GuardRaise))
            * utils_transform::Get_EntityCurrentTransform(_Root);
        return Get_TransformsMatch(utils_transform::Get_EntityCurrentTransform(Mover.As_Transform()), Wanted);
    }

    UFUNCTION()
    private void OnVerifySeat(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Root) || _Available || _FullHaulRequested == false || Get_DeckSeated() == false)
        { return; }
        if (_GuardsRequested == false)
        {
            if (ck::Is_NOT_Valid(_NearGuard) || ck::Is_NOT_Valid(_FarGuard))
            { return; }
            _GuardsRequested = true;
            _NearGuard.Request_SetPosition(FMars_Request_Gate_SetPosition(EMars_Gate_Position::Open));
            _FarGuard.Request_SetPosition(FMars_Request_Gate_SetPosition(EMars_Gate_Position::Open));
            return;
        }
        if (Get_GuardCleared(_NearGuard, Bridge.NearGuardOffset) == false
            || Get_GuardCleared(_FarGuard, Bridge.FarGuardOffset) == false)
        { return; }
        _Available = true;
        if (ck::IsValid(_Source))
        { _Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(EMars_MechanismSource_Output::Asserted)); }
        StopVerification();
    }

    private void StopVerification()
    {
        if (ck::IsValid(_VerificationTimer))
        {
            _VerificationTimer.UnbindFrom_OnDone(FCk_Delegate_Timer(this, n"OnVerifySeat"));
            utils_entity_lifetime::Request_DestroyEntity(_VerificationTimer.H());
        }
        _VerificationTimer = FCk_Handle_Timer();
    }
}
