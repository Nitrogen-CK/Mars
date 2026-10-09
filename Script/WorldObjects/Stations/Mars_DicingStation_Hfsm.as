// The dicing station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Dicing_Idle). It runs on the STATION entity (context = the station, which also carries the Dicing feature
// and, when the station has food, the FoodBoard) and reads the station's operator; it only issues Dicing and FoodBoard
// requests and registers the operator's legend rows.
//
//   Idle      ->Operated [StationIsOperated]      task: Dicing_ResetOnEnter (a fresh pile and joint for the next operator)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Dicing_OperatorInput (Tick), Dicing_CutBridge, Dicing_OperatorHints
//
// The conditions are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose,
// the camera (Captured: the view stays still, the look delta is ours), the glove grip and the Leave intent.

namespace utils_dicing
{
    // The blade as a cutting plane at contact: through the hand's lateral position, its normal along the hand's travel (the
    // station's local Y), its face along the board's depth. Read from the station root and Dicing's HandLateral rather than
    // the lateral node, which lags a nudge drained in the chop's own frame. Here, beside the control that captures it, so
    // the minigame kernel never learns about food.
    FMars_FoodPiece_WorldPlane Get_BladePlane(const FTransform& InStationWorld, float32 InHandLateral)
    {
        return FMars_FoodPiece_WorldPlane(
            InStationWorld.TransformPosition(FVector(0.0, float64(InHandLateral), 0.0)),
            InStationWorld.TransformVectorNoScale(FVector::RightVector),
            InStationWorld.TransformVectorNoScale(FVector::ForwardVector));
    }
}

class UMars_SmState_Dicing_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Dicing_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_Dicing_ResetOnEnter);
    }
}

class UMars_SmState_Dicing_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Dicing_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Dicing_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Dicing_CutBridge);
        AddTask(InHandle, UMars_SmTask_Dicing_OperatorHints);
    }
}

// A fresh pile, band and hand, and a fresh joint unless the board still holds the whole one nobody touched. A joint whose
// cut is in flight as the operator leaves counts as touched: its halves must not greet the next operator. No Dicing or
// board on the context yet (the SM can enter before the entity script composes them) = nothing to reset.
class UMars_SmTask_Dicing_ResetOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Station = ck::Ctx(InHandle);

        auto Dicing = Station.As_Dicing(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Dicing))
        { Dicing.Request_Reset(FMars_Request_Dicing_Reset()); }

        auto Board = Station.As_FoodBoard(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Board) && Get_NeedsFreshJoint(Board))
        { Board.Request_Clear(FMars_Request_FoodBoard_Clear()); }
    }

    private bool Get_NeedsFreshJoint(const FCk_Handle_FoodBoard& InBoard) const
    {
        if (InBoard.Get_IsUntouched() == false || InBoard.Get_HeldCount() == 0)
        { return true; }

        const auto Held = InBoard.Get_Held();
        for (const auto& Piece : Held)
        {
            if (Piece.Get_HasBoardCutPending())
            { return true; }
        }

        return false;
    }
}

// The operator's input, read off its InputIntents: one nudge per drained look delta (its horizontal component, degrees;
// positive = mouse right = the board's +Y, the operator's right), one chop per rising edge of Interact_Primary and one sweep
// (a board release) per rising edge of Interact_Secondary. All are seeded on enter, so a delta or a press from before the
// station was taken does not count. No operator intents (headless) = nothing to read; no board = no sweep.
class UMars_SmTask_Dicing_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Dicing _Dicing;
    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_InputIntents _Intents;
    private int32 _SeenLookSequence = 0;
    // The activation frame of the Interact_Primary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenChopFrame;
    // The same for Interact_Secondary.
    private TOptional<int32> _SeenSweepFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Dicing = StationEntity.As_Dicing();
        _Board = StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked);
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenLookSequence = _Intents.Get_LookDeltaSequence();
        _SeenChopFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        _SeenSweepFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Dicing) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto Sequence = _Intents.Get_LookDeltaSequence();
        if (Sequence != _SeenLookSequence)
        {
            _SeenLookSequence = Sequence;
            _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge(float32(_Intents.Get_LookDelta().X)));
        }

        const auto ChopFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        if (ChopFrame != _SeenChopFrame)
        {
            _SeenChopFrame = ChopFrame;
            if (ChopFrame.IsSet())
            { _Dicing.Request_Chop(FMars_Request_Dicing_Chop()); }
        }

        const auto SweepFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
        if (SweepFrame != _SeenSweepFrame)
        {
            _SeenSweepFrame = SweepFrame;
            if (SweepFrame.IsSet() && ck::IsValid(_Board))
            { _Board.Request_Release(FMars_Request_FoodBoard_Release()); }
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Dicing = FCk_Handle_Dicing();
        _Board = FCk_Handle_FoodBoard();
        _Intents = FCk_Handle_InputIntents();
        _SeenLookSequence = 0;
        _SeenChopFrame.Reset();
        _SeenSweepFrame.Reset();
    }
}

// Every chop the cleaver lands cuts the board along the blade, on the band or off it: the band scores the herbs, the board
// holds the food under the blade, and the cut never feeds the score. The binding lives exactly as long as the Operated state,
// so a chop that lands after the operator left cuts nothing. It needs no operator input, so a headless operator drives it
// too. No board on the context (a station without food) = nothing to cut.
class UMars_SmTask_Dicing_CutBridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_Transform _Root;
    private FCk_Handle_Dicing _Dicing;
    private FCk_Handle_FoodBoard _Board;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Board = StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked);
        _Dicing = StationEntity.As_Dicing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Board) || ck::Is_NOT_Valid(_Dicing))
        { return; }

        _Root = StationEntity.As_Transform();
        _Dicing.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Dicing))
        { _Dicing.UnbindFrom_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved")); }

        _Root = FCk_Handle_Transform();
        _Dicing = FCk_Handle_Dicing();
        _Board = FCk_Handle_FoodBoard();
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        const auto StationWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(utils_dicing::Get_BladePlane(StationWorld, InDicing.Get_HandLateral())));
    }
}

// The operator's legend rows while operating, under owner key k_OwnerKey: "move hand" (IA_Look), "chop"
// (IA_Interact_Primary) and, on a station with food, "sweep to tray" (IA_Interact_Secondary). The pile's state is the
// station's world label, not a row: a legend row without an InputAction does not render. An operator without a display
// (headless) gets no rows.
class UMars_SmTask_Dicing_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Dicing";
    private const int32 k_MoveHandSortOrder = 7;
    private const int32 k_ChopSortOrder = 8;
    private const int32 k_SweepSortOrder = 9;

    private FCk_Handle_ActionHintDisplay _Display;

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

        if (ck::IsValid(StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked)))
        { _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Secondary, FText::FromString("sweep to tray"), k_SweepSortOrder, k_OwnerKey)); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Display = FCk_Handle_ActionHintDisplay();
    }
}
