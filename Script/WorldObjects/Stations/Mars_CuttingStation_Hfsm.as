// The cutting station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Cutting_Idle). It runs on the STATION entity (context = the station, which also carries the Cutting feature,
// the FoodBoard and the input platter's CookingFeed; its two platter docks are lifetime children of it) and reads the
// station's operator; it only issues Cutting, FoodBoard, CookingFeed and Platter requests, switches the pickup of a whole
// food the board holds and registers the operator's legend rows. The feed tasks are the shared ones
// (Mars_StationFeed_SmTasks.as): add food (Q) sends the free glove to the whole food on the input platter and the bridge
// places it on the board; the board takes one joint at a time, so a press while it holds anything is refused here.
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_ResetOnEnter (a new generation for an idle hand),
//                                                         StationFeed_Source, StationFeed_Bridge (a release in flight
//                                                         lands), Cutting_ResetOnEnter (the hand back at the centre for
//                                                         the next operator), Cutting_SweepBridge
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Cutting_OperatorInput (Tick), Cutting_CutBridge,
//                                                         StationFeed_Source, CuttingFeed_OperatorInput (Tick),
//                                                         StationFeed_Bridge, Cutting_SweepBridge, CuttingFeed_OperatorHints,
//                                                         Cutting_OperatorHints
//
// The feed bridge and the sweep bridge run in both states: neither needs an operator, and a joint released over the board
// or a piece the board handed off lands whoever is standing there. The sweep (RMB) is this station's take-out, so the
// feed's take-out tasks are not added.
//
// The conditions are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose,
// the camera (Captured: the view stays still, the look delta is ours), the glove grips and the Leave intent.

namespace utils_cutting
{
    // The quarter turn R gives the food on the board.
    const float32 k_TurnDegrees = 90.0f;

    // Where the food lies on the board, in the station frame: over the board's middle, on its top (the counter and the 4 cm
    // board). Here, beside the control that lays pieces there. A function: a global's initializer cannot read another
    // module's constant.
    FTransform Get_PileLocal()
    {
        return FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, constants_station::k_CounterHeight + 4.0));
    }

    // The pile point in the world, at unit scale and with no food's layout: what the food on the board turns about.
    FTransform Get_PileCentreWorld(const FTransform& InStationWorld)
    {
        auto PileWorld = Get_PileLocal() * InStationWorld;
        PileWorld.SetScale3D(FVector::OneVector);
        return PileWorld;
    }

    // The blade as a cutting plane at contact: through the hand's lateral position, its normal along the hand's travel (the
    // station's local Y), its face along the board's depth. Read from the station root and Cutting's HandLateral rather than
    // the lateral node, which lags a nudge drained in the chop's own frame. Here, beside the control that captures it, so
    // the cleaver kernel never learns about food.
    FMars_FoodPiece_WorldPlane Get_BladePlane(const FTransform& InStationWorld, float32 InHandLateral)
    {
        return FMars_FoodPiece_WorldPlane(
            InStationWorld.TransformPosition(FVector(0.0, float64(InHandLateral), 0.0)),
            InStationWorld.TransformVectorNoScale(FVector::RightVector),
            InStationWorld.TransformVectorNoScale(FVector::ForwardVector));
    }

    // The pose InPiece takes on the board: the pile, with its food's layout applied (yaw about the station's Z, lift along
    // it), at unit scale. A piece with no definition lies unrotated.
    FTransform Get_PileWorld(const FTransform& InStationWorld, const FCk_Handle_FoodPiece& InPiece)
    {
        auto LayoutLocal = FTransform::Identity;
        const UMars_Food_Def Def = InPiece.Get_Definition().Get();
        if (ck::IsValid(Def))
        { LayoutLocal = FTransform(FRotator(0.0, Def.Layout.YawDegrees, 0.0), FVector(0.0, 0.0, Def.Layout.LiftCm)); }

        auto PileWorld = LayoutLocal * Get_PileLocal() * InStationWorld;
        PileWorld.SetScale3D(FVector::OneVector);
        return PileWorld;
    }

    // The board takes one joint at a time: an add-food press is refused while it holds anything, cut or whole.
    bool Get_IsBoardBusy(const FCk_Handle_FoodBoard& InBoard)
    {
        return InBoard.Get_HeldCount() > 0;
    }

    // The platter docked on the station's finished-tray dock; invalid with nothing docked.
    FCk_Handle_Platter TryGet_Tray(FCk_Handle InStation)
    {
        const auto Dock = utils_platter_dock::Find_OnStation(InStation, EMars_PlatterDock_Role::Output);
        if (ck::Is_NOT_Valid(Dock))
        { return FCk_Handle_Platter(); }

        return Dock.Get_Platter();
    }

    // The sweep: hands the board's free pieces to the docked finished tray, no more than it has room for (the sweep bridge
    // loads each one the board lets go). No tray docked = refused; the station's label already says so.
    void Request_Sweep(FCk_Handle InStation)
    {
        const auto Tray = TryGet_Tray(InStation);
        if (ck::Is_NOT_Valid(Tray))
        {
            ck::Trace("[Cutting] sweep refused: no tray");
            return;
        }

        auto Board = InStation.As_FoodBoard();
        Board.Request_Release(FMars_Request_FoodBoard_Release(EMars_FoodBoard_ReleaseMode::Handoff, TOptional<int32>(Tray.Get_FreeCount())));
    }

    // The turn: the food on the board yaws a quarter turn about the pile point, so the next chops cross the last ones. The
    // board waits out any cut in flight before it turns.
    void Request_Turn(FCk_Handle InStation)
    {
        auto Board = InStation.As_FoodBoard();
        const auto StationWorld = utils_transform::Get_EntityCurrentTransform(InStation.As_Transform());
        Board.Request_Turn(FMars_Request_FoodBoard_Turn(Get_PileCentreWorld(StationWorld), k_TurnDegrees));
    }
}

class UMars_SmState_Cutting_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Cutting_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_StationFeed_ResetOnEnter);
        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_Cutting_ResetOnEnter);
        AddTask(InHandle, UMars_SmTask_Cutting_SweepBridge);
    }
}

class UMars_SmState_Cutting_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Cutting_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Cutting_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Cutting_CutBridge);
        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_CuttingFeed_OperatorInput);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_Cutting_SweepBridge);
        AddTask(InHandle, UMars_SmTask_CuttingFeed_OperatorHints);
        AddTask(InHandle, UMars_SmTask_Cutting_OperatorHints);
    }
}

// The hand back at the board centre for the next operator. The board keeps whatever the last one left: the player's food is
// never cleared by an operator change. No Cutting on the context yet (the SM can enter before the entity script composes
// it) = nothing to reset.
class UMars_SmTask_Cutting_ResetOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Station = ck::Ctx(InHandle);

        auto Cutting = Station.As_Cutting(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Cutting))
        { Cutting.Request_Reset(FMars_Request_Cutting_Reset()); }
    }
}

// The operator's input, read off its InputIntents: one nudge per drained look delta (its horizontal component, degrees;
// positive = mouse right = the board's +Y, the operator's right), one chop per rising edge of Interact_Primary, one sweep
// (utils_cutting::Request_Sweep) per rising edge of Interact_Secondary and one turn (utils_cutting::Request_Turn) per rising
// edge of Drop (R: the hands are empty at a station, so nothing else reads it here). All are seeded on enter, so a delta or
// a press from before the station was taken does not count. No operator intents (headless) = nothing to read.
class UMars_SmTask_Cutting_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Station;
    private FCk_Handle_Cutting _Cutting;
    private FCk_Handle_InputIntents _Intents;
    private int32 _SeenLookSequence = 0;
    // The activation frame of the Interact_Primary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenChopFrame;
    // The same for Interact_Secondary.
    private TOptional<int32> _SeenSweepFrame;
    // The same for Drop.
    private TOptional<int32> _SeenTurnFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Station = StationEntity;
        _Cutting = StationEntity.As_Cutting();
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenLookSequence = _Intents.Get_LookDeltaSequence();
        _SeenChopFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        _SeenSweepFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
        _SeenTurnFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Drop);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Cutting) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto Sequence = _Intents.Get_LookDeltaSequence();
        if (Sequence != _SeenLookSequence)
        {
            _SeenLookSequence = Sequence;
            _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge(float32(_Intents.Get_LookDelta().X)));
        }

        const auto ChopFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        if (ChopFrame != _SeenChopFrame)
        {
            _SeenChopFrame = ChopFrame;
            if (ChopFrame.IsSet())
            { _Cutting.Request_Chop(FMars_Request_Cutting_Chop()); }
        }

        const auto SweepFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
        if (SweepFrame != _SeenSweepFrame)
        {
            _SeenSweepFrame = SweepFrame;
            if (SweepFrame.IsSet())
            { utils_cutting::Request_Sweep(_Station); }
        }

        const auto TurnFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Drop);
        if (TurnFrame != _SeenTurnFrame)
        {
            _SeenTurnFrame = TurnFrame;
            if (TurnFrame.IsSet())
            { utils_cutting::Request_Turn(_Station); }
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = FCk_Handle();
        _Cutting = FCk_Handle_Cutting();
        _Intents = FCk_Handle_InputIntents();
        _SeenLookSequence = 0;
        _SeenChopFrame.Reset();
        _SeenSweepFrame.Reset();
        _SeenTurnFrame.Reset();
    }
}

// Every chop the cleaver lands cuts the board along the blade: the board holds the food under the blade, and its answer
// (OnCutIssued) says whether the blade met any. The binding lives exactly as long as the Operated state, so a chop that lands
// after the operator left cuts nothing. It needs no operator input, so a headless operator drives it too. No board or
// Cutting on the context (a composition that failed and already ensured) = nothing to cut.
class UMars_SmTask_Cutting_CutBridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_Transform _Root;
    private FCk_Handle_Cutting _Cutting;
    private FCk_Handle_FoodBoard _Board;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Board = StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked);
        _Cutting = StationEntity.As_Cutting(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Board) || ck::Is_NOT_Valid(_Cutting))
        { return; }

        _Root = StationEntity.As_Transform();
        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Cutting))
        { _Cutting.UnbindFrom_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded")); }

        _Root = FCk_Handle_Transform();
        _Cutting = FCk_Handle_Cutting();
        _Board = FCk_Handle_FoodBoard();
    }

    UFUNCTION()
    private void OnChopLanded(FCk_Handle_Cutting InCutting)
    {
        const auto StationWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(utils_cutting::Get_BladePlane(StationWorld, InCutting.Get_HandLateral())));
    }
}

// The shared add-food input, refused by the cutting station while the board holds anything (utils_cutting::Get_IsBoardBusy:
// one joint at a time): a refused edge is consumed before BeginTransfer, so nothing is queued.
class UMars_SmTask_CuttingFeed_OperatorInput : UMars_SmTask_StationFeed_OperatorInput
{
    private FCk_Handle_FoodBoard _Board;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoEnterTask(InHandle, InNetContext);
        _Board = ck::Ctx(InHandle).As_FoodBoard();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);
        _Board = FCk_Handle_FoodBoard();
    }

    protected bool Get_CanBeginTransfer() const override
    {
        if (utils_cutting::Get_IsBoardBusy(_Board) == false)
        { return true; }

        ck::Trace(f"[Cutting] add food refused: board busy ({_Board.Get_HeldCount()} on [{_Board.ToString()}])");
        return false;
    }
}

// The shared add-food row, reading "board busy" while the cutting station would refuse a press, re-texted on every board edge
// that changes it (a place, a release, a clear; a cut keeps the count above zero).
class UMars_SmTask_CuttingFeed_OperatorHints : UMars_SmTask_StationFeed_OperatorHints
{
    private FCk_Handle_FoodBoard _Board;

    // The board first: the row's first text reads it.
    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Board = ck::Ctx(InHandle).As_FoodBoard();
        _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
        _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        _Board.BindTo_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Board))
        {
            _Board.UnbindFrom_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
            _Board.UnbindFrom_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
            _Board.UnbindFrom_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
        }

        Super::DoExitTask(InHandle, InNetContext);
        _Board = FCk_Handle_FoodBoard();
    }

    protected TOptional<FString> TryGet_StationRefusal() const override
    {
        if (utils_cutting::Get_IsBoardBusy(_Board) == false)
        { return TOptional<FString>(); }

        const FString Refusal = "board busy";
        return TOptional<FString>(Refusal);
    }

    UFUNCTION()
    private void OnBoardPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        Refresh_AddFoodRow();
    }

    UFUNCTION()
    private void OnBoardReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        Refresh_AddFoodRow();
    }

    UFUNCTION()
    private void OnBoardCleared(FCk_Handle_FoodBoard InBoard)
    {
        Refresh_AddFoodRow();
    }
}

// The board's pieces' pickups, and the sweep's landing. A whole food is a world item whose pickup would let a hand take it
// off the board behind the board's back (the board never reconciles): every piece the board places loses its pickup, and
// every piece it lets go gets it back, whoever asked (a piece with no world item needs nothing). Every piece the board lets
// go is then loaded onto the docked finished tray, where it drops onto the pile. The sweep releases only with a tray docked
// and only as many as it has room for (utils_cutting::Request_Sweep); a piece released with no tray docked is left where it
// is. It runs in both states, so a sweep in the frame the operator leaves still lands on the tray; the bindings live as long
// as the state. No board on the context (a composition that failed and already ensured) = nothing to bridge.
class UMars_SmTask_Cutting_SweepBridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Station;
    private FCk_Handle_FoodBoard _Board;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Board = StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Board))
        { return; }

        _Station = StationEntity;
        _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnPlaced"));
        _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnReleased"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Board))
        {
            _Board.UnbindFrom_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnPlaced"));
            _Board.UnbindFrom_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnReleased"));
        }

        _Station = FCk_Handle();
        _Board = FCk_Handle_FoodBoard();
    }

    UFUNCTION()
    private void OnPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        utils_world_item::Request_SetPickupEnableDisable(InPiece, ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void OnReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        utils_world_item::Request_SetPickupEnableDisable(InPiece, ECk_EnableDisable::Enable);

        auto Tray = utils_cutting::TryGet_Tray(_Station);
        if (ck::Is_NOT_Valid(Tray))
        {
            ck::Trace(f"[Cutting] [{InPiece.ToString()}] was released with no tray docked: it stays where it is");
            return;
        }

        Tray.Request_Load(FMars_Request_Platter_Load(InPiece));
    }
}

// The operator's legend rows while operating, under owner key k_OwnerKey: "move hand" (IA_Look), "chop"
// (IA_Interact_Primary), "to tray" (IA_Interact_Secondary) while a finished tray is docked, and "turn" (IA_Drop) while the
// board holds anything; the add-food row (sort order 6) is the feed's, between chop and to tray. The board's count is the
// station's world label, not a row: a legend row without an InputAction does not render. An operator without a display
// (headless) gets no rows.
class UMars_SmTask_Cutting_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Cutting";
    private const int32 k_MoveHandSortOrder = 4;
    private const int32 k_ChopSortOrder = 5;
    private const int32 k_SweepSortOrder = 9;
    private const int32 k_TurnSortOrder = 10;

    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_PlatterDock _OutputDock;
    private FCk_Handle_FoodBoard _Board;
    // Registered while a finished tray is docked.
    private FCk_Handle_ActionHintRow _SweepRow;
    // Registered while the board holds anything.
    private FCk_Handle_ActionHintRow _TurnRow;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Display = FCk_Handle_ActionHintDisplay();

        auto StationEntity = ck::Ctx(InHandle);
        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Display = Operator.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Look, FText::FromString("move hand"), k_MoveHandSortOrder, k_OwnerKey));
        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Primary, FText::FromString("chop"), k_ChopSortOrder, k_OwnerKey));

        _Board = StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Board))
        {
            _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
            _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
            _Board.BindTo_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
            Refresh_TurnRow();
        }

        _OutputDock = utils_platter_dock::Find_OnStation(StationEntity, EMars_PlatterDock_Role::Output);
        if (ck::Is_NOT_Valid(_OutputDock))
        { return; }

        _OutputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
        _OutputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));
        if (ck::IsValid(_OutputDock.Get_Platter()))
        { Register_Sweep(); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_OutputDock))
        {
            _OutputDock.UnbindFrom_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
            _OutputDock.UnbindFrom_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));
        }

        if (ck::IsValid(_Board))
        {
            _Board.UnbindFrom_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
            _Board.UnbindFrom_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
            _Board.UnbindFrom_OnCleared(FMars_Delegate_FoodBoard_OnCleared(this, n"OnBoardCleared"));
        }

        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Display = FCk_Handle_ActionHintDisplay();
        _OutputDock = FCk_Handle_PlatterDock();
        _Board = FCk_Handle_FoodBoard();
        _SweepRow = FCk_Handle_ActionHintRow();
        _TurnRow = FCk_Handle_ActionHintRow();
    }

    private void Register_Sweep()
    {
        if (ck::IsValid(_SweepRow))
        { return; }

        _SweepRow = _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Secondary, FText::FromString("to tray"), k_SweepSortOrder, k_OwnerKey));
    }

    // A cut keeps the count above zero, so placements, releases and clears are the only edges.
    private void Refresh_TurnRow()
    {
        const auto HoldsAnything = _Board.Get_HeldCount() > 0;
        if (HoldsAnything && ck::Is_NOT_Valid(_TurnRow))
        {
            _TurnRow = _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Drop, FText::FromString("turn"), k_TurnSortOrder, k_OwnerKey));
            return;
        }

        if (HoldsAnything == false && ck::IsValid(_TurnRow))
        {
            _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(_TurnRow));
            _TurnRow = FCk_Handle_ActionHintRow();
        }
    }

    UFUNCTION()
    private void OnOutputDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Register_Sweep();
    }

    UFUNCTION()
    private void OnOutputUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        if (ck::Is_NOT_Valid(_SweepRow))
        { return; }

        _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(_SweepRow));
        _SweepRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnBoardPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        Refresh_TurnRow();
    }

    UFUNCTION()
    private void OnBoardReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        Refresh_TurnRow();
    }

    UFUNCTION()
    private void OnBoardCleared(FCk_Handle_FoodBoard InBoard)
    {
        Refresh_TurnRow();
    }
}
