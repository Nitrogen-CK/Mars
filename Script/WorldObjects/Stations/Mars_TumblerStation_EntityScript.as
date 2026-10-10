// The tumbler station: a counter (depth along local X, width along local Y; the operator at -X, +Y their right) with a cage
// drum on an axle above its centre, the raw platter's dock on the LEFT and the finished tray's dock on the RIGHT. The axle
// node carries one Mover (home to a quarter turn) and the lever Control that scrubs it: the visible cage, the kernel's
// invisible kinematic shell (utils_tumbler::Add_DrumBodies), the hatch hinge and the lever arm all hang off the axle, so
// gripping the lever and rocking it turns the drum and its shell, and letting go settles both home. The hatch swings up and
// open on its hinge node (its own Mover), carrying the plate's kinematic body (utils_tumbler::Add_HatchBody); the right
// glove rides a hand node on the root that the Tumbler kernel moves (a free cursor over a reach plane in front of the drum,
// a reach to the lever grip, the grip itself). The Tumbler feature lives on the station entity and its own state machine
// (UMars_SmState_Tumbler_Idle) reads the operator. A CookingFeed on the same entity draws the pieces of the docked raw
// platter: its station-feed tasks turn the operator's add-food press into a left-hand transfer (the feed moves the glove
// node it carries the real piece under) whose release inside the drum, behind the open hatch, lands in the station's
// admission inbox, where the Tumbler kernel adopts the piece itself on its own dynamic body for the shell to tumble; the
// kernel lands every tumbled piece a take-out hands back on the docked finished tray and readopts one the tray refuses. The
// base builds the feed's nodes and the docks and keeps the label; this script builds the drum and, every frame, dresses
// every piece (its crumb from the kernel's mapping of its cook state), the hover cue and the right glove's pose.
class UMars_TumblerStation_EntityScript : UMars_FeedStation_EntityScript
{
    default _ShowInPlaceActors = true;

    // The minigame's reach, targets, drum, shell, pieces and coating; its geometry-bound fields and its Nodes are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_Tumbler_Spec Tumbler;

    // The crank's feel; its completion policy and pull axis are set here (the kernel grips it, the axle's -X is the pull).
    UPROPERTY(ExposeOnSpawn)
    FMars_Control_Spec LeverControl;
    default LeverControl.Manipulation.AlphaPerDegree = 0.012f;

    // cm, in the station frame (the root; Z 0 is the floor).
    private const float64 CounterWidth = 230.0;
    private const float64 CounterDepth = 110.0;
    private const float64 CounterHeight = constants_station::k_CounterHeight;
    // The operating view, pitched onto the drum from ViewBack behind its axis at ViewHeight (station frame, so the framing
    // holds whatever the operator's eye height).
    private const float32 CameraPitch = -35.0f;
    private const float64 ViewBack = 80.0;
    private const float64 ViewHeight = 185.0;

    // The drum: the axle AxleAboveCounter over the counter. DrumArcDegrees is both the kernel's arc and the axle Mover's end
    // pitch (they must match); the shell's inner faces are DrumInnerRadius from the axis and its baffles DrumHalfLength long
    // either side of the middle.
    private const float64 AxleAboveCounter = 42.0;
    private const float64 AxleZ = CounterHeight + AxleAboveCounter;
    private const float32 DrumArcDegrees = 90.0f;
    private const float32 DrumInnerRadius = 28.0f;
    private const float32 DrumHalfLength = 22.0f;
    // A full-arc return in this long, decelerating into home.
    private const float32 AxleReturnSeconds = 0.7f;
    // The visible cage over the invisible shell: its bars' inner faces on the shell's inner radius (CageClearance is half a
    // bar), CageBarCount of them, closer than a piece is wide so nothing shows through between them; its end discs'
    // inner faces CageEndGap past the baffles, where the shell's discs are.
    private const float64 CageBarSize = 2.0;
    private const float64 CageClearance = CageBarSize * 0.5;
    private const float64 CageEndGap = 4.0;
    private const float64 CageDiscThickness = 2.0;
    private const int32 CageBarCount = 20;
    // The visible ribs over the shell's baffles (their count and height are the spec's Shell.Baffles).
    private const float64 BaffleThickness = 1.5;
    private const float64 AxleRadius = 1.5;
    // The axle posts stand PostWidth wide on the counter, one outside each end disc (the right one past the lever arm).
    private const float64 PostWidth = 4.0;
    private const float64 PostGap = 1.0;

    // The hatch: the front gap of the cage spans HatchHalfDegrees either side of HatchCentreDegrees (drum frame degrees from
    // the bottom, the kernel's convention: -90 is the operator's side, so -120 is up the front), its lower edge 25 cm above
    // the drum's floor so a pile does not spill through it; the hinge is at its upper edge. The plate (HatchSegments boxes
    // along the arc, HatchThickness thick) swings up and out by HatchOpenPitch over HatchSeconds. The tab (the hover anchor)
    // is at the plate's lower edge, about axle height. These are the kernel shell's gap numbers (copied into the spec).
    private const float32 HatchCentreDegrees = -120.0f;
    private const float32 HatchHalfDegrees = 35.0f;
    private const int32 HatchSegments = 3;
    private const float64 HatchThickness = 1.5;
    // The open plate stands up over the gap's upper edge, its tab about 48 cm above the axle: inside the reach (WorkspaceHalfZ)
    // so the hand can close it again.
    private const float32 HatchOpenPitch = -100.0f;
    private const float32 HatchSeconds = 0.35f;
    private const FVector HatchTabSize = FVector(3.0, 8.0, 3.0);

    // The lever on the axle's +Y end: a stub out to LeverArmY, an arm up LeverArmHeight, a grip bar GripLength long on top.
    private const float64 LeverArmY = 30.0;
    private const float64 LeverArmHeight = 38.0;
    private const float64 LeverRodThickness = 2.5;
    private const float64 GripLength = 12.0;

    // The free hand's reach plane is WorkspaceGap in front of the shell, at the axle's height; it reaches WorkspaceHalfZ up
    // and down from there, enough for the lever grip (LeverArmHeight up) and the open hatch's raised tab.
    private const float64 WorkspaceGap = 14.0;
    private const float32 WorkspaceHalfZ = 56.0f;

    // Inside the drum, ReleaseInset in from the shell at the gap's centre: behind the open hatch, so a piece drops in.
    private const float64 ReleaseInset = 8.0;

    // The decorative crumb bed on the root at the drum's bottom, inside the cage.
    private const FVector CrumbBedSize = FVector(24.0, 44.0, 2.0);

    // The raw platter's dock on the counter's left (-Y), the platter's edge PlatterGap off the left post: a large platter
    // (54 cm wide) is the widest that docks there. The finished tray's dock on the counter's right (+Y), DockTrayY out.
    private const float64 PlatterGap = 8.0;
    private const float64 RawPlatterHalfWidth = 27.0;
    private const float64 DockTrayY = 80.0;
    // The glove's rest from the raw platter's dock: in front of its near edge, a little to its left.
    private const FVector FeedRestFromPlatter = FVector(-32.0, -2.0, 0.0);

    // The nominal piece the reseat is measured with: a 12 cm cube.
    private const float32 PieceSize = 12.0f;

    // The label over the far top of the cage, facing the operator; after a refused press its first line says why for
    // RefusalSeconds.
    private const float64 LabelBack = 18.0;
    private const float64 LabelHeight = 12.0;
    private const float32 LabelWorldSize = 7.0f;
    private const float32 RefusalSeconds = 0.6f;

    private const FLinearColor k_IronColor = FLinearColor(0.08f, 0.08f, 0.09f, 1.0f);
    private const FLinearColor k_CageColor = FLinearColor(0.55f, 0.42f, 0.2f, 1.0f);
    private const FLinearColor k_HandleColor = FLinearColor(0.5f, 0.35f, 0.2f, 1.0f);
    private const FLinearColor k_HoverColor = FLinearColor(0.2f, 0.85f, 0.35f, 1.0f);
    private const FLinearColor k_CrumbBedColor = FLinearColor(0.8f, 0.62f, 0.32f, 1.0f);

    // Tumbler as exposed, with the geometry-bound fields and the nodes set (Prepare_Kernel, Compose_Kernel); what the
    // feature and the visuals read.
    private FMars_Tumbler_Spec _TumblerSpec;
    private FMars_Control_Spec _LeverSpec;
    private FCk_Handle_Tumbler _TumblerHandle;
    // The axle node (the drum frame): its Mover is the drum's turn and its Control is the lever.
    private FCk_Handle_SceneNode _AxleNode;
    // The kernel's shell under the axle (its first panel): admission waits for it to be in the simulation.
    private FCk_Handle_JoltBody _DrumBody;
    private FCk_Handle_Mover _AxleMover;
    private FCk_Handle_Control _Lever;
    private FCk_Handle_Transform _LeverGripNode;
    private FCk_Handle_Mover _HatchMover;
    private FCk_Handle_Transform _HatchTabNode;
    // The right glove's grip (Station.Node.Tool): the kernel writes its offset.
    private FCk_Handle_SceneNode _HandNode;
    // The hover cue's parts: painted k_HoverColor while their target is hovered.
    private FCk_Handle_UnrealComponent _HatchTabPart;
    private FCk_Handle_UnrealComponent _LeverGripPart;
    // The hover the cue last painted; unset until both parts exist.
    private TOptional<EMars_Tumbler_Target> _PaintedHover;
    // One per piece entity still in the drum, in admission order.
    private TArray<FMars_Station_PieceDisplay> _PieceVisuals;
    // The last refused press and the seconds the label still shows it.
    private EMars_Tumbler_Refusal _Refusal = EMars_Tumbler_Refusal::NotHome;
    private float32 _RefusalLeft = 0.0f;
    // The right glove's pose override: the one last sent and the operator it went to (sent only on change).
    private TOptional<EMars_HandGripPose> _AppliedRightPose;
    private FCk_Handle _PosedOperator;
    // Tinted parts not painted yet (their components are created asynchronously), with their colours, in parallel.
    private TArray<FCk_Handle_UnrealComponent> _PendingTintParts;
    private TArray<FLinearColor> _PendingTintColors;

    // The base composes the transform, the visuals and nodes (AddVisuals: the axle with its Mover and lever Control, the
    // hinge with its Mover, the grip, tab and hand nodes, the feed hand and the release node) and the Station
    // (Configure_Spec, grips on the registered nodes); the minigame needs the station's view node, so it comes after
    // (Compose_Kernel), then the base's feed and docks. The Tumbler signals are bound there, not at begin play, so no
    // piece's record can miss its OnPieceAdded.
    protected void Prepare_Kernel() override
    {
        // Before the base: its AddVisuals builds the cage, the shell and the hatch from them and places the hand. The drum's
        // arc, radius and length, the hatch gap, the end discs' gap, the nominal piece size and the reach plane are this
        // station's geometry, so the exposed spec cannot set them.
        _TumblerSpec = Tumbler;
        _TumblerSpec.Drum.ArcDegrees = DrumArcDegrees;
        _TumblerSpec.Drum.InnerRadius = DrumInnerRadius;
        _TumblerSpec.Drum.HalfLength = DrumHalfLength;
        _TumblerSpec.Shell.Gap.CentreDegrees = HatchCentreDegrees;
        _TumblerSpec.Shell.Gap.HalfDegrees = HatchHalfDegrees;
        _TumblerSpec.Shell.DiscGap = float32(CageEndGap);
        _TumblerSpec.Piece.HalfSize = PieceSize * 0.5f;
        _TumblerSpec.Hand.WorkspaceCentreLocal = Get_WorkspaceCentreLocal();
        _TumblerSpec.Hand.HalfExtentZ = WorkspaceHalfZ;

        _LeverSpec = LeverControl;
        _LeverSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        _LeverSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
    }

    // A rejected lever or Tumbler spec or node already ensured (utils_control::Add, utils_tumbler::Add): the station stands
    // with nothing to tumble on.
    protected bool Compose_Kernel(FCk_Handle& InHandle) override
    {
        if (ck::Is_NOT_Valid(_Lever))
        { return false; }

        auto StationHandle = InHandle.As_Station();
        _TumblerSpec.Nodes = FMars_Tumbler_Nodes(_HandNode, _HatchTabNode, _LeverGripNode, _Lever, _HatchMover,
            _AxleNode.As_Transform(), _DrumBody, StationHandle.Get_View());
        _TumblerHandle = utils_tumbler::Add(InHandle, _TumblerSpec);
        if (ck::Is_NOT_Valid(_TumblerHandle))
        { return false; }

        _TumblerHandle.BindTo_OnPieceAdded(FMars_Delegate_Tumbler_OnPieceAdded(this, n"OnPieceAdded"));
        _TumblerHandle.BindTo_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnHandModeChanged"));
        _TumblerHandle.BindTo_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnHoverChanged"));
        _TumblerHandle.BindTo_OnPressRefused(FMars_Delegate_Tumbler_OnPressRefused(this, n"OnPressRefused"));
        _TumblerHandle.BindTo_OnTakeOutRefused(FMars_Delegate_Tumbler_OnTakeOutRefused(this, n"OnTakeOutRefused"));
        return true;
    }

    // Every part is a hosted component: it dies with its entity.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_TumblerHandle))
        {
            _TumblerHandle.UnbindFrom_OnPieceAdded(FMars_Delegate_Tumbler_OnPieceAdded(this, n"OnPieceAdded"));
            _TumblerHandle.UnbindFrom_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnHandModeChanged"));
            _TumblerHandle.UnbindFrom_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnHoverChanged"));
            _TumblerHandle.UnbindFrom_OnPressRefused(FMars_Delegate_Tumbler_OnPressRefused(this, n"OnPressRefused"));
            _TumblerHandle.UnbindFrom_OnTakeOutRefused(FMars_Delegate_Tumbler_OnTakeOutRefused(this, n"OnTakeOutRefused"));
        }

        Clear_RightPose();
        // The pieces wear their own displays; only the records go.
        _PieceVisuals.Empty();

        Super::DoEndPlay(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    // The hand node carries the right glove (the kernel moves it over the reach plane, onto the lever grip and with the
    // crank); its pose follows the work (the dressing closes it on the lever).
    protected void Configure_Operation(FMars_Station_Spec& InOutSpec) override
    {
        auto Grips = TArray<FMars_Station_Grip>();
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(CameraPitch, 0.0, 0.0),
            FVector(-(float64(DrumInnerRadius) + ViewBack), 0.0, ViewHeight)));
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "TumblerBatchPrompt", "Coat the batch"),
            NSLOCTEXT("MarsInteraction", "TumblerStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Tumbler_Idle;
    }

    protected FVector2D Get_CounterFootprint() const override
    {
        return FVector2D(CounterDepth, CounterWidth);
    }

    // Engine cube and cylinder are 100 uu with the pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, CounterHeight * 0.5), FVector(CounterDepth, CounterWidth, CounterHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"TumblerStation_Counter"));

        AddAxle(InRoot);
        AddCage();
        AddHatch();
        AddLever();
        AddPosts(InRoot);
        AddCrumbBed(InRoot);

        // The kernel writes its offset (station frame) from the first tick; it starts at the reach plane's centre.
        _HandNode = utils_scene_node::Create(InRoot, FTransform(utils_tumbler::Get_FreeRotation(), Get_WorkspaceCentreLocal()));

        // The left glove rests in front of the raw platter's dock; the docked raw platter is the stock's only visual.
        const auto InputDockLocal = Get_InputDockLocal();
        Add_FeedHand(FVector(InputDockLocal.X + FeedRestFromPlatter.X, InputDockLocal.Y + FeedRestFromPlatter.Y, CounterHeight));

        const auto ReleaseLocal = FVector(0.0, 0.0, AxleZ)
            + Get_CagePoint(float64(HatchCentreDegrees), float64(DrumInnerRadius) - ReleaseInset);
        _ReleaseNode = utils_scene_node::Create(InRoot, FTransform(ReleaseLocal)).As_Transform();

        AddLabel(FTransform(FRotator(0.0, 180.0, 0.0), FVector(LabelBack, 0.0, AxleZ + Get_CageRadius() + LabelHeight)),
            EVerticalTextAligment::EVRTA_TextCenter, n"TumblerStation_Label");
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _HandNode.As_Transform()));
        Super::Register_GripNodes(OutNodes);
    }

    protected FMars_FeedStation_DockLayout Get_DockLayout() const override
    {
        auto Layout = FMars_FeedStation_DockLayout();
        Layout.Input = FMars_FeedStation_DockSpot(Get_InputDockLocal(), FText::FromString("raw platter"), n"TumblerStation_InputDockMarker");
        Layout.Output = FMars_FeedStation_DockSpot(FVector(0.0, DockTrayY, 0.0), FText::FromString("finished tray"), n"TumblerStation_OutputDockMarker");
        return Layout;
    }

    protected float32 Get_LabelWorldSize() const override
    {
        return LabelWorldSize;
    }

    // Why the drum would not take a piece now (the add-food press's gate).
    protected FString Get_StationGateText() const override
    {
        if (ck::Is_NOT_Valid(_TumblerHandle))
        { return "station busy"; }

        if (_TumblerHandle.Get_PieceCount() >= _TumblerHandle.Get_Spec().Drum.Capacity)
        { return "drum full"; }

        if (_TumblerHandle.Get_Hatch() != EMars_Tumbler_Hatch::Open)
        { return "open the hatch first"; }

        if (_TumblerHandle.Get_Drum() != EMars_Tumbler_Drum::Home)
        { return "wait for home"; }

        return "station busy";
    }

    // The axle node over the counter's centre with the drum's Mover (pitch home to DrumArcDegrees; the Mover writes the
    // node's whole offset, so both poses keep the axle where it stands) and the lever Control that scrubs it.
    private void AddAxle(FCk_Handle_Transform& InRoot)
    {
        const auto AxleLocal = FVector(0.0, 0.0, AxleZ);
        _AxleNode = utils_scene_node::Create(InRoot, FTransform(AxleLocal));

        auto AxleSpec = FMars_Mover_Spec();
        AxleSpec.StartLocation = AxleLocal;
        AxleSpec.EndLocation = AxleLocal;
        AxleSpec.EndRotation = FRotator(float64(DrumArcDegrees), 0.0, 0.0);
        AxleSpec.Duration = AxleReturnSeconds;
        AxleSpec.Easing = ECk_TweenEasing::OutSine;
        _AxleMover = utils_mover::Add(_AxleNode, AxleSpec);

        auto AxleEntity = _AxleNode.H();
        _Lever = utils_control::Add(AxleEntity, _LeverSpec, _AxleMover);

        // The shaft, from outside the left disc to the lever arm.
        auto Axle = _AxleNode.As_Transform();
        const auto ShaftStart = -(Get_CageHalfLength() + PostGap + PostWidth);
        const auto ShaftLength = LeverArmY - ShaftStart;
        AddTintedPart(Axle, FMars_MeshPart(
            FTransform(FRotator(0.0, 0.0, 90.0), FVector(0.0, ShaftStart + ShaftLength * 0.5, 0.0),
                FVector(AxleRadius * 0.02, AxleRadius * 0.02, ShaftLength * 0.01)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"TumblerStation_Shaft"),
            k_IronColor);
    }

    // Under the axle: the visible cage (the two end discs, CageBarCount bars around the axis leaving the hatch gap, and a rib
    // over each of the shell's baffles) and the kernel's invisible kinematic shell inside it, which the pieces collide with.
    private void AddCage()
    {
        auto Axle = _AxleNode.As_Transform();
        const auto Radius = Get_CageRadius();
        const auto HalfLength = Get_CageHalfLength();

        // Each disc's inner face where the shell's disc is.
        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            AddTintedPart(Axle, FMars_MeshPart(
                FTransform(FRotator(0.0, 0.0, 90.0), FVector(0.0, float64(Side) * (HalfLength + CageDiscThickness * 0.5), 0.0),
                    FVector(Radius * 0.02, Radius * 0.02, CageDiscThickness * 0.01)),
                engine::load::Cylinder(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"TumblerStation_CageDisc"),
                k_CageColor);
        }

        // The bars share the arc outside the gap evenly, half a step in from each gap edge.
        const auto GapEnd = float64(HatchCentreDegrees + HatchHalfDegrees);
        const auto BarStep = (360.0 - 2.0 * float64(HatchHalfDegrees)) / float64(CageBarCount);
        for (int32 Index = 0; Index < CageBarCount; ++Index)
        {
            const auto Degrees = GapEnd + (float64(Index) + 0.5) * BarStep;
            AddRod(Axle, FTransform(FRotator(Degrees, 0.0, 0.0), Get_CagePoint(Degrees, Radius)),
                FVector(CageBarSize, 2.0 * HalfLength, CageBarSize), k_CageColor);
        }

        // Pitched by their angle, so each rib's local Z runs radially (inward), standing on the shell's inner face where the
        // kernel's baffle bodies are.
        const auto& Baffles = _TumblerSpec.Shell.Baffles;
        const auto BaffleHeight = float64(Baffles.Height);
        for (int32 Index = 0; Index < Baffles.Count; ++Index)
        {
            const auto Degrees = float64(utils_tumbler::Get_BaffleDegrees(_TumblerSpec, Index));
            AddRod(Axle, FTransform(FRotator(Degrees, 0.0, 0.0), Get_CagePoint(Degrees, float64(DrumInnerRadius) - BaffleHeight * 0.5)),
                FVector(BaffleThickness, 2.0 * float64(DrumHalfLength), BaffleHeight), k_IronColor);
        }

        _DrumBody = utils_tumbler::Add_DrumBodies(_AxleNode, _TumblerSpec);
    }

    // The hinge node at the gap's upper edge (the kernel's hinge) with the hatch Mover (closed at rest, pitched
    // HatchOpenPitch open; both poses keep the hinge where it stands), the kernel's plate bodies under it, the visible curved
    // plate across the gap just outside the bars, and the tab node at its lower edge with its handle.
    private void AddHatch()
    {
        auto Axle = _AxleNode.As_Transform();
        const auto PlateRadius = Get_CageRadius() + CageBarSize * 0.5 + HatchThickness * 0.5;
        const auto TopDegrees = float64(HatchCentreDegrees - HatchHalfDegrees);
        const auto BottomDegrees = float64(HatchCentreDegrees + HatchHalfDegrees);
        const auto HingeLocal = utils_tumbler::Get_HatchHingeLocal(_TumblerSpec);

        auto HingeNode = utils_scene_node::Create(Axle, FTransform(HingeLocal));
        auto HatchSpec = FMars_Mover_Spec();
        HatchSpec.StartLocation = HingeLocal;
        HatchSpec.EndLocation = HingeLocal;
        HatchSpec.EndRotation = FRotator(float64(HatchOpenPitch), 0.0, 0.0);
        HatchSpec.Duration = HatchSeconds;
        _HatchMover = utils_mover::Add(HingeNode, HatchSpec);
        utils_tumbler::Add_HatchBody(HingeNode, _TumblerSpec);

        auto Hinge = HingeNode.As_Transform();
        const auto SegmentDegrees = 2.0 * float64(HatchHalfDegrees) / float64(HatchSegments);
        const auto SegmentLength = Math::DegreesToRadians(SegmentDegrees) * PlateRadius * 1.05;
        for (int32 Index = 0; Index < HatchSegments; ++Index)
        {
            const auto Degrees = TopDegrees + (float64(Index) + 0.5) * SegmentDegrees;
            AddRod(Hinge, FTransform(FRotator(Degrees, 0.0, 0.0), Get_CagePoint(Degrees, PlateRadius) - HingeLocal),
                FVector(SegmentLength, 2.0 * Get_CageHalfLength(), HatchThickness), k_HandleColor);
        }

        _HatchTabNode = utils_scene_node::Create(Hinge, FTransform(utils_tumbler::Get_HatchTabLocal(_TumblerSpec))).As_Transform();

        // The handle stands out of the plate, below its lower edge.
        _HatchTabPart = Hinge.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator(BottomDegrees, 0.0, 0.0), Get_CagePoint(BottomDegrees, PlateRadius + HatchTabSize.Z * 0.5) - HingeLocal,
                HatchTabSize * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"TumblerStation_HatchTab"));
    }

    // Under the axle on its +Y end: the stub out to the arm, the arm up, the grip bar on top and the grip node.
    private void AddLever()
    {
        auto Axle = _AxleNode.As_Transform();
        const auto StubStart = Get_CageHalfLength();
        AddRod(Axle, FTransform(FVector(0.0, (StubStart + LeverArmY) * 0.5, 0.0)),
            FVector(LeverRodThickness, LeverArmY - StubStart, LeverRodThickness), k_IronColor);
        AddRod(Axle, FTransform(FVector(0.0, LeverArmY, LeverArmHeight * 0.5)),
            FVector(LeverRodThickness, LeverRodThickness, LeverArmHeight), k_IronColor);

        const auto GripLocal = FVector(0.0, LeverArmY, LeverArmHeight);
        _LeverGripPart = Axle.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, GripLocal, FVector(GripLength, LeverRodThickness * 1.2, LeverRodThickness * 1.2) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"TumblerStation_LeverGrip"));

        // A right-hand handshake grip on the bar: palm facing the operator's left (-Y), fingers curling down round it, the
        // hand leading away from the operator along the bar.
        _LeverGripNode = utils_scene_node::Create(Axle,
            FTransform(utils_fphands::Make_GripRotation(EMars_Hand::Right, -FVector::UpVector, -FVector::RightVector), GripLocal)).As_Transform();
    }

    // The axle's posts on the counter: one outside the left disc, one outside the lever arm.
    private void AddPosts(FCk_Handle_Transform& InRoot)
    {
        const auto Height = AxleZ - CounterHeight;
        const auto LeftY = -(Get_CageHalfLength() + PostGap + PostWidth * 0.5);
        const auto RightY = LeverArmY + LeverRodThickness * 0.5 + PostGap + PostWidth * 0.5;
        for (int32 Side = 0; Side < 2; ++Side)
        {
            const auto Y = Side == 0 ? LeftY : RightY;
            AddRod(InRoot, FTransform(FVector(0.0, Y, CounterHeight + Height * 0.5)), FVector(PostWidth, PostWidth, Height), k_IronColor);
        }
    }

    // On the root (it does not turn), just under the shell's floor: the pieces at rest show sitting on it.
    private void AddCrumbBed(FCk_Handle_Transform& InRoot)
    {
        const auto TopZ = AxleZ - float64(DrumInnerRadius);
        AddRod(InRoot, FTransform(FVector(0.0, 0.0, TopZ - CrumbBedSize.Z * 0.5)), CrumbBedSize, k_CrumbBedColor);
    }

    // A NoCollision cube of InSize at InLocal under InParent, tinted InColor.
    private FCk_Handle_UnrealComponent AddRod(FCk_Handle_Transform& InParent, const FTransform& InLocal, FVector InSize, FLinearColor InColor)
    {
        auto Rod = FMars_MeshPart(FTransform(InLocal.GetRotation(), InLocal.GetLocation(), InSize * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"TumblerStation_Rod");
        return AddTintedPart(InParent, Rod, InColor);
    }

    // InPart under InParent, painted InColor once its component exists: a part's PrimaryColor alone leaves the ProtoGrid
    // instance's own secondary and line colours.
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

    //----------------------------------------------------------------------------------------------------------------------
    // Geometry
    //----------------------------------------------------------------------------------------------------------------------

    // The free hand's reach plane: WorkspaceGap in front of the shell, level with the axle.
    private FVector Get_WorkspaceCentreLocal() const
    {
        return FVector(-(float64(DrumInnerRadius) + WorkspaceGap), 0.0, AxleZ);
    }

    private float64 Get_CageRadius() const
    {
        return float64(DrumInnerRadius) + CageClearance;
    }

    private float64 Get_CageHalfLength() const
    {
        return float64(DrumHalfLength) + CageEndGap;
    }

    // A point on the circle of InRadius round the axle, InDegrees from the bottom (drum frame).
    private FVector Get_CagePoint(float64 InDegrees, float64 InRadius) const
    {
        const auto Angle = Math::DegreesToRadians(InDegrees);
        return FVector(InRadius * Math::Sin(Angle), 0.0, -InRadius * Math::Cos(Angle));
    }

    // The raw platter's dock on the operator's left: a large platter's edge PlatterGap off the left post.
    private FVector Get_InputDockLocal() const
    {
        return FVector(0.0, -(Get_CageHalfLength() + PostGap + PostWidth + PlatterGap + RawPlatterHalfWidth), 0.0);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the Tumbler feature and the feed are the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // After the base advanced the feed and before it refreshes the label.
    protected void Dress(float32 InDeltaSeconds) override
    {
        if (ck::Is_NOT_Valid(_TumblerHandle))
        { return; }

        _RefusalLeft = Math::Max(0.0f, _RefusalLeft - InDeltaSeconds);
        Advance_PieceVisuals();
        Apply_PendingTints();
        Apply_HoverCue();
        Apply_RightPose();
    }

    // Each piece's look from the kernel's mapping of its cook state (utils_cookstate::Make_DisplayParams: its coverage so far
    // as its crumb). A record whose piece the kernel no longer holds (taken out, or reset) or whose entity is gone is
    // dropped.
    private void Advance_PieceVisuals()
    {
        for (int32 Index = _PieceVisuals.Num() - 1; Index >= 0; --Index)
        {
            auto Display = _PieceVisuals[Index];
            if (ck::Is_NOT_Valid(Display.Entity) || _TumblerHandle.Get_HasPiece(Display.Id) == false)
            {
                _PieceVisuals.RemoveAt(Index);
                continue;
            }

            Display.CookState = utils_cookstate::Make_DisplayParams(_TumblerHandle.Get_PieceCookState(Display.Id));
            utils_station::Write_PieceDisplay(Display);
            _PieceVisuals[Index] = Display;
        }
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

    // The hovered target's part reads k_HoverColor, the other its own colour. Repainted on a hover edge, and the first time
    // both components exist.
    private void Apply_HoverCue()
    {
        const auto Hovered = _TumblerHandle.Get_Hovered();
        if (_PaintedHover.IsSet() && _PaintedHover.GetValue() == Hovered)
        { return; }

        if (ck::Is_NOT_Valid(utils_unreal_component::Get_Component(_HatchTabPart))
            || ck::Is_NOT_Valid(utils_unreal_component::Get_Component(_LeverGripPart)))
        { return; }

        _HatchTabPart.Paint_MeshPart(Hovered == EMars_Tumbler_Target::Hatch ? k_HoverColor : k_HandleColor);
        _LeverGripPart.Paint_MeshPart(Hovered == EMars_Tumbler_Target::Lever ? k_HoverColor : k_HandleColor);
        _PaintedHover = TOptional<EMars_Tumbler_Target>(Hovered);
    }

    // The station's operator closes the right glove (Power) while the hand reaches for or holds the lever; Free clears the
    // override. Sent only when it changes; a different operator (or none) first gets the old one cleared.
    private void Apply_RightPose()
    {
        auto Operator = _Root.H().As_Station().Get_Operator();
        if (_PosedOperator != Operator)
        { Clear_RightPose(); }

        auto Pose = TOptional<EMars_HandGripPose>();
        if (_TumblerHandle.Get_HandMode() != EMars_Tumbler_HandMode::Free)
        { Pose = TOptional<EMars_HandGripPose>(EMars_HandGripPose::Power); }

        if (Pose == _AppliedRightPose)
        { return; }

        auto Hands = Operator.As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hands))
        { return; }

        Hands.Request_SetPoseOverride(FMars_Request_FPHands_SetPoseOverride(EMars_Hand::Right, Pose));
        _AppliedRightPose = Pose;
        _PosedOperator = Operator;
    }

    // Unsets the override on the gloves it was sent to (gloves already gone need nothing).
    private void Clear_RightPose()
    {
        if (_AppliedRightPose.IsSet())
        {
            auto Hands = _PosedOperator.As_FPHands(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Hands))
            { Hands.Request_SetPoseOverride(FMars_Request_FPHands_SetPoseOverride(EMars_Hand::Right, TOptional<EMars_HandGripPose>())); }
        }

        _AppliedRightPose.Reset();
        _PosedOperator = FCk_Handle();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The label
    //----------------------------------------------------------------------------------------------------------------------

    // What the label reads: why the last press was refused (for RefusalSeconds), otherwise the batch: how many pieces are in,
    // the hatch, and the batch's mean coverage. A station whose drum was not built says so.
    protected FText Get_StateLabel() const override
    {
        if (ck::Is_NOT_Valid(_TumblerHandle))
        { return FText::FromString("tumbler not built"); }

        if (_RefusalLeft > 0.0f)
        { return FText::FromString(Get_RefusalText(_Refusal)); }

        const auto Ids = _TumblerHandle.Get_PieceIds();
        auto CoverageSum = 0.0f;
        for (const auto& Id : Ids)
        { CoverageSum += _TumblerHandle.Get_PieceCoverage(Id); }

        const auto MeanPercent = Ids.Num() > 0 ? Math::RoundToInt(100.0f * CoverageSum / float32(Ids.Num())) : 0;
        return FText::FromString(f"{Ids.Num()} in - hatch {Get_HatchText(_TumblerHandle.Get_Hatch())} - coverage {MeanPercent}%");
    }

    private FString Get_HatchText(EMars_Tumbler_Hatch InHatch) const
    {
        if (InHatch == EMars_Tumbler_Hatch::Open)
        { return "open"; }

        if (InHatch == EMars_Tumbler_Hatch::Opening)
        { return "opening"; }

        if (InHatch == EMars_Tumbler_Hatch::Closing)
        { return "closing"; }

        return "closed";
    }

    private FString Get_RefusalText(EMars_Tumbler_Refusal InRefusal) const
    {
        if (InRefusal == EMars_Tumbler_Refusal::NotHome)
        { return "wait for home"; }

        if (InRefusal == EMars_Tumbler_Refusal::HatchOpen)
        { return "close the hatch first"; }

        if (InRefusal == EMars_Tumbler_Refusal::HatchMoving)
        { return "wait for the hatch"; }

        if (InRefusal == EMars_Tumbler_Refusal::LoadingInFlight)
        { return "wait for the piece"; }

        if (InRefusal == EMars_Tumbler_Refusal::HandBusy)
        { return "hand busy"; }

        return "nothing there";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    // A piece's record: the piece wears its own display, and its look starts as the piece arrived.
    UFUNCTION()
    private void OnPieceAdded(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _PieceVisuals.Add(utils_station::Make_PieceDisplay(InPieceId, InPiece));
    }

    UFUNCTION()
    private void OnHandModeChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_HandMode InHandMode)
    {
        Apply_RightPose();
    }

    UFUNCTION()
    private void OnHoverChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Target InTarget)
    {
        Apply_HoverCue();
    }

    UFUNCTION()
    private void OnPressRefused(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Refusal InRefusal)
    {
        _Refusal = InRefusal;
        _RefusalLeft = RefusalSeconds;
        Refresh_Label();
    }

    UFUNCTION()
    private void OnTakeOutRefused(FCk_Handle_Tumbler InTumbler, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        Flash_TakeOutRefusal(InRefusal);
    }
}
