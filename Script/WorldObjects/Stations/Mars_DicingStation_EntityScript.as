// The dicing station: a table (width along local Y, depth along local X) with a cutting board on top, the station's food on
// the board, a highlighted band the cleaver must be over to chop usefully, and a cleaver that slides along the board under
// the operator's hand. The operator stands StandGap uu in front of the table's -X edge facing +X; the view is Captured (the
// look delta slides the hand). While operating, the right glove holds the cleaver handle (riding the slide and the chop) and
// the left rests flat near the board's left edge, outside the cleaver's travel (the script sets the Dicing spec's
// BoardHalfWidth to HandHalfTravel).
//
// The station entity carries Dicing (the herb minigame) and FoodBoard (the pieces on the board), and two platter docks sit
// beside the board: the input platter (-Y) the food arrives on and the finished tray (+Y) the sweep fills. The station's
// state machine (Mars_DicingStation_Hfsm.as) takes the joint off the input platter onto the board, turns every chop into a
// board cut and hands the swept pieces to the tray. This script assembles what is seen and heard: it dresses the halves of
// every cut from the cut piece's own food definition, gives the furniture static bodies so loose pieces land on it, and
// keeps the label in step with the board and the tray.
class UMars_DicingStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Dicing_Spec Dicing;

    // The input platter brings one whole piece; the finished tray docks empty.
    UPROPERTY(EditDefaultsOnly, Category = "Docks")
    FMars_Station_DockPolicies Docks;
    default Docks.Input.WholeOnly = true;
    default Docks.Input.MaxPieces = TOptional<int32>(1);
    default Docks.Input.RequireEmpty = TOptional<bool>(false);
    default Docks.Output.RequireEmpty = TOptional<bool>(true);

    // The cut halves part 0.75 cm each way; a loose release slides the pieces toward the finished tray (+Y). A full board
    // only knocks (the label says so); released pieces stay at least two sweeps' worth before the oldest go.
    UPROPERTY(EditDefaultsOnly, Category = "Board")
    FMars_FoodBoard_Tuners BoardTuners;
    default BoardTuners.MaxHeldPieces = 32;
    default BoardTuners.MaxReleasedPieces = 64;
    default BoardTuners.SeparationCm = 1.5f;
    default BoardTuners.Release = FMars_FoodBoard_ReleaseTuners(n"PhysicsActor", 0.6f, 0.1f, FVector(0.0, 240.0, 0.0));

    // PrepTable_Mars_SM: 160 wide (the blockout was 140), the extra 10 cm a side making room for the input platter and the
    // finished tray beside the 90 cm board (station_spec.py PROPS["PrepTable"], CuttingStation_Layout.json).
    private const float64 TableWidth = 160.0;
    private const float64 TableDepth = 80.0;
    private const float64 TableHeight = constants_station::k_CounterHeight;
    // Close in: the capsule (radius 39) stands almost touching the table edge.
    private const float64 StandGap = 43.0;
    // The input platter's dock (left, -Y) and the finished tray's (right, +Y) sit beside the board at the table's Input /
    // Output sockets.
    private const float64 BowlY = 62.0;
    // The operating view, pitched hard onto the board from ViewGap uu off the table edge and ViewAboveBoard uu over the
    // board top. It lives in the station frame (Camera.ViewLocal), so the framing holds whatever the operator's eye height.
    private const float32 CameraPitch = -48.0f;
    private const float64 ViewGap = 38.0;
    private const float64 ViewAboveBoard = 58.0;
    // The Use probe's margin around the table.
    private const float64 ProbePadding = 5.0;

    private const float64 BoardWidth = 90.0;
    private const float64 BoardDepth = 50.0;
    private const float64 BoardThickness = 4.0;
    private const float64 BoardX = -5.0;

    // The hand's (and the cleaver's) lateral travel each side of the board centre: the Dicing spec's BoardHalfWidth, set
    // here because it is bound to the geometry - the cleaver (and the band table's extreme fraction of it) must stop
    // short of the left glove at -(BoardWidth / 2) + LeftGripEdgeInset.
    private const float32 HandHalfTravel = 28.0f;
    // The left glove's grip, in from the board's left (-Y) edge.
    private const float64 LeftGripEdgeInset = 6.0;

    // The left glove's grip bone above the board (the palm's thickness, FMars_FPHands_Spec.PalmSurfaceOffset).
    private const float64 PalmLift = 2.5;

    // The food (utils_dicing::Get_PileLocal) and the cleaver sit over the board's middle; the band marks the strip in front of
    // the food (operator side), just above the board so it never z-fights it.
    private const float64 BandX = -24.0;
    private const float64 BandDepth = 10.0;
    private const float64 BandLift = 0.5;
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

    // The state label above the board's far edge.
    private const float64 LabelInset = 5.0;
    private const float64 LabelHeight = 40.0;
    private const float32 LabelWorldSize = 10.0f;
    private const FColor LabelColor = FColor(255, 238, 0, 255);

    private const int32 k_ChopBurstBehavior = 13; // SparksBurst
    private const float64 ChopBurstLift = 1.0;
    private const float32 ChopBurstSize = 0.35f;
    private const float32 ChopBurstColorIntensity = 0.8f;
    private const float32 ChopBurstPlaybackSpeed = 1.6f;

    private FCk_Handle_Transform _Root;
    // The cleaver's knock on the board (KnifeChop_Cue, which carries its own close-range attenuation and sound class): a
    // local one-shot at the blade's contact on every chop.
    private USoundBase _ChopSound;
    // Dicing with the geometry-bound fields set (DoConstruct); what the feature and the visuals read.
    private FMars_Dicing_Spec _DicingSpec;
    private FCk_Handle_Dicing _DicingHandle;
    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_PlatterDock _InputDock;
    private FCk_Handle_PlatterDock _OutputDock;
    // The finished tray docked on _OutputDock, watched while it is there so the label follows its room.
    private FCk_Handle_Platter _OutputPlatter;
    private FCk_Handle_SceneNode _BandNode;
    private FCk_Handle_SceneNode _LateralNode;
    private FCk_Handle_Mover _ChopMover;
    // The right glove's grip: the cleaver handle, under the Mover node so it rides the chop and the lateral slide.
    private FCk_Handle_Transform _HandleGripNode;
    // The left glove's grip: flat near the board's left edge, outside the cleaver's travel.
    private FCk_Handle_Transform _BoardGripNode;
    private FCk_Handle_UnrealComponent _Label;
    private UNiagaraComponent _ChopBurst;
    private bool _OutlineClaimed = false;

    // The base composes the transform, the visuals and nodes (AddVisuals) and the Station (Configure_Spec, grips on the
    // registered nodes); the minigame, the board and the docks need the station, so they are composed after.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // Before the base: its AddVisuals reads the band and the strike from it.
        _DicingSpec = Dicing;
        _DicingSpec.BoardHalfWidth = HandHalfTravel;

        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to dice on.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        // A rejected Dicing spec already ensured in utils_dicing::Add.
        _DicingSpec.Nodes = FMars_Dicing_Nodes(_LateralNode, _ChopMover);
        _DicingHandle = utils_dicing::Add(InHandle, _DicingSpec);
        _ChopSound = assets::load::KnifeChop_Cue();

        // A rejected spec already ensured in utils_foodboard::Add.
        _Board = utils_foodboard::Add(InHandle, FMars_FoodBoard_Spec(BoardTuners));
        Add_Docks();
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_BandNode) && ck::IsValid(_Root))
        {
            UCk_Utils_Usf_Outline_UE::Set_OutlineClaim(_BandNode.H(), _Root,
                UCk_Utils_Usf_Outline_Settings_UE::Get_GameplayInteractionOutlineTag(), ECk_Usf_OutlineScope::EntityAndDependents);
            _OutlineClaimed = true;
        }

        if (ck::IsValid(_Board))
        {
            _Board.BindTo_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
            _Board.BindTo_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnBoardPieceCut"));
            _Board.BindTo_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnBoardCutIssued"));
            _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        }

        if (ck::IsValid(_OutputDock))
        {
            _OutputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
            _OutputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));
        }

        if (ck::Is_NOT_Valid(_DicingHandle))
        { return; }

        _DicingHandle.BindTo_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
        _DicingHandle.BindTo_OnBandMoved(FMars_Delegate_Dicing_OnBandMoved(this, n"OnBandMoved"));
        _DicingHandle.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
        _DicingHandle.BindTo_OnReset(FMars_Delegate_Dicing_OnReset(this, n"OnReset"));

        Refresh_Label();
        Move_Band(_DicingHandle.Get_BandCenter());
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_DicingHandle))
        {
            _DicingHandle.UnbindFrom_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
            _DicingHandle.UnbindFrom_OnBandMoved(FMars_Delegate_Dicing_OnBandMoved(this, n"OnBandMoved"));
            _DicingHandle.UnbindFrom_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
            _DicingHandle.UnbindFrom_OnReset(FMars_Delegate_Dicing_OnReset(this, n"OnReset"));
        }

        if (ck::IsValid(_Board))
        {
            _Board.UnbindFrom_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
            _Board.UnbindFrom_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnBoardPieceCut"));
            _Board.UnbindFrom_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnBoardCutIssued"));
            _Board.UnbindFrom_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        }

        if (ck::IsValid(_OutputDock))
        {
            _OutputDock.UnbindFrom_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
            _OutputDock.UnbindFrom_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));
        }

        Unwatch_OutputPlatter();

        if (_OutlineClaimed && ck::IsValid(_BandNode) && ck::IsValid(_Root))
        {
            UCk_Utils_Usf_Outline_UE::Clear_OutlineClaim(_BandNode.H(), _Root,
                UCk_Utils_Usf_Outline_Settings_UE::Get_GameplayInteractionOutlineTag());
        }

        _OutlineClaimed = false;

        if (ck::IsValid(_ChopBurst))
        { _ChopBurst.DestroyComponent(); }

        _ChopBurst = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(TableDepth * 0.5 + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        // Both grips take their node's frame: the handle node wraps the right glove around the horizontal handle, the
        // board node lays the left glove flat on the board.
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Surface, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(CameraPitch, 0.0, 0.0),
            FVector(-(TableDepth * 0.5 + ViewGap), 0.0, Get_BoardTop() + ViewAboveBoard)));
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "DiceHerbsPrompt", "Dice herbs"),
            NSLOCTEXT("MarsInteraction", "DicingStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Dicing_Idle;
    }

    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(
            FVector(TableDepth * 0.5 + ProbePadding, TableWidth * 0.5 + ProbePadding, TableHeight * 0.5 + ProbePadding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    // Engine cube and sphere are 100 uu with the pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;
        auto CubeMesh = engine::load::Cube();
        const auto BoardTop = Get_BoardTop();

        // The station props (station_spec.py): the table pivots at its floor contact, the board at the centre of its
        // underside (exactly the blockout board's 50 x 90 x 4 at BoardX). The docked platters are the bowl and the tray.
        AddFurniture(InRoot, FMars_MeshPart(FTransform::Identity,
            assets::load::PrepTable_Mars_SM(), nullptr, collision::profile::BlockAll, n"DicingStation_Table"));

        AddFurniture(InRoot, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(BoardX, 0.0, TableHeight)),
            assets::load::CuttingBoard_Mars_SM(), nullptr, collision::profile::BlockAll, n"DicingStation_Board"));

        // The band: a flat slab across the strip in front of the food, centred on the band; outlined in DoBeginPlay.
        _BandNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::ZeroRotator, FVector(BandX, utils_dicing::Get_BandCenterAt(_DicingSpec, 0), BoardTop + BandLift)));
        auto BandTransform = _BandNode.As_Transform();
        BandTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(BandDepth * 0.01, _DicingSpec.BandHalfWidth * 0.02, 0.01)),
            CubeMesh, assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"DicingStation_Band"));

        _Label = AddLabel(InRoot,
            FTransform(FRotator(0.0, 180.0, 0.0), FVector(TableDepth * 0.5 - LabelInset, 0.0, BoardTop + LabelHeight)));

        // A left hand flat on the board: fingers forward, palm down, the grip bone a palm's thickness above the wood.
        _BoardGripNode = utils_scene_node::Create(InRoot,
            FTransform(utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, -FVector::UpVector),
                FVector(BoardX, -BoardWidth * 0.5 + LeftGripEdgeInset, BoardTop + PalmLift))).As_Transform();

        AddCleaver(InRoot);
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _HandleGripNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _BoardGripNode));
    }

    // The part, and a static body of its mesh's authored convex collision on a node of its own at the same pose: the part's
    // collision is Chaos's, and a released piece is a Jolt body that would fall through it.
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

        // One Duration for both directions: the recover takes ChopDownSeconds too.
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = FVector(0.0, 0.0, BladeHalfHeight + CleaverRaise);
        MoverSpec.EndLocation = FVector(0.0, 0.0, BladeHalfHeight);
        MoverSpec.Duration = _DicingSpec.ChopDownSeconds;
        MoverSpec.Easing = ECk_TweenEasing::InQuad;
        _ChopMover = utils_mover::Add(CleaverNode, MoverSpec);

        // MeatCleaver_Mars_SM: pivot at the rear grip, blade along +X, edge down; its Strike socket (the edge's centre) is
        // CleaverEdgeFromGrip from the pivot. The mesh is placed so that edge centre sits BladeHalfHeight under the cleaver
        // node: the chop's contact puts the edge on the board, as the blockout blade's bottom was.
        auto CleaverTransform = CleaverNode.As_Transform();
        const auto GripLocal = FVector(-CleaverEdgeFromGrip.X, 0.0, -CleaverEdgeFromGrip.Z - BladeHalfHeight);
        CleaverTransform.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, GripLocal),
            assets::load::MeatCleaver_Mars_SM(), nullptr, collision::profile::NoCollision, n"DicingStation_Cleaver"));

        // A right-hand handshake grip on the rear grip, blade edge down: palm facing the operator's left (-Y), fingers curling
        // down round the handle, the hand leading toward the blade.
        _HandleGripNode = utils_scene_node::Create(CleaverTransform,
            FTransform(utils_fphands::Make_GripRotation(EMars_Hand::Right, -FVector::UpVector, -FVector::RightVector), GripLocal)).As_Transform();
    }

    // The two docks on the table's sockets beside the board, children of the root (they die with the station), lifted so a
    // docked platter's underside rests on the top. A rejected spec already ensured in utils_platter_dock::Create.
    private void Add_Docks()
    {
        const auto DockZ = TableHeight + constants_platter::k_FloorAboveBase;
        auto InputSpec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Input, Docks.Input,
            FTransform(FRotator::ZeroRotator, FVector(BoardX, -BowlY, DockZ)));
        InputSpec.Name = FText::FromString("input platter");
        _InputDock = utils_platter_dock::Create(_Root, InputSpec);

        auto OutputSpec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Output, Docks.Output,
            FTransform(FRotator::ZeroRotator, FVector(BoardX, BowlY, DockZ)));
        OutputSpec.Name = FText::FromString("finished tray");
        _OutputDock = utils_platter_dock::Create(_Root, OutputSpec);
    }

    private float64 Get_BoardTop() const
    {
        return TableHeight + BoardThickness;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals (the Dicing feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    private void Refresh_Label()
    {
        if (ck::Is_NOT_Valid(_DicingHandle) || ck::Is_NOT_Valid(_Label))
        { return; }

        // Null until the component is created (asynchronously); OnPartAdded refreshes then.
        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(_Label));
        if (ck::Is_NOT_Valid(Text))
        { return; }

        const auto StateLabel = Get_StateLabel(_DicingHandle.Get_MaterialState(), _DicingHandle.Get_RequestedState());
        const auto Tray = ck::IsValid(_OutputDock) ? _OutputDock.Get_Platter() : FCk_Handle_Platter();
        if (ck::Is_NOT_Valid(Tray))
        {
            Text.SetText(FText::FromString(f"{StateLabel}\nno tray: dock one to sweep"));
            return;
        }

        if (Tray.Get_IsFull())
        {
            Text.SetText(FText::FromString(f"{StateLabel}\ntray full"));
            return;
        }

        if (Get_IsBoardFull())
        {
            Text.SetText(FText::FromString(f"{StateLabel}\nboard full: sweep to tray"));
            return;
        }

        Text.SetText(StateLabel);
    }

    // A full board's chops only knock until a sweep clears it.
    private bool Get_IsBoardFull() const
    {
        return ck::IsValid(_Board) && _Board.Get_Occupancy() >= _Board.Get_Tuners().MaxHeldPieces;
    }

    // What the label reads: the texture, "stop here" once it is exactly the requested one, "over-processed" past it.
    private FText Get_StateLabel(EMars_Dicing_State InState, EMars_Dicing_State InRequested) const
    {
        const auto StateName = utils_dicing::Get_StateName(InState);
        if (InState == InRequested)
        { return FText::FromString(f"{StateName}: stop here"); }

        if (int32(InState) > int32(InRequested))
        { return FText::FromString(f"{StateName}: over-processed"); }

        return FText::FromString(StateName);
    }

    private void Move_Band(float32 InCenter)
    {
        if (ck::Is_NOT_Valid(_BandNode))
        { return; }

        utils_scene_node::Request_UpdateOffset_Location(_BandNode, FVector(BandX, InCenter, Get_BoardTop() + BandLift), ECk_RelativeAbsolute::Absolute);
    }

    private void Play_ChopSound()
    {
        if (ck::Is_NOT_Valid(_ChopSound) || ck::Is_NOT_Valid(_DicingHandle) || ck::Is_NOT_Valid(_Root))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Contact = RootWorld.TransformPosition(FVector(CleaverX, _DicingHandle.Get_HandLateral(), Get_BoardTop()));
        Gameplay::PlaySoundAtLocation(_ChopSound, Contact, RootWorld.Rotator());
    }

    // One reused burst component: spawned at the first aligned chop whose template is ready (a cold template never stalls
    // the game thread; the chop just goes without a burst), then moved and re-activated per chop. Null under nullrhi.
    private void Play_ChopBurst()
    {
        if (ck::Is_NOT_Valid(_DicingHandle) || ck::Is_NOT_Valid(_Root))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Contact = RootWorld.TransformPosition(FVector(CleaverX, _DicingHandle.Get_HandLateral(), Get_BoardTop() + ChopBurstLift));

        if (ck::IsValid(_ChopBurst))
        {
            _ChopBurst.SetWorldLocation(Contact);
            _ChopBurst.Activate(true);
            return;
        }

        if (utils_particles::Get_IsBehaviorTemplateReady(k_ChopBurstBehavior) == false)
        { return; }

        _ChopBurst = utils_particles::Spawn_BehaviorAtLocation(k_ChopBurstBehavior, Contact, RootWorld.Rotator());
        if (ck::IsValid(_ChopBurst))
        { utils_particles::Request_ApplyTuningValues(_ChopBurst, ChopBurstSize, ChopBurstColorIntensity, 1.0f, ChopBurstPlaybackSpeed); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Parts
    //----------------------------------------------------------------------------------------------------------------------

    // The state label above the board's far edge, yawed to face the operator. Its text is set once the component exists.
    private FCk_Handle_UnrealComponent AddLabel(FCk_Handle_Transform& InAttachTo, FTransform InLocalTransform)
    {
        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);

        auto Archetype = NewObject(this, UTextRenderComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Archetype.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Archetype.SetWorldSize(LabelWorldSize);
        Archetype.SetTextRenderColor(LabelColor);
        Archetype.SetText(Get_StateLabel(EMars_Dicing_State::WholeLeaves, _DicingSpec.RequestedState));

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"DicingStation_Label");
        return utils_unreal_component::Add(Node, ComponentParams);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnStateChanged(FCk_Handle_Dicing InDicing, EMars_Dicing_State InState)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnReset(FCk_Handle_Dicing InDicing)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnBandMoved(FCk_Handle_Dicing InDicing, float32 InCenter)
    {
        Move_Band(InCenter);
    }

    // The cleaver knocks on the board wherever it lands; only an aligned chop sparks.
    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        Play_ChopSound();
        if (InResult == EMars_Dicing_ChopResult::Aligned)
        { Play_ChopBurst(); }
    }

    UFUNCTION()
    private void OnBoardCleared(FCk_Handle_FoodBoard InBoard)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnBoardCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnBoardReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        Refresh_Label();
    }

    // The halves are born Ready and inherit the source's definition: they wear its food's display, whatever station built it.
    UFUNCTION()
    private void OnBoardPieceCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative)
    {
        const UMars_Food_Def Def = InPositive.Get_Definition().Get();
        if (ck::EnsureIfNot(ck::IsValid(Def), "[DicingStation] a cut piece has no definition to dress its halves with"))
        { return; }

        Def.Add_Display(InPositive);
        Def.Add_Display(InNegative);
        Refresh_Label();
    }

    UFUNCTION()
    private void OnOutputDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Unwatch_OutputPlatter();

        _OutputPlatter = InPlatter;
        _OutputPlatter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnTrayLoaded"));
        _OutputPlatter.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnTrayUnloaded"));
        Refresh_Label();
    }

    UFUNCTION()
    private void OnOutputUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Unwatch_OutputPlatter();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnTrayLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, int32 InSlot)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnTrayUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        Refresh_Label();
    }

    private void Unwatch_OutputPlatter()
    {
        if (ck::IsValid(_OutputPlatter))
        {
            _OutputPlatter.UnbindFrom_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnTrayLoaded"));
            _OutputPlatter.UnbindFrom_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnTrayUnloaded"));
        }

        _OutputPlatter = FCk_Handle_Platter();
    }
}
