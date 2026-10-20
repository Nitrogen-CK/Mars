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

    // What the bench cuts, the input dock's Kind: meat for the pan, and the pickle. A mushroom is not (a slice is already
    // cut, a whole one goes to the fryer).
    FGameplayTagQuery Make_BenchKindQuery()
    {
        auto Kinds = FGameplayTagContainer();
        Kinds.AddTag(GameplayTags::Food_Meat);
        Kinds.AddTag(GameplayTags::Food_Vegetable_Pickle);
        return FGameplayTagQuery::MakeQuery_MatchAnyTags(Kinds);
    }

    // The sweep, the station's take-out: the board hands its free pieces to the docked finished tray, no more than it has
    // room for, loading each one it lets go. No tray docked caps it at none, which the board refuses (OnReleaseRefused
    // NoRoom), and the station's label says so.
    void Request_Sweep(FCk_Handle InStation)
    {
        utils_cooking_feed::Request_TakeOutToDock(InStation, utils_platter_dock::Find_OnStation(InStation, EMars_PlatterDock_Role::Output));
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

// The operator's input: one nudge per drained look delta (its horizontal component in degrees, k_LateralCmPerLookDegree cm
// along the board each; positive = mouse right = the board's +Y, the operator's right), one chop per press of
// Interact_Primary, one sweep (utils_cutting::Request_Sweep) per press of Interact_Secondary and one turn
// (utils_cutting::Request_Turn) per press of Drop (R: the hands are empty at a station, so nothing else reads it here).
class UMars_SmTask_Cutting_OperatorInput : UMars_SmTask_StationOperatorInput
{
    private FCk_Handle_Cutting _Cutting;
    private FMars_LookCursor _Look;
    private FMars_IntentEdge _Chop;
    private FMars_IntentEdge _Sweep;
    private FMars_IntentEdge _Turn;

    protected void Bind(FCk_Handle InStation) override
    {
        _Cutting = InStation.As_Cutting();
    }

    protected void Seed() override
    {
        _Look.Seed(_Intents);
        _Chop.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
        _Sweep.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Secondary);
        _Turn.Seed(_Intents, GameplayTags::Mars_Intent_Drop);
    }

    protected void Poll() override
    {
        if (ck::Is_NOT_Valid(_Cutting))
        { return; }

        if (_Look.Advance(_Intents))
        { _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge(float32(_Intents.Get_LookDelta().X) * utils_cutting::k_LateralCmPerLookDegree)); }

        if (utils_station::Get_HasPress(_Chop.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Primary)))
        { _Cutting.Request_Chop(FMars_Request_Cutting_Chop()); }

        if (utils_station::Get_HasPress(_Sweep.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Secondary)))
        { utils_cutting::Request_Sweep(_Station); }

        if (utils_station::Get_HasPress(_Turn.Advance(_Intents, GameplayTags::Mars_Intent_Drop)))
        { utils_cutting::Request_Turn(_Station); }
    }

    protected void Unbind() override
    {
        _Cutting = FCk_Handle_Cutting();
        _Look = FMars_LookCursor();
        _Chop = FMars_IntentEdge();
        _Sweep = FMars_IntentEdge();
        _Turn = FMars_IntentEdge();
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

// The shared add-food input, refused by the cutting station while the board holds anything (one joint at a time): a
// refused press is the feed's StationGate refusal, so nothing is queued.
class UMars_SmTask_CuttingFeed_OperatorInput : UMars_SmTask_StationFeed_OperatorInput
{
    private FCk_Handle_FoodBoard _Board;

    protected void Bind(FCk_Handle InStation) override
    {
        Super::Bind(InStation);
        _Board = InStation.As_FoodBoard();
    }

    protected void Unbind() override
    {
        Super::Unbind();
        _Board = FCk_Handle_FoodBoard();
    }

    protected bool Get_CanBeginTransfer() const override
    {
        return ck::IsValid(_Board) && _Board.Get_HeldCount() == 0;
    }
}

// The shared add-food row, reading "board busy" while the cutting station would refuse a press, re-texted on every board edge
// that changes it (a place, a release; a cut keeps the count above zero).
class UMars_SmTask_CuttingFeed_OperatorHints : UMars_SmTask_StationFeed_OperatorHints
{
    private FCk_Handle_FoodBoard _Board;

    // The board first: the row's first text reads it.
    protected void Register_Rows() override
    {
        _Board = _Station.As_FoodBoard();
        _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
        _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        Super::Register_Rows();
    }

    protected void Unregister_Rows() override
    {
        if (ck::IsValid(_Board))
        {
            _Board.UnbindFrom_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
            _Board.UnbindFrom_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        }

        Super::Unregister_Rows();
        _Board = FCk_Handle_FoodBoard();
    }

    protected TOptional<FString> TryGet_StationRefusal() const override
    {
        if (ck::Is_NOT_Valid(_Board) || _Board.Get_HeldCount() == 0)
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

// The operator's legend rows while operating: "move hand" (IA_Look), "chop" (IA_Interact_Primary), "to tray"
// (IA_Interact_Secondary) while a finished tray is docked, and "turn" (IA_Drop) while the board holds anything; the add-food
// row (sort order 6) is the feed's, between chop and to tray. The board's count is the station's world label, not a row: a
// legend row without an InputAction does not render.
class UMars_SmTask_Cutting_OperatorHints : UMars_SmTask_StationOperatorHints
{
    private const int32 k_MoveHandSortOrder = 4;
    private const int32 k_ChopSortOrder = 5;
    private const int32 k_SweepSortOrder = 9;
    private const int32 k_TurnSortOrder = 10;

    private FCk_Handle_PlatterDock _OutputDock;
    private FCk_Handle_FoodBoard _Board;
    // Registered while a finished tray is docked.
    private FCk_Handle_ActionHintRow _SweepRow;
    // Registered while the board holds anything.
    private FCk_Handle_ActionHintRow _TurnRow;

    protected FName Get_OwnerKey() const override
    {
        return n"Cutting";
    }

    protected void Register_Rows() override
    {
        Show_Row(FCk_Handle_ActionHintRow(), Make_Row(mars::Mars_IA_Look, "move hand", k_MoveHandSortOrder));
        Show_Row(FCk_Handle_ActionHintRow(), Make_Row(mars::Mars_IA_Interact_Primary, "chop", k_ChopSortOrder));

        _Board = _Station.As_FoodBoard(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Board))
        {
            _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnBoardPlaced"));
            _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
            Refresh_TurnRow();
        }

        _OutputDock = utils_platter_dock::Find_OnStation(_Station, EMars_PlatterDock_Role::Output);
        if (ck::Is_NOT_Valid(_OutputDock))
        { return; }

        _OutputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
        _OutputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));
        if (ck::IsValid(_OutputDock.Get_Platter()))
        { Show_Sweep(); }
    }

    protected void Unregister_Rows() override
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

        _OutputDock = FCk_Handle_PlatterDock();
        _Board = FCk_Handle_FoodBoard();
        _SweepRow = FCk_Handle_ActionHintRow();
        _TurnRow = FCk_Handle_ActionHintRow();
    }

    private void Show_Sweep()
    {
        if (ck::Is_NOT_Valid(_SweepRow))
        { _SweepRow = Show_Row(_SweepRow, Make_Row(mars::Mars_IA_Interact_Secondary, "to tray", k_SweepSortOrder)); }
    }

    // A cut keeps the count above zero, so placements and releases are the only edges.
    private void Refresh_TurnRow()
    {
        const auto HoldsAnything = _Board.Get_HeldCount() > 0;
        if (HoldsAnything && ck::Is_NOT_Valid(_TurnRow))
        {
            _TurnRow = Show_Row(_TurnRow, Make_Row(mars::Mars_IA_Drop, "turn", k_TurnSortOrder));
            return;
        }

        if (HoldsAnything == false)
        { _TurnRow = Clear_Row(_TurnRow); }
    }

    UFUNCTION()
    private void OnOutputDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Show_Sweep();
    }

    UFUNCTION()
    private void OnOutputUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        _SweepRow = Clear_Row(_SweepRow);
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
