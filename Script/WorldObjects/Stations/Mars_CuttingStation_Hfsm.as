// The cutting station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Cutting_Idle). It runs on the STATION entity (context = the station, which also carries the Cutting feature,
// the FoodBoard and the input platter's CookingFeed; its two platter docks are lifetime children of it) and reads the
// station's operator; it only issues Cutting, FoodBoard and CookingFeed requests and registers the operator's legend rows.
// The feed tasks are the shared ones (Mars_StationFeed_SmTasks.as): add food (Q) sends the free glove to the whole food on
// the input platter and the bridge hands it to the board through the station's inbox (the board poses it on its pile
// node); the board takes one joint at a time, so a press while it holds anything is refused here.
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_Source, StationFeed_Bridge (a release in flight
//                                                         lands), Cutting_ResetOnEnter (the hand back at the centre for
//                                                         the next operator)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Cutting_OperatorInput (Tick), Cutting_CutBridge,
//                                                         StationFeed_Source, CuttingFeed_OperatorInput (Tick),
//                                                         StationFeed_Bridge, CuttingFeed_OperatorHints (Tick),
//                                                         Cutting_OperatorHints
//
// The feed bridge runs in both states: it needs no operator, and a joint released over the board lands whoever is standing
// there. The sweep (RMB) is this station's take-out (the station's take-out contract on the board), so the feed's take-out
// input is not added: the board lands what it lets go on the finished tray, places back what the tray refuses, and keeps
// its pieces' pickups off while it holds them.
//
// The conditions are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose,
// the camera (Captured: the view stays still, the look delta is ours), the glove grips and the Leave intent.

namespace utils_cutting
{
    // The quarter turn R gives the food on the board.
    const float32 k_TurnDegrees = 90.0f;

    // Centimetres of hand travel along the board per degree of look yaw: the operator's look steers the cleaver.
    const float32 k_LateralCmPerLookDegree = 1.5f;

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

    // The sweep, the station's take-out: the board hands its free pieces to the docked finished tray, no more than it has
    // room for, loading each one it lets go. No tray docked caps it at none, which the board refuses (OnReleaseRefused
    // NoRoom), and the station's label says so.
    void Request_Sweep(FCk_Handle InStation)
    {
        const auto Tray = TryGet_Tray(InStation);
        const auto Room = ck::IsValid(Tray) ? Tray.Get_FreeCount() : 0;
        auto Station = InStation;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(Room, Tray));
    }

    // The turn: the food on the board yaws a quarter turn about the board's pile node, so the next chops cross the last ones.
    // The board waits out any cut in flight before it turns.
    void Request_Turn(FCk_Handle InStation)
    {
        auto Board = InStation.As_FoodBoard();
        Board.Request_Turn(FMars_Request_FoodBoard_Turn(k_TurnDegrees));
    }
}

class UMars_SmState_Cutting_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Cutting_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_Cutting_ResetOnEnter);
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
        AddTask(InHandle, UMars_SmTask_CuttingFeed_OperatorHints);
        AddTask(InHandle, UMars_SmTask_Cutting_OperatorHints);
    }
}

// The hand back at the board centre for the next operator. The board keeps whatever the last one left: the player's food is
// never cleared by an operator change. No Cutting on the context (a composition that failed and already ensured) = nothing
// to reset.
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

// The operator's input, read off its InputIntents: one nudge per drained look delta (its horizontal component in degrees,
// k_LateralCmPerLookDegree cm along the board each; positive = mouse right = the board's +Y, the operator's right), one
// chop per rising edge of Interact_Primary, one sweep (utils_cutting::Request_Sweep) per rising edge of Interact_Secondary
// and one turn (utils_cutting::Request_Turn) per rising edge of Drop (R: the hands are empty at a station, so nothing else
// reads it here). All are seeded on enter, so a delta or a press from before the station was taken does not count. No
// operator intents (headless) = nothing to read.
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
            _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge(float32(_Intents.Get_LookDelta().X) * utils_cutting::k_LateralCmPerLookDegree));
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
        return utils_cutting::Get_IsBoardBusy(_Board) == false;
    }
}

// The shared add-food row, reading "board busy" while the cutting station would refuse a press, re-texted on every board edge
// that changes it (a place, a release; a cut keeps the count above zero).
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
        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Board))
        {
            _Board.UnbindFrom_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
            _Board.UnbindFrom_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
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

    // A cut keeps the count above zero, so placements and releases are the only edges.
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
}
