// The fry station: a counter (depth along local X, width along local Y; the operator at -X, +Y their right) with an iron pot
// of hot oil on its centre, the raw platter's dock on the LEFT and a fixed wire drain basket on the RIGHT, on the counter,
// out of the oil, with the finished tray's dock beyond it. A skimmer is parked over the oil: its node carries an Implement (no look tilt, a pour roll and a commanded lift
// the skim sets, a commanded slide the kernel steers across the pot, a corridor and the basket) and, at its origin, the
// scoop's disc and lip bodies, with the handle, a stem and the grip bar beside it; the basket node carries the basket's
// five kinematic boxes. Every part under those nodes is a NoCollision visual. The Fry feature lives on the station entity
// and its own state machine (UMars_SmState_Fry_Idle) reads the operator. The pot starts empty: a CookingFeed on the same
// entity draws the pieces of the docked raw platter, and its station-feed tasks turn the operator's add-food press into a
// left-hand transfer that this script presents (the glove node and a battered proxy in the glove; the hand reaches for the
// reserved piece where it lies) and whose release over the oil the Fry kernel admits (the piece itself, wearing its own
// display, on a dynamic body). This script builds the nodes and the docks and, every frame, keeps every piece's record and
// the label from the Fry state. While operating, the right glove holds the skimmer's grip bar (riding its slide, dip and
// pour roll) and the left follows the feed node, resting in front of the raw platter between transfers.
//
// Per piece (keyed by its feed identity): its own cook state (its six face heats; the oil coat ramps up in the oil and falls
// with the drain in the basket: the visible dripping).
// A wire or handle rod's box in its parent's frame: its centre and its size (cm).
struct FMars_FryStation_Rod
{
    FVector Location = FVector::ZeroVector;
    FVector Size = FVector::ZeroVector;

    FMars_FryStation_Rod() {}

    FMars_FryStation_Rod(FVector InLocation, FVector InSize)
    {
        Location = InLocation;
        Size = InSize;
    }
}

// The station's record of one admitted piece. The piece wears its own display; the station adds no part to it.
struct FMars_FryStation_PieceVisual
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    UPROPERTY()
    FCk_Handle Entity;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    // This piece's look; a lost piece keeps its last one.
    UPROPERTY()
    FMars_CookState CookState;

    // The look last sent to the piece's display.
    UPROPERTY()
    FMars_CookState Written;
}

class UMars_FryStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Fry_Spec Fry;

    // The skimmer's slide and dip; its modes, bounds and Nodes are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_Implement_Spec SkimmerImplement;

    // The transfer's timing and release motion; its release node is set here. The stock is the feed's source platter.
    UPROPERTY(ExposeOnSpawn)
    FMars_CookingFeed_Spec Feed;

    // The raw platter brings any food; the finished tray docks empty.
    UPROPERTY(EditDefaultsOnly, Category = "Docks")
    FMars_Station_DockPolicies Docks;
    default Docks.Output.RequireEmpty = TOptional<bool>(true);

    // cm, in the station frame (the root; Z 0 is the floor).
    private const float64 CounterWidth = 230.0;
    private const float64 CounterDepth = 110.0;
    private const float64 CounterHeight = constants_station::k_CounterHeight;
    // Close in: the capsule (radius 39) stands almost touching the counter edge.
    private const float64 StandGap = 43.0;
    // The operating view, pitched onto the oil from ViewGap uu behind the pot's near wall at ViewHeight. It lives in the
    // station frame (Camera.ViewLocal), so the framing holds whatever the operator's eye height. ViewHeight was raised from
    // 175 so the platter and the basket both fall in frame (at a 90-degree horizontal FOV the basket's near right corner
    // moves from just outside the frame's right edge to 92 % of the way to it).
    private const float32 CameraPitch = -50.0f;
    private const float64 ViewGap = 30.0;
    private const float64 ViewHeight = 190.0;
    // The Use probe's margin around the counter.
    private const float64 ProbePadding = 5.0;

    // The pot is FryerVat_Mars_SM (station_spec.py): a stone-ring vat standing on the FLOOR at the station's origin, inner
    // radius 48, wall 14 (outer 62), rim top 76, cavity floor 40, oil at 66 (its SOCKET_Oil). The counter is split into two
    // halves flanking it (CounterGap off the ring) for the platter and the basket. Its UCX hulls are the pot's collision.
    private const float64 PotInnerRadius = 48.0;
    private const float64 PotWallThickness = 14.0;
    private const float64 PotFloorZ = 40.0;
    private const float64 PotRimZ = 76.0;
    private const float64 OilSurfaceZ = 66.0;
    private const float64 CounterGap = 4.0;

    // The drain basket to the right of the pot, on a stand: its interior's -Y edge BasketGap off the pot's outer wall, its
    // floor top just under the pot rim so a pour drops a piece a hand's width (the carried disc is 17 over the rim), not the
    // half metre a counter-level basket would (a piece poured from that height bounced over the wall); its walls
    // BasketWallHeight tall, still under the carried scoop's underside.
    // FryerBasket_Mars_SM (inner 44 x 26 x 16, pivot at its inner floor centre) stretched along Y to a 44 x 44 interior,
    // the square the pour window needs (k_MinPourWindow both ways); the kinematic boxes follow the same spec.
    private const float64 BasketGap = 6.0;
    private const float64 BasketFloorTopZ = PotRimZ - 2.0;
    private const float64 BasketWallHeight = 16.0;
    private const float32 BasketInnerHalf = 22.0f;
    private const float64 BasketMeshInnerY = 26.0;
    private const float64 RodThickness = 1.2;
    // cm: the narrowest the pour window (where the whole bowl is over the basket interior) may be on either axis: twice the
    // pour's 11 cm.
    private const float32 k_MinPourWindow = 22.0f;

    // The skimmer: parked over the far oil with the disc top 17 above the rim, so a carried scoop clears the rim and the
    // basket's walls. The dip lowers the disc top to ScoopDipTopZ: a floating piece's bottom sits about 7.8 below the oil
    // line (65 % of its 12 cm under it), and the dipped disc passes 5 under that, so the scoop slides beneath a floater and
    // lifts it. The handle runs from the scoop's rim to the operator's right; a stem rises from its end and the grip bar on
    // top keeps the glove above the oil while the scoop is dipped.
    private const FVector ScoopPark = FVector(30.0, 6.0, PotRimZ + 17.0);
    private const float64 ScoopDipTopZ = OilSurfaceZ - 13.0;
    // FryerSkimmer_Mars_SM (station_spec.py): a wire bowl of inner radius 10 and depth 7, pivot at the bowl's lowest inner
    // point, handle along its +X with SOCKET_Grip at (49.67, 0, 14.75). Scaled so the bowl matches the scoop spec's
    // BowlRadius and yawed so the handle runs to the operator's right (+Y); the grip node sits on its grip.
    private const float64 SkimmerMeshBowlRadius = 10.0;
    private const FVector SkimmerMeshGrip = FVector(49.67, 0.0, 14.75);
    // A slow, critically damped dip and carry: the scoop's deceleration at the top of a carry stays under gravity, so a
    // piece on it is not thrown off.
    private const float32 SkimmerLiftSpringHz = 1.5f;
    private const float32 SkimmerLiftDampingRatio = 1.0f;
    // uu past the dip and the carry the lift may travel before its clamp (critically damped: never reached).
    private const float32 SkimmerLiftHeadroom = 2.0f;
    // Room for the kernel's pour (the scoop spec's PourPitchDegrees, 55 by default).
    private const float32 SkimmerMaxTiltDegrees = 60.0f;
    // uu the skimmer's own slide clamp reaches past the kernel's reach bounds (the kernel's clamp is the real one).
    private const float64 SkimmerSlideMargin = 1.0;

    // The release node over the oil, left of the park (a dropped piece never lands on the parked scoop): ReleaseBack uu
    // nearer the operator than the park, at ReleaseY, ReleaseAboveOil over the oil line.
    private const float64 ReleaseBack = 20.0;
    private const float64 ReleaseY = -10.0;
    private const float64 ReleaseAboveOil = 25.0;

    // The docks on the counter top (Z is the counter's): the raw platter on the left (-Y), its tray's edge a few cm off the
    // pot's outer wall, and the finished tray on the right, beyond the basket's stand along X (the basket fills the right
    // half from the pot's wall to the counter's edge at X 0).
    private const FVector InputDockLocal = FVector(0.0, -85.0, 0.0);
    private const FVector OutputDockLocal = FVector(40.0, 90.0, 0.0);
    // The glove's rest from the raw platter's dock: in front of it, a little to its left.
    private const FVector FeedRestFromPlatter = FVector(-32.0, -2.0, 0.0);
    // A palm's thickness: the glove's grip bone above what its palm rests on.
    private const float64 PalmLift = 2.5;

    // The battered meshes' authored sizes (FOOD_LIBRARY.md), cm; each is scaled to the piece's box.
    private const float32 PufferSize = 16.0f;
    private const float32 MushroomSize = 14.4f;
    private const float32 SpikedBerrySize = 11.7f;
    private const int32 k_PieceKinds = 3;
    // The half size of the box the glove's battered proxy is scaled to.
    private const float64 CarriedHalfSize = 6.0;

    // The cook state the dressing writes: the oil coat ramps up toward OilCoatInOil while a piece floats in the oil (at
    // OilCoatRate per second) and, in the basket, falls with its drain progress to OilCoatDrained.
    private const float32 OilCoatInOil = 0.8f;
    private const float32 OilCoatDrained = 0.3f;
    private const float32 OilCoatRate = 1.0f;

    // The ambient boil (OilBubbles_Mars_NS) over the pot. A knob: 0 = no bubbles (the surge that drove them is gone).
    private const float32 AmbientBubbleRate = 0.0f;
    private const float64 BubbleWallMargin = 4.0;
    private const FLinearColor OilColour = FLinearColor(0.22f, 0.1f, 0.02f, 1.0f);

    // The state label on the pot's far rim, its text centred LabelHeight above the rim: inside the operating view.
    private const float64 LabelHeight = 10.0;
    private const float32 LabelWorldSize = 10.0f;
    private const FColor LabelColor = FColor(255, 238, 0, 255);

    private const FLinearColor k_IronColor = FLinearColor(0.08f, 0.08f, 0.09f, 1.0f);
    private const FLinearColor k_WireColor = FLinearColor(0.55f, 0.42f, 0.2f, 1.0f);
    private const FLinearColor k_HandleColor = FLinearColor(0.5f, 0.35f, 0.2f, 1.0f);

    private FCk_Handle_Transform _Root;
    // Fry as exposed, with the geometry-bound fields, the reach and the nodes set (DoConstruct); what the feature and the
    // visuals read.
    private FMars_Fry_Spec _FrySpec;
    private FCk_Handle_Fry _FryHandle;
    private FCk_Handle_Implement _SkimmerImplement;
    // The basket node's origin is the basket frame (the floor's top centre); fixed.
    private FCk_Handle_SceneNode _BasketNode;
    private FCk_Handle_JoltBody _BasketBody;
    // The skimmer at its park; the Implement writes its offset. The scoop, the handle and its grip hang off it.
    private FCk_Handle_SceneNode _SkimmerNode;
    private FCk_Handle_SceneNode _ScoopNode;
    private FCk_Handle_JoltBody _ScoopBody;
    // The right glove's grip (Station.Node.Tool): the skimmer's grip bar, so the glove rides the slide, the dip and the pour.
    private FCk_Handle_Transform _SkimmerHandleNode;
    // The left glove's grip (Station.Node.Feed): the presentation moves it through each transfer.
    private FCk_Handle_SceneNode _FeedHandNode;
    // Over the oil: where a carried piece is released.
    private FCk_Handle_Transform _ReleaseNode;
    // One battered proxy per kind riding the glove (the carried piece's kind shows): the hand mimes the transfer, the piece
    // itself teleports at its admission.
    private TArray<FCk_Handle_UnrealComponent> _CarryProxyParts;
    private FCk_Handle_CookingFeed _FeedHandle;
    private FMars_StationFeed_Presentation _FeedPresentation;
    private FCk_Handle_PlatterDock _InputDock;
    // The label reads it: without a tray, a take-out has nowhere to go.
    private FCk_Handle_PlatterDock _OutputDock;
    // At the pot's axis on the oil line, unit scale: the boil FX rides it (Niagara would inherit a scaled parent's scale).
    private FCk_Handle_SceneNode _FxNode;
    private FCk_Handle_UnrealComponent _BubblesPart;
    // One per piece entity still alive, in admission order.
    private TArray<FMars_FryStation_PieceVisual> _PieceVisuals;
    private FCk_Handle_UnrealComponent _Label;
    // The text last written to the label: it is rewritten only when it changes.
    private FString _LabelText;
    private FCk_Handle_Timer _DressingTick;
    // Tinted parts not painted yet (their components are created asynchronously), with their colours, in parallel.
    private TArray<FCk_Handle_UnrealComponent> _PendingTintParts;
    private TArray<FLinearColor> _PendingTintColors;

    // The entity script is a UObject, not a fragment, so it may hold the component. Null until the hosted component exists.
    private UNiagaraComponent _Bubbles;

    // The base composes the transform, the visuals and nodes (AddVisuals: the basket and skimmer nodes and their bodies, the
    // feed hand and the release node) and the Station (Configure_Spec, grips on the registered nodes); the skimmer Implement,
    // the minigame and the feed need them, so they come after. The Fry signals are bound here, not at begin play, so no
    // piece's visuals can miss its OnPieceAdded.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // Before the base: its AddVisuals sizes the basket and the scoop from it. The oil line, the pot, the dip and the reach
        // are this station's geometry, so the exposed spec cannot set them.
        _FrySpec = Fry;
        _FrySpec.Oil.SurfaceZ = float32(OilSurfaceZ);
        _FrySpec.Zones.RimZ = float32(PotRimZ);
        _FrySpec.Zones.PotRadius = float32(PotInnerRadius);
        _FrySpec.Basket.WallHeight = float32(BasketWallHeight);
        _FrySpec.Basket.InnerHalfX = BasketInnerHalf;
        _FrySpec.Basket.InnerHalfY = BasketInnerHalf;
        _FrySpec.Scoop.CarryLift = 0.0f;
        _FrySpec.Scoop.DipLift = float32(ScoopDipTopZ - ScoopPark.Z);
        _FrySpec.Reach = Make_Reach();

        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to fry on.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        const auto& Basket = _FrySpec.Basket;
        const auto BowlRadius = _FrySpec.Scoop.BowlRadius;
        ck::EnsureIfNot(2.0f * (Basket.InnerHalfX - BowlRadius) >= k_MinPourWindow && 2.0f * (Basket.InnerHalfY - BowlRadius) >= k_MinPourWindow,
            f"[FryStation] the basket (InnerHalfX {Basket.InnerHalfX}, InnerHalfY {Basket.InnerHalfY}) leaves a pour window under {k_MinPourWindow} cm for a bowl of radius {BowlRadius}");

        const auto CarryUnderside = ScoopPark.Z - float64(_FrySpec.Scoop.DiscThickness);
        ck::EnsureIfNot(CarryUnderside > PotRimZ && CarryUnderside > Get_BasketWallTopZ(),
            f"[FryStation] the carried scoop's underside (Z {CarryUnderside}) does not clear the pot rim (Z {PotRimZ}) and the basket walls (Z {Get_BasketWallTopZ()})");

        // A rejected implement spec already ensured in utils_implement::Add.
        _SkimmerImplement = utils_implement::Add(_SkimmerNode.H(), Make_SkimmerImplementSpec());
        if (ck::Is_NOT_Valid(_SkimmerImplement))
        { return Flow; }

        // A rejected Fry spec already ensured in utils_fry::Add.
        _FrySpec.Nodes = FMars_Fry_Nodes(_SkimmerImplement, _ScoopBody, _BasketBody);
        _FryHandle = utils_fry::Add(InHandle, _FrySpec);
        if (ck::Is_NOT_Valid(_FryHandle))
        { return Flow; }

        // The label and the cook states are recomputed every dressing tick, so only the new piece needs a signal.
        _FryHandle.BindTo_OnPieceAdded(FMars_Delegate_Fry_OnPieceAdded(this, n"OnPieceAdded"));

        // A rejected feed spec already ensured in utils_cooking_feed::Add; the station still fries without a platter.
        auto FeedSpec = Feed;
        FeedSpec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode);
        _FeedHandle = utils_cooking_feed::Add(InHandle, FeedSpec);
        Add_Docks();

        // The timer dies with the entity; nothing to unbind.
        _DressingTick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDressingTick"));
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLabelAdded")); }

        if (ck::IsValid(_BubblesPart))
        { utils_unreal_component::BindTo_OnAdded(_BubblesPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFxPartAdded")); }

        for (const auto& Part : _CarryProxyParts)
        {
            if (ck::IsValid(Part))
            { utils_unreal_component::BindTo_OnAdded(Part, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnCarryProxyAdded")); }
        }

        Refresh_Label();
    }

    // The boil and every part are hosted components: they die with their entities.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_FryHandle))
        { _FryHandle.UnbindFrom_OnPieceAdded(FMars_Delegate_Fry_OnPieceAdded(this, n"OnPieceAdded")); }

        _FeedPresentation.Clear(FCk_Handle());
        // The pieces wear their own displays; only the records go.
        _PieceVisuals.Empty();
        _Bubbles = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(CounterDepth * 0.5 + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        // Both grips take their node's frame: the skimmer's grip bar wraps the right glove around it (riding the slide, the
        // dip and the pour roll), the feed node lays the left glove palm down (at rest in front of the platter, and through
        // each transfer).
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Feed, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(CameraPitch, 0.0, 0.0),
            FVector(-(PotInnerRadius + ViewGap), 0.0, ViewHeight)));
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "FryBatchPrompt", "Fry the batch"),
            NSLOCTEXT("MarsInteraction", "FryStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Fry_Idle;
    }

    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(
            FVector(CounterDepth * 0.5 + ProbePadding, CounterWidth * 0.5 + ProbePadding, CounterHeight * 0.5 + ProbePadding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, CounterHeight * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    // Engine cube, cylinder and sphere are 100 uu with the pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;
        // Two counter halves flanking the vat: from CounterGap off the ring out to the counter's edge on each side.
        auto CubeMesh = engine::load::Cube();
        const auto HalfInner = PotInnerRadius + PotWallThickness + CounterGap;
        const auto HalfWidth = CounterWidth * 0.5 - HalfInner;
        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            InRoot.Add_MeshPart(this, FMars_MeshPart(
                FTransform(FRotator::ZeroRotator, FVector(0.0, float64(Side) * (HalfInner + HalfWidth * 0.5), CounterHeight * 0.5),
                    FVector(CounterDepth, HalfWidth, CounterHeight) * 0.01),
                CubeMesh, assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"FryStation_Counter"));
        }

        AddPot(InRoot);
        AddOil(InRoot);
        AddBasket(InRoot);
        AddSkimmer(InRoot);
        AddFeedHand(InRoot);

        _ReleaseNode = utils_scene_node::Create(InRoot,
            FTransform(FVector(ScoopPark.X - ReleaseBack, ReleaseY, OilSurfaceZ + ReleaseAboveOil))).As_Transform();

        _Label = AddLabel(InRoot,
            FTransform(FRotator(0.0, 180.0, 0.0), FVector(PotInnerRadius, 0.0, PotRimZ + LabelHeight)));
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _SkimmerHandleNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Feed, _FeedHandNode.As_Transform()));
    }

    // The pot's floor disc and its wall, all BlockAll: the static world the physics mirrors, so a piece flung against the
    // wall bounces back into the oil and one that clears the rim lands on the counter or the floor.
    private void AddPot(FCk_Handle_Transform& InRoot)
    {
        // The vat's authored hulls (ring wedges from the cavity floor to the rim, the floor slab, the plinth) are the static
        // world the physics mirrors: a piece flung against the wall bounces back into the oil, one that clears the rim lands
        // on a counter or the floor.
        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity,
            assets::load::FryerVat_Mars_SM(), nullptr, collision::profile::BlockAll, n"FryStation_Vat"));
    }

    // The oil surface (the 1 m disc scaled to the pot) and the boil mesh, both static visuals at the oil line, and the hosted
    // ambient bubbles on a unit node at the pot's axis there (created inactive; they run only at a non-zero AmbientBubbleRate).
    private void AddOil(FCk_Handle_Transform& InRoot)
    {
        const auto Scale = PotInnerRadius / 50.0;
        auto Surface = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, OilSurfaceZ), FVector(Scale, Scale, Scale)),
            assets::load::OilSurface_Mars_SM(), assets::load::OilSurface_Mars_MI(), collision::profile::NoCollision, n"FryStation_OilSurface");
        Surface.CastShadow = false;
        InRoot.Add_MeshPart(this, Surface);

        auto Boil = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, OilSurfaceZ), FVector(Scale, Scale, Scale)),
            assets::load::OilBubbles_Mars_SM(), assets::load::OilBubbles_Mars_MI(), collision::profile::NoCollision, n"FryStation_OilBoil");
        Boil.CastShadow = false;
        InRoot.Add_MeshPart(this, Boil);

        _FxNode = utils_scene_node::Create(InRoot, FTransform(FVector(0.0, 0.0, OilSurfaceZ)));

        auto Archetype = NewObject(this, UNiagaraComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetAsset(assets::load::OilBubbles_Mars_NS());
        Archetype.SetAutoActivate(false);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"FryStation_AmbientBubbles");
        _BubblesPart = utils_unreal_component::Add(_FxNode, ComponentParams);
    }

    // The basket node on the counter right of the pot, its origin at the floor's top centre (the basket frame), fixed. Under
    // it: the wire visuals (the box's twelve edges and three floor rods each way) and the five kinematic boxes, the only
    // collision of the basket, sized from the same spec as the kernel's interior.
    private void AddBasket(FCk_Handle_Transform& InRoot)
    {
        const auto& Basket = _FrySpec.Basket;
        _BasketNode = utils_scene_node::Create(InRoot, FTransform(Get_BasketLocal()));
        auto BasketTransform = _BasketNode.As_Transform();

        const auto OuterX = float64(Basket.InnerHalfX + Basket.WallThickness);
        const auto OuterY = float64(Basket.InnerHalfY + Basket.WallThickness);
        const auto Height = float64(Basket.WallHeight);

        // The stand: an iron block from the counter to the floor's underside (a visual; the floor body is the collision).
        const auto StandTop = BasketFloorTopZ - float64(Basket.FloorThickness);
        const auto StandHeight = StandTop - CounterHeight;
        auto Stand = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, Get_BasketLocal().Y, CounterHeight + StandHeight * 0.5),
                FVector(2.0 * OuterX, 2.0 * OuterY, StandHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"FryStation_BasketStand");
        AddTintedPart(InRoot, Stand, k_IronColor);

        // The wire basket mesh over the kinematic boxes: its pivot is its inner floor centre (the basket frame), its 44 cm
        // long side along X matches InnerHalfX and its 26 cm short side is stretched to InnerHalfY.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, Get_BasketLocal(),
                FVector(1.0, 2.0 * float64(Basket.InnerHalfY) / BasketMeshInnerY, Height / BasketWallHeight)),
            assets::load::FryerBasket_Mars_SM(), nullptr, collision::profile::NoCollision, n"FryStation_Basket"));

        _BasketBody = utils_fry::Add_BasketBodies(_BasketNode, Basket);
    }

    // The skimmer node at its park; the Implement (composed in DoConstruct) writes its offset. Under it: the scoop node at
    // its origin (the disc's top centre, the scoop frame) with the disc and lip visuals and the kinematic disc and lip
    // bodies, and the handle rod from the rim to the operator's right, the stem up from its end and the grip bar on top
    // with its grip node (the right glove's).
    private void AddSkimmer(FCk_Handle_Transform& InRoot)
    {
        const auto& Scoop = _FrySpec.Scoop;
        _SkimmerNode = utils_scene_node::Create(InRoot, FTransform(ScoopPark));
        auto SkimmerTransform = _SkimmerNode.As_Transform();

        _ScoopNode = utils_scene_node::Create(SkimmerTransform, FTransform::Identity);
        auto ScoopTransform = _ScoopNode.As_Transform();

        // The skimmer mesh over the kinematic disc and lip: its pivot (the bowl's lowest inner point) at the scoop frame's
        // origin (the disc's top), scaled so its bowl is the spec's BowlRadius, yawed 90 so its handle runs along +Y.
        const auto MeshScale = float64(Scoop.BowlRadius) / SkimmerMeshBowlRadius;
        ScoopTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator(0.0, 90.0, 0.0), FVector::ZeroVector, FVector(MeshScale, MeshScale, MeshScale)),
            assets::load::FryerSkimmer_Mars_SM(), nullptr, collision::profile::NoCollision, n"FryStation_Skimmer"));

        _ScoopBody = utils_fry::Add_ScoopBodies(_ScoopNode, Scoop);

        // The grip: the mesh's SOCKET_Grip, carried into the yawed, scaled frame (its +X handle is the skimmer's +Y).
        const auto GripLocal = FVector(-SkimmerMeshGrip.Y, SkimmerMeshGrip.X, SkimmerMeshGrip.Z) * MeshScale;

        // A right hand palm down on the raked handle, fingers forward closing round the far side of the bar, so the hand
        // leads toward the bowl (-Y).
        _SkimmerHandleNode = utils_scene_node::Create(SkimmerTransform,
            FTransform(utils_fphands::Make_GripRotation(EMars_Hand::Right, FVector::ForwardVector, -FVector::UpVector), GripLocal)).As_Transform();
    }

    // The feed node the left glove follows (at rest in front of the raw platter's dock, palm down, fingers forward) and one
    // battered proxy per kind riding that glove, in its palm, hidden until a piece of that kind is grasped. The docked raw
    // platter is the stock's only visual. The presentation's geometry is authored here, in the station frame.
    private void AddFeedHand(FCk_Handle_Transform& InRoot)
    {
        const auto HandRotation = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, -FVector::UpVector);
        auto& Geometry = _FeedPresentation.Geometry;
        Geometry.RestLocal = FTransform(HandRotation,
            FVector(InputDockLocal.X + FeedRestFromPlatter.X, InputDockLocal.Y + FeedRestFromPlatter.Y, CounterHeight + PalmLift));
        // The piece sits under the palm, world-aligned: a palm's thickness and its half extent out of the palm.
        Geometry.HeldLocal = FTransform(HandRotation.Inverse(), FVector(0.0, 0.0, PalmLift + CarriedHalfSize));

        _FeedHandNode = utils_scene_node::Create(InRoot, Geometry.RestLocal);
        _FeedPresentation.HandNode = _FeedHandNode;
        _FeedPresentation.WrittenHand = Geometry.RestLocal;

        auto HandTransform = _FeedHandNode.As_Transform();
        for (int32 Kind = 0; Kind < k_PieceKinds; ++Kind)
        {
            auto Part = HandTransform.Add_MeshPart(this, Make_PiecePart(Geometry.HeldLocal, Kind, n"FryStation_CarriedPiece"));
            if (ck::IsValid(Part))
            { utils_entity_tag::Add(Part, n"TAG_MarsFryCarriedPiece"); }

            _CarryProxyParts.Add(Part);
        }
    }

    // A NoCollision cube of InRod's size at its location under InParent, tinted InColor.
    private FCk_Handle_UnrealComponent AddRod(FCk_Handle_Transform& InParent, const FMars_FryStation_Rod& InRod, FLinearColor InColor)
    {
        auto Rod = FMars_MeshPart(FTransform(FRotator::ZeroRotator, InRod.Location, InRod.Size * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"FryStation_Rod");
        return AddTintedPart(InParent, Rod, InColor);
    }

    // InPart under InParent, painted InColor once its component exists: a part's PrimaryColor alone leaves the ProtoGrid
    // instance's own secondary and line colours, so iron would read as the counter and the wire as interactable green.
    private FCk_Handle_UnrealComponent AddTintedPart(FCk_Handle_Transform& InParent, FMars_MeshPart InPart, FLinearColor InColor)
    {
        auto Part = InPart;
        Part.PrimaryColor = TOptional<FLinearColor>(InColor);
        const auto Handle = InParent.Add_MeshPart(this, Part);
        if (ck::IsValid(Handle))
        {
            _PendingTintParts.Add(Handle);
            _PendingTintColors.Add(InColor);
        }

        return Handle;
    }

    // A battered mesh of InPreset's kind with its centre at InCentre (its frame: the mesh is scaled to the carried box and
    // lowered by the half size, since the meshes' pivots are at their base).
    private FMars_MeshPart Make_PiecePart(const FTransform& InCentre, int32 InPreset, FName InDebugName) const
    {
        const auto HalfSize = CarriedHalfSize;
        const auto Scale = 2.0 * HalfSize / float64(Get_PieceMeshSize(InPreset));
        return FMars_MeshPart(
            FTransform(InCentre.GetRotation(), InCentre.TransformPosition(FVector(0.0, 0.0, -HalfSize)), FVector(Scale, Scale, Scale)),
            Get_PieceMesh(InPreset), nullptr, collision::profile::NoCollision, InDebugName);
    }

    // The state label on the pot's far rim, yawed to face the operator, its text centred on the node. Its text is set once
    // the component exists.
    private FCk_Handle_UnrealComponent AddLabel(FCk_Handle_Transform& InAttachTo, FTransform InLocalTransform)
    {
        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);

        auto Archetype = NewObject(this, UTextRenderComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Archetype.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Archetype.SetVerticalAlignment(EVerticalTextAligment::EVRTA_TextCenter);
        Archetype.SetWorldSize(LabelWorldSize);
        Archetype.SetTextRenderColor(LabelColor);
        Archetype.SetText(FText::FromString(""));

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"FryStation_Label");
        return utils_unreal_component::Add(Node, ComponentParams);
    }

    // The skimmer's Implement: never tilted by the look; its slide is the kernel's (Commanded), clamped by the implement
    // only to the box bounding the kernel's reach (the kernel's own clamp is the real one), and it stays where it is left;
    // its commanded lift and its pour tilt are the kernel's skim, never the look.
    private FMars_Implement_Spec Make_SkimmerImplementSpec() const
    {
        const auto& Scoop = _FrySpec.Scoop;
        const auto Bounds = utils_fry::Get_ReachBounds(_FrySpec);
        auto Spec = SkimmerImplement;
        Spec.Tilt.Axes = EMars_Implement_TiltAxes::None;
        Spec.Tilt.Relax = EMars_Implement_Relax::WhileIdle;
        Spec.Tilt.MaxTiltDegrees = SkimmerMaxTiltDegrees;
        Spec.Lift.Mode = EMars_Implement_LiftMode::Commanded;
        Spec.Lift.LiftPerLookDegree = 0.0f;
        Spec.Lift.MinLift = Scoop.DipLift - SkimmerLiftHeadroom;
        Spec.Lift.MaxLift = Scoop.CarryLift + SkimmerLiftHeadroom;
        Spec.Lift.SpringHz = SkimmerLiftSpringHz;
        Spec.Lift.DampingRatio = SkimmerLiftDampingRatio;
        Spec.Slide.Mode = EMars_Implement_SlideMode::Commanded;
        Spec.Slide.CmPerLookDegree = 0.0f;
        Spec.Slide.Radius = 0.0f;
        Spec.Slide.Centre = Bounds.Centre - FVector2D(ScoopPark.X, ScoopPark.Y);
        Spec.Slide.HalfExtentX = float32(Bounds.HalfExtent.X + SkimmerSlideMargin);
        Spec.Slide.HalfExtentY = float32(Bounds.HalfExtent.Y + SkimmerSlideMargin);
        Spec.Nodes = FMars_Implement_Nodes(_SkimmerNode);
        return Spec;
    }

    // The carried scoop's reach from this station's geometry (the pot disc is the kernel's, from Zones.PotRadius): a corridor
    // as wide as the basket from the pot's axis to the basket interior's near (-Y) edge (overlapping the pot disc, so the two
    // join without a gap), and the basket's interior footprint.
    private FMars_Fry_ReachSpec Make_Reach() const
    {
        const auto& Basket = _FrySpec.Basket;
        const auto BasketY = Get_BasketLocal().Y;
        const auto InteriorNearY = BasketY - float64(Basket.InnerHalfY);

        auto Reach = _FrySpec.Reach;
        Reach.CorridorCentre = FVector2D(0.0, InteriorNearY * 0.5);
        Reach.CorridorHalfExtent = FVector2D(float64(Basket.InnerHalfX), InteriorNearY * 0.5);
        Reach.BasketCentre = FVector2D(0.0, BasketY);
        Reach.BasketHalfExtent = FVector2D(float64(Basket.InnerHalfX), float64(Basket.InnerHalfY));
        return Reach;
    }

    // The basket frame (the floor's top centre) in the station frame: on its stand, its interior BasketGap off the pot's
    // outer wall on the operator's right, its floor top at BasketFloorTopZ.
    private FVector Get_BasketLocal() const
    {
        const auto& Basket = _FrySpec.Basket;
        return FVector(0.0, PotInnerRadius + PotWallThickness + BasketGap + float64(Basket.InnerHalfY), BasketFloorTopZ);
    }

    private float64 Get_BasketWallTopZ() const
    {
        return Get_BasketLocal().Z + float64(_FrySpec.Basket.WallHeight);
    }

    // The two docks on the counter top, children of the root (they die with the station), lifted so a docked platter's
    // underside rests on the top. A rejected spec already ensured in utils_platter_dock::Create.
    private void Add_Docks()
    {
        const auto DockLift = FVector(0.0, 0.0, CounterHeight + constants_platter::k_FloorAboveBase);
        auto InputSpec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Input, Docks.Input,
            FTransform(FRotator::ZeroRotator, InputDockLocal + DockLift));
        InputSpec.Name = FText::FromString("raw platter");
        _InputDock = utils_platter_dock::Create(_Root, InputSpec);

        auto OutputSpec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Output, Docks.Output,
            FTransform(FRotator::ZeroRotator, OutputDockLocal + DockLift));
        OutputSpec.Name = FText::FromString("finished tray");
        _OutputDock = utils_platter_dock::Create(_Root, OutputSpec);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the Fry feature and the feed are the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // The Advance_ steps update the lag state and the nodes (under nullrhi too); the Apply_ steps write the components and
    // skip any that does not exist yet.
    UFUNCTION()
    private void OnDressingTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_FryHandle))
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        Advance_Feed(DeltaSeconds);
        Advance_PieceVisuals(DeltaSeconds);
        Apply_PendingTints();
        Refresh_Label();
    }

    // The feed's glove node, pose override and carried piece follow the feed; the glove's proxy of the carried piece's kind
    // shows while it is carried.
    private void Advance_Feed(float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(_FeedHandle))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Operator = _Root.H().As_Station().Get_Operator();
        _FeedPresentation.Advance(FMars_StationFeed_Frame(_FeedHandle, Operator, RootWorld, InDeltaSeconds));

        const auto Carried = _FeedPresentation.CarriedPiece;
        const auto CarriedKind = Carried.IsSet() ? Get_PieceKind(Carried.GetValue().StockIndex) : -1;
        for (int32 Kind = 0; Kind < _CarryProxyParts.Num(); ++Kind)
        { Set_PartVisible(_CarryProxyParts[Kind], Kind == CarriedKind); }
    }

    // Skips a part that was left out or whose component does not exist yet.
    private void Set_PartVisible(const FCk_Handle_UnrealComponent& InPart, bool InVisible)
    {
        if (ck::Is_NOT_Valid(InPart))
        { return; }

        auto Component = Cast<USceneComponent>(utils_unreal_component::Get_Component(InPart));
        if (ck::Is_NOT_Valid(Component) || Component.IsVisible() == InVisible)
        { return; }

        Component.SetVisibility(InVisible);
    }

    // Each piece's cook state from its own ledger: its six face heats are its six sears, its mean heat the batter's fry
    // floor; its oil coat ramps up while it floats in the oil and, in the basket, falls with its drain progress (never back
    // up). A record whose piece the kernel no longer holds (taken out, or destroyed at the end of its linger) or whose entity
    // is gone is dropped; a lost piece keeps its last cook state.
    private void Advance_PieceVisuals(float32 InDeltaSeconds)
    {
        for (int32 Index = _PieceVisuals.Num() - 1; Index >= 0; --Index)
        {
            auto Visual = _PieceVisuals[Index];
            if (ck::Is_NOT_Valid(Visual.Entity) || _FryHandle.Get_HasPiece(Visual.Id) == false)
            {
                _PieceVisuals.RemoveAt(Index);
                continue;
            }

            const auto Whereabouts = _FryHandle.Get_PieceWhereabouts(Visual.Id);
            if (Whereabouts == EMars_Fry_Whereabouts::Lost)
            { continue; }

            auto HeatSum = 0.0f;
            for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
            {
                const auto Heat = _FryHandle.Get_FaceHeat(Visual.Id, EMars_Searing_Face(Face));
                Visual.CookState.FaceSear[Face] = Heat;
                HeatSum += Heat;
            }

            Visual.CookState.Fry = HeatSum / float32(utils_searing::k_FaceCount);

            if (Whereabouts == EMars_Fry_Whereabouts::Oil)
            { Visual.CookState.OilCoat = MoveToward(Visual.CookState.OilCoat, OilCoatInOil, OilCoatRate * InDeltaSeconds); }
            else if (Whereabouts == EMars_Fry_Whereabouts::DrainBasket)
            {
                const auto Dripped = OilCoatInOil + (OilCoatDrained - OilCoatInOil) * _FryHandle.Get_PieceDrainProgress(Visual.Id);
                Visual.CookState.OilCoat = Math::Min(Visual.CookState.OilCoat, Dripped);
            }

            Write_PieceCpd(Visual);
            _PieceVisuals[Index] = Visual;
        }
    }

    // The display follows the look on its edges, never per frame: a write once any float has moved by the threshold since
    // the last one. A piece without a display (a bare test piece) is legal and gets none.
    private void Write_PieceCpd(FMars_FryStation_PieceVisual& InVisual)
    {
        if (InVisual.Entity.Is_RuntimeMeshDisplay() == false)
        { return; }

        if (utils_cookstate::Get_HasMovedBeyond(InVisual.Written, InVisual.CookState, constants_cookstate::k_WriteThreshold) == false)
        { return; }

        utils_cookstate::Request_Write(InVisual.Entity.As_RuntimeMeshDisplay(), InVisual.CookState);
        InVisual.Written = InVisual.CookState;
    }

    // Every tinted part whose component now exists, once.
    private void Apply_PendingTints()
    {
        for (int32 Index = _PendingTintParts.Num() - 1; Index >= 0; --Index)
        {
            if (ck::Is_NOT_Valid(utils_unreal_component::Get_Component(_PendingTintParts[Index])))
            { continue; }

            _PendingTintParts[Index].Paint_MeshPart(_PendingTintColors[Index]);
            _PendingTintParts.RemoveAt(Index);
            _PendingTintColors.RemoveAt(Index);
        }
    }

    // The bubbles get their static parameters the first time the component exists (from its OnAdded or, if that fired
    // before the bind, from the tick); they run only at a non-zero AmbientBubbleRate.
    private void Resolve_Bubbles()
    {
        if (ck::IsValid(_Bubbles) || ck::Is_NOT_Valid(_BubblesPart))
        { return; }

        _Bubbles = Cast<UNiagaraComponent>(utils_unreal_component::Get_Component(_BubblesPart));
        if (ck::Is_NOT_Valid(_Bubbles))
        { return; }

        // A disc over the whole oil, short of the wall; the node is on the oil line.
        _Bubbles.SetVariableFloat(n"SpawnRadius", float32(PotInnerRadius - BubbleWallMargin));
        _Bubbles.SetVariableVec2(n"SpawnExtent", FVector2D(0.0, 0.0));
        _Bubbles.SetVariableFloat(n"SurfaceZ", 0.0f);
        _Bubbles.SetVariableFloat(n"SpawnRate", AmbientBubbleRate);
        _Bubbles.SetVariableLinearColor(n"LiquidColour", OilColour);
        if (AmbientBubbleRate > 0.0f)
        { _Bubbles.Activate(true); }
    }

    // InValue moved toward InTarget by at most InMaxStep.
    private float32 MoveToward(float32 InValue, float32 InTarget, float32 InMaxStep) const
    {
        if (InValue < InTarget)
        { return Math::Min(InTarget, InValue + InMaxStep); }

        return Math::Max(InTarget, InValue - InMaxStep);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Pieces and the label
    //----------------------------------------------------------------------------------------------------------------------

    // A piece's record: the piece wears its own display (whoever made the piece dressed it); Jolt owns its pose. The cook
    // state starts as the piece arrived with it, and the display gets it at once.
    private void AddPieceVisuals(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle InPiece)
    {
        auto Visual = FMars_FryStation_PieceVisual();
        Visual.Id = InPieceId;
        Visual.Entity = InPiece;
        Visual.Piece = InPiece.As_FoodPiece();
        Visual.CookState = Visual.Piece.Get_CookState();
        if (Visual.Entity.Is_RuntimeMeshDisplay())
        {
            utils_cookstate::Request_Write(Visual.Entity.As_RuntimeMeshDisplay(), Visual.CookState);
            Visual.Written = Visual.CookState;
        }

        _PieceVisuals.Add(Visual);
    }

    // The three battered kinds by a preset (or slot) index.
    private int32 Get_PieceKind(int32 InPreset) const
    {
        return InPreset % k_PieceKinds;
    }

    private UStaticMesh Get_PieceMesh(int32 InPreset) const
    {
        const auto Kind = Get_PieceKind(InPreset);
        if (Kind == 0)
        { return assets::load::Puffer_Battered_Mars_SM(); }

        if (Kind == 1)
        { return assets::load::Mushroom_Battered_Mars_SM(); }

        return assets::load::SpikedBerry_Battered_Mars_SM();
    }

    private float32 Get_PieceMeshSize(int32 InPreset) const
    {
        const auto Kind = Get_PieceKind(InPreset);
        if (Kind == 0)
        { return PufferSize; }

        if (Kind == 1)
        { return MushroomSize; }

        return SpikedBerrySize;
    }

    // Rewritten only when the text changes.
    private void Refresh_Label()
    {
        if (ck::Is_NOT_Valid(_FryHandle) || ck::Is_NOT_Valid(_Label))
        { return; }

        // Null until the component is created (asynchronously); OnLabelAdded refreshes then.
        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(_Label));
        if (ck::Is_NOT_Valid(Text))
        { return; }

        const auto Label = Get_StateLabel();
        const auto LabelText = Label.ToString();
        if (LabelText == _LabelText)
        { return; }

        _LabelText = LabelText;
        Text.SetText(Label);
    }

    // What the label reads: once something was admitted, the raw platter is spent, no transfer is under way and nothing is
    // still in the oil, on the scoop or in the air, the batch is all accounted for (taken out counts); otherwise the batch so
    // far and what is left raw ("no platter" without one docked). A second line says when no tray is docked to take out onto.
    private FText Get_StateLabel() const
    {
        const auto Summary = _FryHandle.Get_Summary();
        const auto HasFeed = ck::IsValid(_FeedHandle);
        const auto IsSourced = HasFeed && _FeedHandle.Get_IsSourced();
        const auto Raw = IsSourced ? _FeedHandle.Get_Available() : 0;
        const auto IsFeeding = HasFeed && _FeedHandle.Get_IsBusy();
        const auto InPlay = Summary.InOil + Summary.OnSkimmer + Summary.Airborne;
        const FString TrayLine = Get_HasTray() ? "" : "\nno tray: dock one to take out";

        if (Summary.Admitted > 0 && Raw == 0 && IsFeeding == false && InPlay == 0)
        { return FText::FromString(f"all accounted for: {Summary.Drained}/{Summary.InBasket} drained · {Summary.TakenOut} taken out · {Summary.Lost} lost{TrayLine}"); }

        const FString RawText = IsSourced ? f"{Raw} raw" : "no platter";
        return FText::FromString(f"{Summary.Drained}/{Summary.Admitted} drained · {Summary.InOil} frying · {Summary.Lost} lost · {Summary.TakenOut} taken out · {RawText}{TrayLine}");
    }

    private bool Get_HasTray() const
    {
        return ck::IsValid(_OutputDock) && ck::IsValid(_OutputDock.Get_Platter());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLabelAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnFxPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Resolve_Bubbles();
    }

    // A glove proxy wears the raw cook state and starts hidden; the dressing tick sets its visibility.
    UFUNCTION()
    private void OnCarryProxyAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto Mesh = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        utils_cookstate::Write_CustomPrimitiveData(Mesh, FMars_CookState());
        Mesh.SetVisibility(false);
    }

    UFUNCTION()
    private void OnPieceAdded(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        AddPieceVisuals(InPieceId, InPiece);
    }
}
