// The tumbler station: a counter (depth along local X, width along local Y; the operator at -X, +Y their right) with a cage
// drum on an axle above its centre, the raw platter on the LEFT and an empty output tray on the RIGHT. The axle node carries
// one Mover (home to a quarter turn) and the lever Control that scrubs it: the visible cage, the kernel's invisible
// kinematic shell (utils_tumbler::Add_DrumBodies), the hatch hinge and the lever arm all hang off the axle, so gripping the
// lever and rocking it turns the drum and its shell, and letting go settles both home. The hatch swings up and open on its
// hinge node (its own Mover), carrying the plate's kinematic body (utils_tumbler::Add_HatchBody); the right glove rides a
// hand node on the root that the Tumbler kernel moves (a free cursor over a reach plane in front of the drum, a reach to
// the lever grip, the grip itself). The Tumbler feature lives on the station entity and its own state machine
// (UMars_SmState_Tumbler_Idle) reads the operator. A CookingFeed on the same entity draws raw pieces from a source
// platter; its station-feed tasks turn the operator's add-food press into a left-hand transfer that this script
// presents, released inside the drum behind the open hatch, where the kernel admits it as a dynamic Jolt body that the
// shell tumbles. This script builds the nodes and, every frame, dresses every piece (its crumb coverage), the label,
// the hover cue and the right glove's pose.

struct FMars_TumblerStation_PieceVisual
{
    FMars_CookingFeed_PieceId Id;
    // The piece's body entity: its mesh dies with it.
    FCk_Handle Entity;
    FCk_Handle_UnrealComponent Part;
    FMars_CookState CookState;
}

class UMars_TumblerStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    // The minigame's reach, targets, drum, shell, pieces and coating; its geometry-bound fields and its Nodes are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_Tumbler_Spec Tumbler;

    // The crank's feel; its completion policy and pull axis are set here (the kernel grips it, the axle's -X is the pull).
    UPROPERTY(ExposeOnSpawn)
    FMars_Control_Spec LeverControl;
    default LeverControl.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
    default LeverControl.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
    default LeverControl.Manipulation.AlphaPerDegree = 0.012f;

    // The transfer's timing and release motion; its release node is set here. The stock is the feed's source platter.
    UPROPERTY(ExposeOnSpawn)
    FMars_CookingFeed_Spec Feed;

    // cm, in the station frame (the root; Z 0 is the floor).
    private const float64 CounterWidth = 230.0;
    private const float64 CounterDepth = 110.0;
    private const float64 CounterHeight = constants_station::k_CounterHeight;
    // Close in: the capsule (radius 39) stands almost touching the counter edge.
    private const float64 StandGap = 43.0;
    // The operating view, pitched onto the drum from ViewBack behind its axis at ViewHeight (station frame, so the framing
    // holds whatever the operator's eye height).
    private const float32 CameraPitch = -35.0f;
    private const float64 ViewBack = 80.0;
    private const float64 ViewHeight = 185.0;
    // The Use probe's margin around the counter.
    private const float64 ProbePadding = 5.0;

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

    // The raw platter on the counter's left (-Y), PlatterGap off the left post: a slab with RawSlotRows x RawSlotColumns raw
    // pieces (rows along X, away from the operator; columns along Y), and the free glove's rest in front of it.
    private const int32 RawSlotRows = 3;
    private const int32 RawSlotColumns = 2;
    private const float64 RawSlotPitch = 15.0;
    private const float64 PlatterGap = 8.0;
    private const float64 PlatterHeight = 2.0;
    private const float64 PlatterMargin = 2.0;
    // The glove's rest from the platter's centre: in front of its near row, a little to its left.
    private const FVector FeedRestFromPlatter = FVector(-32.0, -2.0, 0.0);
    // A palm's thickness: the glove's grip bone above what its palm rests on.
    private const float64 PalmLift = 2.5;

    // The output tray on the counter's right (+Y): an open box, no logic.
    private const float64 TrayCentreY = 80.0;
    private const float64 TrayHalfSize = 20.0;
    private const float64 TrayWallHeight = 6.0;
    private const float64 TrayWallThickness = 1.5;

    // Every piece is scaled to a PieceSize cube; the raw meshes' authored sizes (FOOD_LIBRARY.md), cm.
    private const float32 PieceSize = 12.0f;
    private const float32 PufferSize = 14.0f;
    private const float32 MushroomSize = 12.0f;
    private const float32 DrumstickSize = 21.4f;
    private const int32 k_PieceKinds = 3;

    // The label over the far top of the cage, facing the operator; after a refused press it says why for RefusalSeconds.
    private const float64 LabelBack = 18.0;
    private const float64 LabelHeight = 12.0;
    private const float32 LabelWorldSize = 7.0f;
    private const FColor LabelColor = FColor(255, 238, 0, 255);
    private const float32 RefusalSeconds = 0.6f;

    private const FLinearColor k_IronColor = FLinearColor(0.08f, 0.08f, 0.09f, 1.0f);
    private const FLinearColor k_CageColor = FLinearColor(0.55f, 0.42f, 0.2f, 1.0f);
    private const FLinearColor k_HandleColor = FLinearColor(0.5f, 0.35f, 0.2f, 1.0f);
    private const FLinearColor k_HoverColor = FLinearColor(0.2f, 0.85f, 0.35f, 1.0f);
    private const FLinearColor k_PlatterColor = FLinearColor(0.22f, 0.22f, 0.24f, 1.0f);
    private const FLinearColor k_CrumbBedColor = FLinearColor(0.8f, 0.62f, 0.32f, 1.0f);

    private FCk_Handle_Transform _Root;
    // Tumbler as exposed, with the geometry-bound fields and the nodes set (DoConstruct); what the feature and the visuals
    // read.
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
    // The left glove's grip (Station.Node.Feed): the presentation moves it through each transfer.
    private FCk_Handle_SceneNode _FeedHandNode;
    // Inside the drum behind the hatch: where a carried piece is released.
    private FCk_Handle_Transform _ReleaseNode;
    // The hover cue's parts: painted k_HoverColor while their target is hovered.
    private FCk_Handle_UnrealComponent _HatchTabPart;
    private FCk_Handle_UnrealComponent _LeverGripPart;
    // The hover the cue last painted; unset until both parts exist.
    private TOptional<EMars_Tumbler_Target> _PaintedHover;
    // One raw proxy per platter slot, and one per kind riding the glove (the carried piece's kind shows).
    private TArray<FCk_Handle_UnrealComponent> _RawSlotParts;
    private TArray<FCk_Handle_UnrealComponent> _CarryProxyParts;
    private FCk_Handle_CookingFeed _FeedHandle;
    private FMars_StationFeed_Presentation _FeedPresentation;
    // One per piece entity still alive, in admission order.
    private TArray<FMars_TumblerStation_PieceVisual> _PieceVisuals;
    private FCk_Handle_UnrealComponent _Label;
    // The text last written to the label: it is rewritten only when it changes.
    private FString _LabelText;
    // The last refused press and the seconds the label still shows it.
    private EMars_Tumbler_Refusal _Refusal = EMars_Tumbler_Refusal::NotHome;
    private float32 _RefusalLeft = 0.0f;
    // The right glove's pose override: the one last sent and the operator it went to (sent only on change).
    private TOptional<EMars_HandGripPose> _AppliedRightPose;
    private FCk_Handle _PosedOperator;
    private FCk_Handle_Timer _DressingTick;
    // Tinted parts not painted yet (their components are created asynchronously), with their colours, in parallel.
    private TArray<FCk_Handle_UnrealComponent> _PendingTintParts;
    private TArray<FLinearColor> _PendingTintColors;

    // The base composes the transform, the visuals and nodes (AddVisuals: the axle with its Mover and lever Control, the
    // hinge with its Mover, the grip, tab and hand nodes, the platter and the release node) and the Station (Configure_Spec,
    // grips on the registered nodes); the minigame needs the station's view node, so it and the feed come after. The Tumbler
    // signals are bound here, not at begin play, so no piece's visuals can miss its OnPieceAdded.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // Before the base: its AddVisuals builds the cage, the shell and the hatch from them and places the hand. The drum's
        // arc, radius and length, the hatch gap, the end discs' gap, the piece size the meshes are scaled to and the reach
        // plane are this station's geometry, so the exposed spec cannot set them.
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

        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to tumble on.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        // A rejected lever spec already ensured in utils_control::Add.
        if (ck::Is_NOT_Valid(_Lever))
        { return Flow; }

        // A rejected Tumbler spec or node already ensured in utils_tumbler::Add.
        _TumblerSpec.Nodes = FMars_Tumbler_Nodes(_HandNode, _HatchTabNode, _LeverGripNode, _Lever, _HatchMover,
            _AxleNode.As_Transform(), _DrumBody, StationHandle.Get_View());
        _TumblerHandle = utils_tumbler::Add(InHandle, _TumblerSpec);
        if (ck::Is_NOT_Valid(_TumblerHandle))
        { return Flow; }

        _TumblerHandle.BindTo_OnPieceAdded(FMars_Delegate_Tumbler_OnPieceAdded(this, n"OnPieceAdded"));
        _TumblerHandle.BindTo_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnHandModeChanged"));
        _TumblerHandle.BindTo_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnHoverChanged"));
        _TumblerHandle.BindTo_OnPressRefused(FMars_Delegate_Tumbler_OnPressRefused(this, n"OnPressRefused"));
        _TumblerHandle.BindTo_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnHatchChanged"));

        // A rejected feed spec already ensured in utils_cooking_feed::Add; the drum still turns without a platter.
        auto FeedSpec = Feed;
        FeedSpec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode, _FeedHandNode.As_Transform());
        FeedSpec.Motion.HeldOffset = _FeedPresentation.Geometry.HeldLocal;
        _FeedHandle = utils_cooking_feed::Add(InHandle, FeedSpec);

        // The timer dies with the entity; nothing to unbind.
        _DressingTick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDressingTick"));
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLabelAdded")); }

        for (const auto& Part : _RawSlotParts)
        {
            if (ck::IsValid(Part))
            { utils_unreal_component::BindTo_OnAdded(Part, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnRawPartAdded")); }
        }

        for (const auto& Part : _CarryProxyParts)
        {
            if (ck::IsValid(Part))
            { utils_unreal_component::BindTo_OnAdded(Part, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnRawPartAdded")); }
        }

        Refresh_Label();
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
            _TumblerHandle.UnbindFrom_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnHatchChanged"));
        }

        _FeedPresentation.Clear(FCk_Handle());
        Clear_RightPose();
        // The meshes are hosted on the piece entities and die with them; only the records go.
        _PieceVisuals.Empty();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(CounterDepth * 0.5 + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        // Both grips take their node's frame: the hand node carries the right glove (the kernel moves it over the reach plane,
        // onto the lever grip and with the crank), the feed node lays the left glove palm down (at rest in front of the
        // platter, and through each transfer). Their poses follow the work: the right closes on the lever (the dressing's
        // override), the left cradles a carried piece (the feed presentation's).
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Feed, NAME_None,
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

    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(
            FVector(CounterDepth * 0.5 + ProbePadding, CounterWidth * 0.5 + ProbePadding, CounterHeight * 0.5 + ProbePadding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, CounterHeight * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
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
        AddPlatter(InRoot);
        AddTray(InRoot);

        // The kernel writes its offset (station frame) from the first tick; it starts at the reach plane's centre.
        _HandNode = utils_scene_node::Create(InRoot, FTransform(utils_tumbler::Get_FreeRotation(), Get_WorkspaceCentreLocal()));

        const auto ReleaseLocal = FVector(0.0, 0.0, AxleZ)
            + Get_CagePoint(float64(HatchCentreDegrees), float64(DrumInnerRadius) - ReleaseInset);
        _ReleaseNode = utils_scene_node::Create(InRoot, FTransform(ReleaseLocal)).As_Transform();

        _Label = AddLabel(InRoot,
            FTransform(FRotator(0.0, 180.0, 0.0), FVector(LabelBack, 0.0, AxleZ + Get_CageRadius() + LabelHeight)));
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _HandNode.As_Transform()));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Feed, _FeedHandNode.As_Transform()));
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

    // The raw platter: a slab on the counter's left with one raw proxy per slot (each on its RawSlot node, tagged so a test
    // can find them; the kind by the slot's preset), the feed node the left glove follows (at rest in front of the platter,
    // palm down, fingers forward) and one proxy per kind riding that glove, in its palm, hidden until a piece of that kind
    // is grasped. The presentation's geometry is authored here, in the station frame.
    private void AddPlatter(FCk_Handle_Transform& InRoot)
    {
        const auto HalfSize = float64(PieceSize) * 0.5;
        const auto PlatterTop = CounterHeight + PlatterHeight;
        const auto PlatterDepth = float64(RawSlotRows) * RawSlotPitch + PlatterMargin * 2.0;
        const auto PlatterCentreY = Get_PlatterCentreY();

        auto Platter = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, PlatterCentreY, CounterHeight + PlatterHeight * 0.5),
                FVector(PlatterDepth, Get_PlatterWidth(), PlatterHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Platform_Mars_MI(), collision::profile::NoCollision, n"TumblerStation_Platter");
        Platter.PrimaryColor = TOptional<FLinearColor>(k_PlatterColor);
        InRoot.Add_MeshPart(this, Platter);

        const auto HandRotation = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, -FVector::UpVector);
        auto& Geometry = _FeedPresentation.Geometry;
        Geometry.RestLocal = FTransform(HandRotation,
            FVector(FeedRestFromPlatter.X, PlatterCentreY + FeedRestFromPlatter.Y, CounterHeight + PalmLift));
        // The piece sits under the palm, world-aligned: a palm's thickness and its half extent out of the palm.
        Geometry.HeldLocal = FTransform(HandRotation.Inverse(), FVector(0.0, 0.0, PalmLift + HalfSize));

        for (int32 Row = 0; Row < RawSlotRows; ++Row)
        {
            for (int32 Column = 0; Column < RawSlotColumns; ++Column)
            {
                const auto Slot = _RawSlotParts.Num();
                const auto X = (float64(Row) - float64(RawSlotRows - 1) * 0.5) * RawSlotPitch;
                const auto Y = PlatterCentreY + (float64(Column) - float64(RawSlotColumns - 1) * 0.5) * RawSlotPitch;
                const auto SlotLocal = FTransform(FVector(X, Y, PlatterTop + HalfSize));

                // The slot's piece will be released with preset Slot (the feed's StockIndex: a slot of its source platter).
                auto SlotNode = utils_scene_node::Create(InRoot, SlotLocal).As_Transform();
                auto Part = SlotNode.Add_MeshPart(this, Make_RawPiecePart(FTransform::Identity, Slot, n"TumblerStation_RawSlot"));
                if (ck::IsValid(Part))
                { utils_entity_tag::Add(Part, n"TAG_MarsTumblerRawSlot"); }

                _RawSlotParts.Add(Part);
            }
        }

        _FeedHandNode = utils_scene_node::Create(InRoot, Geometry.RestLocal);
        _FeedPresentation.HandNode = _FeedHandNode;
        _FeedPresentation.WrittenHand = Geometry.RestLocal;

        auto HandTransform = _FeedHandNode.As_Transform();
        for (int32 Kind = 0; Kind < k_PieceKinds; ++Kind)
        {
            auto Part = HandTransform.Add_MeshPart(this, Make_RawPiecePart(Geometry.HeldLocal, Kind, n"TumblerStation_CarriedPiece"));
            if (ck::IsValid(Part))
            { utils_entity_tag::Add(Part, n"TAG_MarsTumblerCarriedPiece"); }

            _CarryProxyParts.Add(Part);
        }
    }

    // The output tray on the counter's right: a floor and four walls, open on top.
    private void AddTray(FCk_Handle_Transform& InRoot)
    {
        const auto FloorZ = CounterHeight + TrayWallThickness * 0.5;
        const auto WallZ = CounterHeight + TrayWallHeight * 0.5;
        const auto Size = 2.0 * TrayHalfSize;
        AddRod(InRoot, FTransform(FVector(0.0, TrayCentreY, FloorZ)), FVector(Size, Size, TrayWallThickness), k_IronColor);
        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            const auto Offset = float64(Side) * TrayHalfSize;
            AddRod(InRoot, FTransform(FVector(Offset, TrayCentreY, WallZ)), FVector(TrayWallThickness, Size, TrayWallHeight), k_IronColor);
            AddRod(InRoot, FTransform(FVector(0.0, TrayCentreY + Offset, WallZ)), FVector(Size, TrayWallThickness, TrayWallHeight), k_IronColor);
        }
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

    // A raw mesh of InPreset's kind with its centre at InCentre (its frame: the mesh is scaled to the piece's cube and
    // lowered by the half size, since the meshes' pivots are at their base).
    private FMars_MeshPart Make_RawPiecePart(const FTransform& InCentre, int32 InPreset, FName InDebugName) const
    {
        const auto HalfSize = float64(PieceSize) * 0.5;
        const auto Scale = Get_PieceScale(InPreset);
        return FMars_MeshPart(
            FTransform(InCentre.GetRotation(), InCentre.TransformPosition(FVector(0.0, 0.0, -HalfSize)), FVector(Scale, Scale, Scale)),
            Get_PieceMesh(InPreset), nullptr, collision::profile::NoCollision, InDebugName);
    }

    // The state label over the cage, yawed to face the operator, its text centred on the node. Its text is set once the
    // component exists.
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
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"TumblerStation_Label");
        return utils_unreal_component::Add(Node, ComponentParams);
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

    private float64 Get_PlatterWidth() const
    {
        return float64(RawSlotColumns) * RawSlotPitch + PlatterMargin * 2.0;
    }

    // The platter on the operator's left, PlatterGap off the left post.
    private float64 Get_PlatterCentreY() const
    {
        return -(Get_CageHalfLength() + PostGap + PostWidth + PlatterGap + Get_PlatterWidth() * 0.5);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the Tumbler feature and the feed are the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDressingTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_TumblerHandle))
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        _RefusalLeft = Math::Max(0.0f, _RefusalLeft - DeltaSeconds);
        Advance_Feed(DeltaSeconds);
        Advance_PieceVisuals();
        Apply_PieceCpd();
        Apply_PendingTints();
        Apply_HoverCue();
        Apply_RightPose();
        Refresh_Label();
    }

    // The feed's glove node, pose override and carried piece follow the feed; the slot proxies show how much stock the source
    // still has and the glove's proxy of the carried piece's kind shows while it is carried.
    private void Advance_Feed(float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(_FeedHandle))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Operator = _Root.H().As_Station().Get_Operator();
        _FeedPresentation.Advance(FMars_StationFeed_Frame(_FeedHandle, Operator, RootWorld, InDeltaSeconds));

        for (int32 Slot = 0; Slot < _RawSlotParts.Num(); ++Slot)
        { Set_PartVisible(_RawSlotParts[Slot], Get_IsSlotVisible(Slot)); }

        // The tumbler's stock is proxies, not pieces: the glove shows the reserved slot's kind from the grasp to the admission.
        const auto Phase = _FeedHandle.Get_Phase();
        const auto IsHolding = Phase == EMars_CookingFeed_Phase::Grasp || Phase == EMars_CookingFeed_Phase::Carry
            || Phase == EMars_CookingFeed_Phase::AwaitAdmission;
        const auto Carried = _FeedHandle.TryGet_ActivePiece();
        const auto CarriedKind = IsHolding && Carried.IsSet() ? Get_PieceKind(Carried.GetValue().StockIndex) : -1;
        for (int32 Kind = 0; Kind < _CarryProxyParts.Num(); ++Kind)
        { Set_PartVisible(_CarryProxyParts[Kind], Kind == CarriedKind); }
    }

    // The tumbler shows its stock as proxies until it takes real pieces: the first Available slots show their piece.
    private bool Get_IsSlotVisible(int32 InSlot) const
    {
        return InSlot < _FeedHandle.Get_Available();
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

    // Each piece's crumb from its coverage. A record whose piece the kernel no longer holds (reset) or whose entity is gone is
    // dropped (its mesh dies with the entity).
    private void Advance_PieceVisuals()
    {
        for (int32 Index = _PieceVisuals.Num() - 1; Index >= 0; --Index)
        {
            auto Visual = _PieceVisuals[Index];
            if (ck::Is_NOT_Valid(Visual.Entity) || _TumblerHandle.Get_HasPiece(Visual.Id) == false)
            {
                _PieceVisuals.RemoveAt(Index);
                continue;
            }

            Visual.CookState.Crumb = _TumblerHandle.Get_PieceCoverage(Visual.Id);
            _PieceVisuals[Index] = Visual;
        }
    }

    private void Apply_PieceCpd()
    {
        for (const auto& Visual : _PieceVisuals)
        { Write_PieceCpd(Visual); }
    }

    private void Write_PieceCpd(const FMars_TumblerStation_PieceVisual& InVisual)
    {
        if (ck::Is_NOT_Valid(InVisual.Part))
        { return; }

        auto Mesh = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InVisual.Part));
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        utils_cookstate::Write_CustomPrimitiveData(Mesh, InVisual.CookState);
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
    // Pieces and the label
    //----------------------------------------------------------------------------------------------------------------------

    // A piece's look: the raw mesh of its preset's kind on the piece's body entity, in the crumb material (every slot), its
    // Custom Primitive Data written from its coverage. The entity is the body's centre and the meshes' pivots are at their
    // base, so the mesh is lowered by half the piece's size to fill the body's box. Tagged so a test can read it back.
    private void AddPieceVisuals(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle InPiece)
    {
        auto PieceTransform = InPiece.As_Transform();
        const auto Preset = _TumblerHandle.Get_PiecePresetIndex(InPieceId);
        const auto Scale = Get_PieceScale(Preset);

        auto Visual = FMars_TumblerStation_PieceVisual();
        Visual.Id = InPieceId;
        Visual.Entity = InPiece;
        Visual.CookState.Crumb = _TumblerHandle.Get_PieceCoverage(InPieceId);
        Visual.Part = PieceTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -float64(PieceSize) * 0.5), FVector(Scale, Scale, Scale)),
            Get_PieceMesh(Preset), assets::load::TumblerCrumb_Mars_M(), collision::profile::NoCollision, n"TumblerStation_Piece"));
        _PieceVisuals.Add(Visual);

        if (ck::Is_NOT_Valid(Visual.Part))
        { return; }

        utils_entity_tag::Add(Visual.Part, n"TAG_MarsTumblerPiece");
        utils_unreal_component::BindTo_OnAdded(Visual.Part, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPiecePartAdded"));
    }

    // The three raw kinds by a preset (or slot) index.
    private int32 Get_PieceKind(int32 InPreset) const
    {
        return InPreset % k_PieceKinds;
    }

    private UStaticMesh Get_PieceMesh(int32 InPreset) const
    {
        const auto Kind = Get_PieceKind(InPreset);
        if (Kind == 0)
        { return assets::load::Puffer_Mars_SM(); }

        if (Kind == 1)
        { return assets::load::Mushroom_Mars_SM(); }

        return assets::load::Drumstick_Mars_SM();
    }

    // Uniform scale fitting the kind's authored size to a PieceSize cube.
    private float64 Get_PieceScale(int32 InPreset) const
    {
        const auto Kind = Get_PieceKind(InPreset);
        auto MeshSize = DrumstickSize;
        if (Kind == 0)
        { MeshSize = PufferSize; }
        else if (Kind == 1)
        { MeshSize = MushroomSize; }

        return float64(PieceSize) / float64(MeshSize);
    }

    // Rewritten only when the text changes.
    private void Refresh_Label()
    {
        if (ck::Is_NOT_Valid(_TumblerHandle) || ck::Is_NOT_Valid(_Label))
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

    // What the label reads: why the last press was refused (for RefusalSeconds), otherwise the batch: how many pieces are in,
    // the hatch, and the batch's mean coverage.
    private FText Get_StateLabel() const
    {
        if (_RefusalLeft > 0.0f)
        { return FText::FromString(Get_RefusalText(_Refusal)); }

        const auto Ids = _TumblerHandle.Get_PieceIds();
        auto CoverageSum = 0.0f;
        for (const auto& Id : Ids)
        { CoverageSum += _TumblerHandle.Get_PieceCoverage(Id); }

        const auto MeanPercent = Ids.Num() > 0 ? Math::RoundToInt(100.0f * CoverageSum / float32(Ids.Num())) : 0;
        return FText::FromString(f"{Ids.Num()} in · hatch {Get_HatchText(_TumblerHandle.Get_Hatch())} · coverage {MeanPercent}%");
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

    UFUNCTION()
    private void OnLabelAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_Label();
    }

    // A raw proxy (on the platter or in the glove) wears the raw cook state; the dressing tick sets its visibility.
    UFUNCTION()
    private void OnRawPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto Mesh = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        utils_cookstate::Write_CustomPrimitiveData(Mesh, FMars_CookState());
        for (const auto& Part : _CarryProxyParts)
        {
            if (Part == InHandle)
            { Mesh.SetVisibility(false); }
        }
    }

    // The part's archetype set slot 0 only: every other slot of the raw mesh gets the crumb material too, and the piece its
    // coverage, so it never shows a default for a frame.
    UFUNCTION()
    private void OnPiecePartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto Mesh = Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        auto Crumb = assets::load::TumblerCrumb_Mars_M();
        for (int32 Slot = 1; Slot < Mesh.GetNumMaterials(); ++Slot)
        { Mesh.SetMaterial(Slot, Crumb); }

        for (const auto& Visual : _PieceVisuals)
        {
            if (Visual.Part == InHandle)
            {
                Write_PieceCpd(Visual);
                return;
            }
        }
    }

    UFUNCTION()
    private void OnPieceAdded(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        AddPieceVisuals(InPieceId, InPiece);
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
    private void OnHatchChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Hatch InHatch)
    {
        Refresh_Label();
    }
}
