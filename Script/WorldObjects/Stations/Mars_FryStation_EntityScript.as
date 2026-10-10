// The fry station: a counter (depth along local X, width along local Y; the operator at -X, +Y their right) with an iron pot
// of hot oil on its centre, the raw platter's dock on the LEFT and a fixed wire drain basket on the RIGHT, on the counter,
// out of the oil, with the finished tray's dock beyond it. A skimmer is parked over the oil: its node carries an Implement (no look tilt, a pour roll and a commanded lift
// the skim sets, a commanded slide the kernel steers across the pot, a corridor and the basket) and, at its origin, the
// scoop's disc and lip bodies, with the handle, a stem and the grip bar beside it; the basket node carries the basket's
// five kinematic boxes. Every part under those nodes is a NoCollision visual. The Fry feature lives on the station entity
// and its own state machine (UMars_SmState_Fry_Idle) reads the operator. The pot starts empty: a CookingFeed on the same
// entity draws the pieces of the docked raw platter, and its station-feed tasks turn the operator's add-food press into a
// left-hand transfer (the feed moves the glove node it carries the real piece under; the hand reaches for the reserved
// piece where it lies) whose release over the oil lands in the station's admission inbox and the Fry kernel admits (the
// piece itself, wearing its own display, on a dynamic body); the kernel lands every piece it hands back on the docked
// finished tray and readopts one the tray refuses. The base builds the feed's nodes and the docks and keeps the label; this
// script builds the fryer and, every frame, keeps every piece's record from the Fry state. While operating, the right glove
// holds the skimmer's grip bar (riding its slide, dip and pour roll) and the left follows the feed node, resting in front of
// the raw platter between transfers.
//
// Per piece (keyed by its feed identity): its own cook state (its six face heats; the oil coat ramps up in the oil and falls
// with the drain in the basket: the visible dripping).
class UMars_FryStation_EntityScript : UMars_FeedStation_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Fry_Spec Fry;

    // The skimmer's slide and dip; its modes, bounds and Nodes are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_Implement_Spec SkimmerImplement;

    // cm, in the station frame (the root; Z 0 is the floor).
    private const float64 CounterWidth = 230.0;
    private const float64 CounterDepth = 110.0;
    private const float64 CounterHeight = constants_station::k_CounterHeight;
    // The operating view, pitched onto the oil from ViewGap uu behind the pot's near wall at ViewHeight. It lives in the
    // station frame (Camera.ViewLocal), so the framing holds whatever the operator's eye height. ViewHeight keeps the platter
    // and the basket both in frame (at a 90-degree horizontal FOV the basket's near right corner sits 92 % of the way to the
    // frame's right edge).
    private const float32 CameraPitch = -50.0f;
    private const float64 ViewGap = 30.0;
    private const float64 ViewHeight = 190.0;

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

    // The oil coat the dressing layers on the ledger's look: it ramps up toward OilCoatInOil while a piece floats in the oil
    // (at OilCoatRate per second) and, in the basket, falls with its drain progress to the kernel's Receiver.DrainedOilCoat,
    // the coat the piece carries away.
    private const float32 OilCoatInOil = 0.8f;
    private const float32 OilCoatRate = 1.0f;

    // The state label on the pot's far rim, its text centred LabelHeight above the rim: inside the operating view.
    private const float64 LabelHeight = 10.0;

    private const FLinearColor k_IronColor = FLinearColor(0.08f, 0.08f, 0.09f, 1.0f);

    // Fry as exposed, with the geometry-bound fields, the reach and the nodes set (Prepare_Kernel, Compose_Kernel); what the
    // feature and the visuals read.
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
    // One per piece entity still alive, in admission order.
    private TArray<FMars_Station_PieceDisplay> _PieceVisuals;

    // The base composes the transform, the visuals and nodes (AddVisuals: the basket and skimmer nodes and their bodies, the
    // feed hand and the release node) and the Station (Configure_Spec, grips on the registered nodes); the skimmer Implement
    // and the minigame need them, so they come after (Compose_Kernel), then the base's feed and docks. The Fry signals are
    // bound there, not at begin play, so no piece's visuals can miss its OnPieceAdded.
    protected void Prepare_Kernel() override
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
    }

    // A geometry that cannot pour into the basket, or carries the scoop through the rim or the basket's walls, builds no
    // fryer: the station stands with its label saying so.
    protected bool Compose_Kernel(FCk_Handle& InHandle) override
    {
        const auto& Basket = _FrySpec.Basket;
        const auto BowlRadius = _FrySpec.Scoop.BowlRadius;
        const auto HasPourWindow = 2.0f * (Basket.InnerHalfX - BowlRadius) >= k_MinPourWindow && 2.0f * (Basket.InnerHalfY - BowlRadius) >= k_MinPourWindow;
        if (ck::EnsureIfNot(HasPourWindow,
            f"[FryStation] the basket (InnerHalfX {Basket.InnerHalfX}, InnerHalfY {Basket.InnerHalfY}) leaves a pour window under {k_MinPourWindow} cm for a bowl of radius {BowlRadius}: no fryer is built"))
        { return false; }

        const auto CarryUnderside = ScoopPark.Z - float64(_FrySpec.Scoop.DiscThickness);
        const auto ClearsRimAndWalls = CarryUnderside > PotRimZ && CarryUnderside > Get_BasketWallTopZ();
        if (ck::EnsureIfNot(ClearsRimAndWalls,
            f"[FryStation] the carried scoop's underside (Z {CarryUnderside}) does not clear the pot rim (Z {PotRimZ}) and the basket walls (Z {Get_BasketWallTopZ()}): no fryer is built"))
        { return false; }

        // A rejected implement spec already ensured in utils_implement::Add.
        _SkimmerImplement = utils_implement::Add(_SkimmerNode.H(), Make_SkimmerImplementSpec());
        if (ck::Is_NOT_Valid(_SkimmerImplement))
        { return false; }

        // A rejected Fry spec already ensured in utils_fry::Add.
        _FrySpec.Nodes = FMars_Fry_Nodes(_SkimmerImplement, _ScoopBody, _BasketBody);
        _FryHandle = utils_fry::Add(InHandle, _FrySpec);
        if (ck::Is_NOT_Valid(_FryHandle))
        { return false; }

        // The label and the cook states are recomputed every dressing tick, so only the new piece needs a signal.
        _FryHandle.BindTo_OnPieceAdded(FMars_Delegate_Fry_OnPieceAdded(this, n"OnPieceAdded"));
        _FryHandle.BindTo_OnTakeOutRefused(FMars_Delegate_Fry_OnTakeOutRefused(this, n"OnTakeOutRefused"));
        _FryHandle.BindTo_OnSkimRefused(FMars_Delegate_Fry_OnSkimRefused(this, n"OnSkimRefused"));
        return true;
    }

    // Every part is a hosted component: it dies with its entity.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_FryHandle))
        {
            _FryHandle.UnbindFrom_OnPieceAdded(FMars_Delegate_Fry_OnPieceAdded(this, n"OnPieceAdded"));
            _FryHandle.UnbindFrom_OnTakeOutRefused(FMars_Delegate_Fry_OnTakeOutRefused(this, n"OnTakeOutRefused"));
            _FryHandle.UnbindFrom_OnSkimRefused(FMars_Delegate_Fry_OnSkimRefused(this, n"OnSkimRefused"));
        }

        // The pieces wear their own displays; only the records go.
        _PieceVisuals.Empty();

        Super::DoEndPlay(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Operation(FMars_Station_Spec& InOutSpec) override
    {
        // The skimmer's grip bar wraps the right glove around it (riding the slide, the dip and the pour roll).
        auto Grips = TArray<FMars_Station_Grip>();
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
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

    protected FVector2D Get_CounterFootprint() const override
    {
        return FVector2D(CounterDepth, CounterWidth);
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
        // The left glove rests in front of the raw platter's dock; the docked raw platter is the stock's only visual.
        Add_FeedHand(FVector(InputDockLocal.X + FeedRestFromPlatter.X, InputDockLocal.Y + FeedRestFromPlatter.Y, CounterHeight));

        _ReleaseNode = utils_scene_node::Create(InRoot,
            FTransform(FVector(ScoopPark.X - ReleaseBack, ReleaseY, OilSurfaceZ + ReleaseAboveOil))).As_Transform();

        AddLabel(FTransform(FRotator(0.0, 180.0, 0.0), FVector(PotInnerRadius, 0.0, PotRimZ + LabelHeight)),
            EVerticalTextAligment::EVRTA_TextCenter, n"FryStation_Label");
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _SkimmerHandleNode));
        Super::Register_GripNodes(OutNodes);
    }

    protected FMars_FeedStation_DockLayout Get_DockLayout() const override
    {
        auto Layout = FMars_FeedStation_DockLayout();
        Layout.Input = FMars_FeedStation_DockSpot(InputDockLocal, FText::FromString("raw platter"), n"FryStation_InputDockMarker");
        Layout.Output = FMars_FeedStation_DockSpot(OutputDockLocal, FText::FromString("finished tray"), n"FryStation_OutputDockMarker");
        return Layout;
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

    // The oil surface (the 1 m disc scaled to the pot) and the boil mesh, both static visuals at the oil line.
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
        // Tinted all through (ProtoGrid), so the iron does not read as the counter.
        auto Stand = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, Get_BasketLocal().Y, CounterHeight + StandHeight * 0.5),
                FVector(2.0 * OuterX, 2.0 * OuterY, StandHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"FryStation_BasketStand");
        Stand.PrimaryColor = TOptional<FLinearColor>(k_IronColor);
        Stand.Tint = EMars_MeshPart_Tint::ProtoGrid;
        InRoot.Add_MeshPart(this, Stand);

        // The wire basket mesh over the kinematic boxes: its pivot is its inner floor centre (the basket frame), its 44 cm
        // long side along X matches InnerHalfX and its 26 cm short side is stretched to InnerHalfY.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, Get_BasketLocal(),
                FVector(1.0, 2.0 * float64(Basket.InnerHalfY) / BasketMeshInnerY, Height / BasketWallHeight)),
            assets::load::FryerBasket_Mars_SM(), nullptr, collision::profile::NoCollision, n"FryStation_Basket"));

        _BasketBody = utils_fry::Add_BasketBodies(_BasketNode, Basket);
    }

    // The skimmer node at its park; the Implement (composed in Compose_Kernel) writes its offset. Under it: the scoop node at
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

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the Fry feature and the feed are the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // After the base advanced the feed and before it refreshes the label.
    protected void Dress(float32 InDeltaSeconds) override
    {
        if (ck::Is_NOT_Valid(_FryHandle))
        { return; }

        Advance_PieceVisuals(InDeltaSeconds);
    }

    // Each piece's look from the kernel's mapping of its cook state (utils_cookstate::Make_DisplayParams: its faces' batter
    // heat, the batter's fry their mean); its oil coat ramps up while it floats in the oil and, in the basket, falls with its
    // drain progress (never back up). A record whose piece the kernel no longer holds (taken out, or destroyed at the end of its linger) or whose entity
    // is gone is dropped; a lost piece keeps its last cook state.
    private void Advance_PieceVisuals(float32 InDeltaSeconds)
    {
        for (int32 Index = _PieceVisuals.Num() - 1; Index >= 0; --Index)
        {
            auto Display = _PieceVisuals[Index];
            if (ck::Is_NOT_Valid(Display.Entity) || _FryHandle.Get_HasPiece(Display.Id) == false)
            {
                _PieceVisuals.RemoveAt(Index);
                continue;
            }

            const auto Whereabouts = _FryHandle.Get_PieceWhereabouts(Display.Id);
            if (Whereabouts == EMars_Fry_Whereabouts::Lost)
            { continue; }

            const auto OilCoat = Display.CookState.OilCoat;
            Display.CookState = utils_cookstate::Make_DisplayParams(_FryHandle.Get_PieceCookState(Display.Id));
            Display.CookState.OilCoat = OilCoat;

            if (Whereabouts == EMars_Fry_Whereabouts::Oil)
            { Display.CookState.OilCoat = Math::FInterpConstantTo(OilCoat, OilCoatInOil, InDeltaSeconds, OilCoatRate); }
            else if (Whereabouts == EMars_Fry_Whereabouts::DrainBasket)
            {
                const auto OilCoatDrained = _FryHandle.Get_Spec().Receiver.DrainedOilCoat;
                const auto Dripped = OilCoatInOil + (OilCoatDrained - OilCoatInOil) * _FryHandle.Get_PieceDrainProgress(Display.Id);
                Display.CookState.OilCoat = Math::Min(OilCoat, Dripped);
            }

            utils_station::Write_PieceDisplay(Display);
            _PieceVisuals[Index] = Display;
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Pieces and the label
    //----------------------------------------------------------------------------------------------------------------------

    // What the label reads: once something was admitted, the raw platter is spent, no transfer is under way and nothing is
    // still in the oil, on the scoop or in the air, the batch is all accounted for (taken out counts); otherwise the batch so
    // far and what is left raw ("no platter" without one docked). A second line says when no tray is docked to take out onto.
    // A station whose fryer was not built says so.
    protected FText Get_StateLabel() const override
    {
        if (ck::Is_NOT_Valid(_FryHandle))
        { return FText::FromString("fryer not built"); }

        const auto Summary = _FryHandle.Get_Summary();
        const auto HasFeed = ck::IsValid(_FeedHandle);
        const auto IsSourced = HasFeed && _FeedHandle.Get_IsSourced();
        const auto Raw = IsSourced ? _FeedHandle.Get_Available() : 0;
        const auto IsFeeding = HasFeed && _FeedHandle.Get_IsBusy();
        const auto InPlay = Summary.InOil + Summary.OnSkimmer + Summary.Airborne;
        const FString TrayLine = Get_HasTray() ? "" : "\nno tray: dock one to take out";

        if (Summary.Admitted > 0 && Raw == 0 && IsFeeding == false && InPlay == 0)
        { return FText::FromString(f"all accounted for: {Summary.Drained}/{Summary.InBasket} drained - {Summary.TakenOut} taken out - {Summary.Lost} lost{TrayLine}"); }

        const FString RawText = IsSourced ? f"{Raw} raw" : "no platter";
        return FText::FromString(f"{Summary.Drained}/{Summary.Admitted} drained - {Summary.InOil} frying - {Summary.Lost} lost - {Summary.TakenOut} taken out - {RawText}{TrayLine}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    // A piece's record: the piece wears its own display, and its cook state starts as the piece arrived with it.
    UFUNCTION()
    private void OnPieceAdded(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _PieceVisuals.Add(utils_station::Make_PieceDisplay(InPieceId, InPiece));
    }

    UFUNCTION()
    private void OnTakeOutRefused(FCk_Handle_Fry InFry, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        Flash_TakeOutRefusal(InRefusal);
    }

    // The scoop is in the corridor, neither in the pot nor over the basket.
    UFUNCTION()
    private void OnSkimRefused(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        if (InSkim == EMars_Fry_Skim::Pour)
        {
            Flash_Refusal("pour over the basket");
            return;
        }

        Flash_Refusal("dip in the oil");
    }
}
