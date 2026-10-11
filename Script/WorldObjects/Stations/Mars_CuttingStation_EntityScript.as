// The cutting station: a table (width along local Y, depth along local X) with a cutting board on top, the station's food on
// the board, and a cleaver that slides along the board under the operator's hand. The operator stands k_StandGap uu in
// front of the table's -X edge facing +X; the view is Captured (the look delta slides the hand). While operating, the right
// glove holds the cleaver handle (riding the slide and the chop) and the left is the feed's glove: it rests flat on the table
// between the input platter and the board, outside the cleaver's travel (the script sets the Cutting spec's BoardHalfWidth
// to HandHalfTravel), and add food sends it to the whole food on the input platter and over the board.
//
// The station entity carries Cutting (the cleaver), FoodBoard (the pieces on the board) and a CookingFeed (the left glove's
// transfers, drawing from the input platter), and two platter docks sit beside the board: the input platter (-Y) the food
// arrives on and the finished tray (+Y) the sweep fills. The station's state machine (Mars_CuttingStation_Hfsm.as) brings a
// joint from the input platter to the board on add food, turns every chop into a board cut, turns the food on the board and
// asks the board for a sweep (the station's take-out: the board lands what it lets go on the docked finished tray and
// places back what the tray refuses, and keeps its pieces' pickups off while it holds them). This script assembles what is
// seen and heard: the feed station base builds the feed's glove node (the feed moves it, the joint rides it) and keeps the
// label; this script builds the board's pile node (where the food lies, on the board's top), drives the cleaver's Mover
// from the kernel's chop signals, dresses the halves of every cut from the cut piece's own food definition, gives the
// furniture static bodies so loose pieces land on it, knocks on every chop and sparks on one that met food. The board
// itself never turns: the food turns on it, about the pile node.
class UMars_CuttingStation_EntityScript : UMars_FeedStation_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Cutting_Spec Cutting;

    // The input platter brings whole meat joints, as many as it carries, and may dock empty to be filled by hand; the
    // finished tray docks empty. The bench cuts meat for the pan: a vegetable (a slice is already cut, a whole one goes to
    // the fryer) is refused at the dock. The board's one joint at a time is the feed's only limit (the control refuses a
    // press while the board holds anything).
    default Docks.Input.WholeOnly = true;
    default Docks.Input.Kind = FGameplayTagQuery::MakeQuery_MatchTag(GameplayTags::Food_Meat);

    // The cut halves part 0.75 cm each way. A full board only knocks (the label says so).
    UPROPERTY(EditDefaultsOnly, Category = "Board")
    FMars_FoodBoard_Tuners BoardTuners;
    default BoardTuners.MaxHeldPieces = 32;
    default BoardTuners.SeparationCm = 1.5f;
    // A cross cut after a turn parts every piece under the blade.
    default BoardTuners.MaxCutsPerChop = 8;

    // PrepTable_Mars_SM: 160 wide, room for the input platter and the finished tray beside the 90 cm board
    // (station_spec.py PROPS["PrepTable"], CuttingStation_Layout.json).
    private const float64 TableWidth = 160.0;
    private const float64 TableDepth = 80.0;
    private const float64 TableHeight = constants_station::k_CounterHeight;
    // The input platter's dock (left, -Y) and the finished tray's (right, +Y) sit beside the board at the table's Input /
    // Output sockets.
    private const float64 BowlY = 62.0;
    // The operating view, pitched hard onto the board from ViewGap uu off the table edge and ViewAboveBoard uu over the
    // board top. It lives in the station frame (Camera.ViewLocal), so the framing holds whatever the operator's eye height.
    private const float32 CameraPitch = -48.0f;
    private const float64 ViewGap = 38.0;
    private const float64 ViewAboveBoard = 58.0;

    private const float64 BoardWidth = 90.0;
    private const float64 BoardDepth = 50.0;
    private const float64 BoardThickness = 4.0;
    private const float64 BoardX = -5.0;

    // The hand's (and the cleaver's) lateral travel each side of the board centre: the Cutting spec's BoardHalfWidth, set
    // here because it is bound to the geometry - the cleaver must stop short of the left glove's rest at FeedRestLocal.
    private const float32 HandHalfTravel = 28.0f;

    // The feed's glove at rest, on the table top: on the operator's side, between the input platter's dock (-BowlY) and the
    // board's left edge (-BoardWidth / 2).
    private const FVector FeedRestLocal = FVector(-28.0, -52.0, 0.0);
    // The release node over the pile: this far above the board plus a carried piece's half extent.
    private const float64 ReleaseClearance = 4.0;

    // The food (the board's pile node) and the cleaver sit at X 0, 5 cm off the board's centre line (BoardX).
    private const float64 PileX = 0.0;
    private const float64 CleaverX = 0.0;

    // Blade 30 long (X), 2 thick (Y), 12 tall, pivot at its centre: contact puts its bottom on the board.
    private const float64 BladeHalfHeight = 6.0;
    private const float64 CleaverRaise = 25.0;
    // The handle runs from the blade's near end toward the operator, near the blade's top.
    // The cleaver mesh's Strike socket (edge centre) from its rear-grip pivot: MeatCleaver_Mars_SM.json.
    private const FVector CleaverEdgeFromGrip = FVector(38.55, 0.0, -11.9);

    // The furniture's wood, for the pieces that land on it.
    private const float32 WoodFriction = 0.6f;
    private const float32 WoodRestitution = 0.1f;

    // The label above the board's far edge.
    private const float64 LabelInset = 5.0;
    private const float64 LabelHeight = 40.0;

    private const float64 ChopBurstLift = 1.0;

    // The cleaver's knock on the board (KnifeChop_Cue, which carries its own close-range attenuation and sound class): a
    // local one-shot at the blade's contact on every chop.
    private USoundBase _ChopSound;
    // Cutting with the geometry-bound fields set (Prepare_Kernel); what the feature and the visuals read.
    private FMars_Cutting_Spec _CuttingSpec;
    private FCk_Handle_Cutting _CuttingHandle;
    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_SceneNode _LateralNode;
    // The cleaver's strike, drawn from the kernel's chop signals: start = raised, end = contact with the board.
    private FCk_Handle_Mover _ChopMover;
    // Where the food lies on the board: the FoodBoard poses what it receives on it and turns the food about it.
    private FCk_Handle_Transform _PileNode;
    // The right glove's grip: the cleaver handle, under the Mover node so it rides the chop and the lateral slide.
    private FCk_Handle_Transform _HandleGripNode;

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_CuttingHandle))
        {
            _CuttingHandle.UnbindFrom_OnChopStarted(FMars_Delegate_Cutting_OnChopStarted(this, n"OnChopStarted"));
            _CuttingHandle.UnbindFrom_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));
        }

        if (ck::IsValid(_Board))
        {
            _Board.UnbindFrom_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnBoardPieceCut"));
            _Board.UnbindFrom_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnBoardCutIssued"));
            _Board.UnbindFrom_OnReleaseRefused(FMars_Delegate_FoodBoard_OnReleaseRefused(this, n"OnBoardReleaseRefused"));
        }

        Super::DoEndPlay(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    // Before the base: its AddVisuals reads the chop's timing from it.
    protected void Prepare_Kernel() override
    {
        _CuttingSpec = Cutting;
        _CuttingSpec.BoardHalfWidth = HandHalfTravel;
    }

    protected bool Compose_Kernel(FCk_Handle& InHandle) override
    {
        // A rejected Cutting spec already ensured in utils_cutting::Add.
        _CuttingSpec.Nodes = FMars_Cutting_Nodes(_LateralNode);
        _CuttingHandle = utils_cutting::Add(InHandle, _CuttingSpec);
        _ChopSound = assets::load::KnifeChop_Cue();

        // A rejected spec already ensured in utils_foodboard::Add.
        _Board = utils_foodboard::Add(InHandle, FMars_FoodBoard_Spec(BoardTuners, _PileNode));

        if (ck::IsValid(_Board))
        {
            _Board.BindTo_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnBoardPieceCut"));
            _Board.BindTo_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnBoardCutIssued"));
            _Board.BindTo_OnReleaseRefused(FMars_Delegate_FoodBoard_OnReleaseRefused(this, n"OnBoardReleaseRefused"));
        }

        if (ck::IsValid(_CuttingHandle))
        {
            _CuttingHandle.BindTo_OnChopStarted(FMars_Delegate_Cutting_OnChopStarted(this, n"OnChopStarted"));
            _CuttingHandle.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));
        }

        // The board still cuts what reaches it when the feed is rejected.
        return true;
    }

    protected void Configure_Operation(FMars_Station_Spec& InOutSpec) override
    {
        // The handle node wraps the right glove around the horizontal handle.
        auto Grips = TArray<FMars_Station_Grip>();
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(CameraPitch, 0.0, 0.0),
            FVector(-(TableDepth * 0.5 + ViewGap), 0.0, Get_BoardTop() + ViewAboveBoard)));
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "CutFoodPrompt", "Cut food"),
            NSLOCTEXT("MarsInteraction", "CuttingStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Cutting_Idle;
    }

    protected FVector2D Get_CounterFootprint() const override
    {
        return FVector2D(TableDepth, TableWidth);
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;
        const auto BoardTop = Get_BoardTop();

        // The station props (station_spec.py): the table pivots at its floor contact, the board at the centre of its
        // underside (50 x 90 x 4 at BoardX). The docked platters are the input platter and the finished tray.
        AddFurniture(InRoot, FMars_MeshPart(FTransform::Identity,
            assets::load::PrepTable_Mars_SM(), nullptr, collision::profile::BlockAll, n"CuttingStation_Table"));

        AddFurniture(InRoot, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(BoardX, 0.0, TableHeight)),
            assets::load::CuttingBoard_Mars_SM(), nullptr, collision::profile::BlockAll, n"CuttingStation_Board"));

        AddLabel(FTransform(FRotator(0.0, 180.0, 0.0), FVector(TableDepth * 0.5 - LabelInset, 0.0, BoardTop + LabelHeight)),
            EVerticalTextAligment::EVRTA_TextBottom, n"CuttingStation_Label");

        // The left glove rests on the table top; the docked input platter is the stock's only visual. The pile node sits on
        // the board's top; the release node over it is where the glove lets the joint go.
        Add_FeedHand(FVector(FeedRestLocal.X, FeedRestLocal.Y, TableHeight));
        const auto PileLocal = FVector(PileX, 0.0, BoardTop);
        _PileNode = utils_scene_node::Create(InRoot, FTransform(PileLocal)).As_Transform();
        const auto ReleaseLocal = PileLocal + FVector(0.0, 0.0, constants_station::k_CarriedHalfExtent + ReleaseClearance);
        _ReleaseNode = utils_scene_node::Create(InRoot, FTransform(ReleaseLocal)).As_Transform();

        AddCleaver(InRoot);
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _HandleGripNode));
        Super::Register_GripNodes(OutNodes);
    }

    protected FMars_FeedStation_DockLayout Get_DockLayout() const override
    {
        auto Layout = FMars_FeedStation_DockLayout();
        Layout.Input = FMars_FeedStation_DockSpot(FVector(BoardX, -BowlY, 0.0), FText::FromString("input platter"),
            n"CuttingStation_InputDockMarker");
        Layout.Input.KindRejectedText = FText::FromString("Meat only");
        Layout.Output = FMars_FeedStation_DockSpot(FVector(BoardX, BowlY, 0.0), FText::FromString("finished tray"),
            n"CuttingStation_OutputDockMarker");
        return Layout;
    }

    // What the board holds, then what keeps a sweep from landing: no tray, a full one, or a full board.
    protected FText Get_StateLabel() const override
    {
        const auto BoardLine = Get_BoardLine();
        const auto Tray = Get_Tray();
        if (ck::Is_NOT_Valid(Tray))
        { return FText::FromString(f"{BoardLine}\nno tray: dock one to sweep"); }

        if (Tray.Get_IsFull())
        { return FText::FromString(f"{BoardLine}\ntray full"); }

        if (Get_IsBoardFull())
        { return FText::FromString(f"{BoardLine}\nboard full: sweep to tray"); }

        return FText::FromString(BoardLine);
    }

    protected FString Get_StationGateText() const override
    {
        return "board busy";
    }

    // The part, and a static body of its mesh's authored convex collision on a node of its own at the same pose: the part's
    // collision is Chaos's, and a food piece's body is a Jolt body that would fall through it.
    private void AddFurniture(FCk_Handle_Transform& InRoot, const FMars_MeshPart& InPart)
    {
        InRoot.Add_MeshPart(this, InPart);

        auto Part = InPart;
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::StaticMeshAsset);
        BodySpec.Set_StaticMesh(TSoftObjectPtr<UStaticMesh>(Part.Mesh));
        BodySpec.Set_MotionType(ECk_MotionType::Static);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(WoodFriction);
        BodySpec.Set_Restitution(WoodRestitution);
        BodySpec.Set_CollisionProfileName(collision::profile::BlockAll);

        auto BodyNode = utils_scene_node::Create(InRoot, InPart.LocalTransform);
        utils_jolt_body::Add(BodyNode.H(), BodySpec);
    }

    // The cleaver: a lateral node the hand slides along the board (Y), a Mover node under it for the chop (Z), the blade
    // and handle parts, and the handle's grip node, all under the Mover node so they ride both.
    private void AddCleaver(FCk_Handle_Transform& InRoot)
    {
        _LateralNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(CleaverX, 0.0, Get_BoardTop())));
        auto LateralTransform = _LateralNode.As_Transform();
        auto CleaverNode = utils_scene_node::Create(LateralTransform,
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, BladeHalfHeight + CleaverRaise)));

        // One Duration for both directions, the kernel's ChopSeconds: the strike reaches the board as the chop lands, and
        // the recover takes as long.
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = FVector(0.0, 0.0, BladeHalfHeight + CleaverRaise);
        MoverSpec.EndLocation = FVector(0.0, 0.0, BladeHalfHeight);
        MoverSpec.Duration = _CuttingSpec.ChopSeconds;
        MoverSpec.Easing = ECk_TweenEasing::InQuad;
        _ChopMover = utils_mover::Add(CleaverNode, MoverSpec);

        // MeatCleaver_Mars_SM: pivot at the rear grip, blade along +X, edge down; its Strike socket (the edge's centre) is
        // CleaverEdgeFromGrip from the pivot. The mesh is placed so that edge centre sits BladeHalfHeight under the cleaver
        // node: the chop's contact puts the edge on the board.
        auto CleaverTransform = CleaverNode.As_Transform();
        const auto GripLocal = FVector(-CleaverEdgeFromGrip.X, 0.0, -CleaverEdgeFromGrip.Z - BladeHalfHeight);
        CleaverTransform.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, GripLocal),
            assets::load::MeatCleaver_Mars_SM(), nullptr, collision::profile::NoCollision, n"CuttingStation_Cleaver"));

        // A right-hand handshake grip on the rear grip, blade edge down: palm facing the operator's left (-Y), fingers curling
        // down round the handle, the hand leading toward the blade.
        _HandleGripNode = utils_scene_node::Create(CleaverTransform,
            FTransform(utils_fphands::Make_GripRotation(EMars_Hand::Right, -FVector::UpVector, -FVector::RightVector), GripLocal)).As_Transform();
    }

    private float64 Get_BoardTop() const
    {
        return TableHeight + BoardThickness;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals (the board, the tray and the feed are the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // A full board's chops only knock until a sweep clears it.
    private bool Get_IsBoardFull() const
    {
        return ck::IsValid(_Board) && _Board.Get_Occupancy() >= _Board.Get_Tuners().MaxHeldPieces;
    }

    // What the board holds: its piece count, or what to do with an empty one.
    private FString Get_BoardLine() const
    {
        const auto Count = ck::IsValid(_Board) ? _Board.Get_HeldCount() : 0;
        if (Count == 0)
        { return "Empty: add food from the input platter"; }

        return f"{Count} on the board";
    }

    private void Play_ChopSound()
    {
        if (ck::Is_NOT_Valid(_ChopSound) || ck::Is_NOT_Valid(_CuttingHandle) || ck::Is_NOT_Valid(_Root))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Contact = RootWorld.TransformPosition(FVector(CleaverX, _CuttingHandle.Get_HandLateral(), Get_BoardTop()));
        Gameplay::PlaySoundAtLocation(_ChopSound, Contact, RootWorld.Rotator());
    }

    // The burst at the blade's contact.
    private void Play_ChopBurst()
    {
        if (ck::Is_NOT_Valid(_CuttingHandle) || ck::Is_NOT_Valid(_Root))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Contact = RootWorld.TransformPosition(FVector(CleaverX, _CuttingHandle.Get_HandLateral(), Get_BoardTop() + ChopBurstLift));
        Play_Burst(Contact, RootWorld.Rotator());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    // The cleaver drops toward the board.
    UFUNCTION()
    private void OnChopStarted(FCk_Handle_Cutting InCutting)
    {
        _ChopMover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::End));
    }

    // The cleaver knocks on the board wherever it lands, and goes back up.
    UFUNCTION()
    private void OnChopLanded(FCk_Handle_Cutting InCutting)
    {
        _ChopMover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::Start));
        Play_ChopSound();
    }

    // The board's answer to the chop: it sparks only when the blade met food.
    UFUNCTION()
    private void OnBoardCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue)
    {
        if (InIssue.Straddling > 0)
        { Play_ChopBurst(); }
    }

    UFUNCTION()
    private void OnBoardReleaseRefused(FCk_Handle_FoodBoard InBoard, EMars_FoodBoard_ReleaseRefusal InRefusal)
    {
        if (InRefusal == EMars_FoodBoard_ReleaseRefusal::NoRoom)
        {
            Flash_Refusal(Get_NoRoomText());
            return;
        }

        Flash_Refusal("nothing to sweep");
    }

    // The halves are born Ready and inherit the source's definition: they wear its food's display, whatever station built it.
    UFUNCTION()
    private void OnBoardPieceCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative)
    {
        const UMars_Food_Def Def = InPositive.Get_Definition().Get();
        if (ck::EnsureIfNot(ck::IsValid(Def), "[CuttingStation] a cut piece has no definition to dress its halves with"))
        { return; }

        Def.Add_Display(InPositive);
        Def.Add_Display(InNegative);
    }
}
