// The board's cuts, turns and releases apply in the order they arrived, blocked at the queue's head. A box on the board is
// chopped through its centre, turned 90 degrees and chopped again across it, all in one step: the first chop's cut is in
// flight, so the turn waits for it, and the second chop, queued after the turn, waits behind it. The board answers the
// first chop, then turns, then answers the second chop: OnCutIssued, OnTurned, OnCutIssued, in that order.
class UMars_AutoTest_FoodBoard_AChopAfterAWaitingTurnWaitsForIt : UMars_AutoTestRig_FoodBoard
{
    private const float32 k_YawDegrees = 90.0f;

    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_FoodPiece _Source;
    // One entry per answer, in the order the board gave them: "cut" or "turn".
    private TArray<FString> _Answers;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 20.0, 0.0), FVector(7800.0, 3000.0, -42000.0)), Make_Tuners());
        _Board.BindTo_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnCutIssued"));
        _Board.BindTo_OnTurned(FMars_Delegate_FoodBoard_OnTurned(this, n"OnTurned"));
        _Source = Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(3.0, 2.0, 0.0)), 1.0);
        Place(_Board, _Source);

        Add_Step_WaitUntil("the box is Ready and placed", n"Check_ReadyAndPlaced", 0, 0);
        Add_Step("chop, turn and chop again in one step", n"Step_ChopTurnChop");
        Add_Step_WaitUntil("the board answered both chops and the turn, and nothing is in flight", n"Check_AllAnswered", 0, 0);
        Add_Step("the second chop waited for the turn", n"Step_AssertOrder");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) == 1 && Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_ChopTurnChop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Centre = Get_WorldBoundsCenter(_Source);
        Chop(_Board, Make_WorldPlane(Centre, Get_BoardWorld(_Board).TransformVectorNoScale(FVector::ForwardVector)));
        _Board.Request_Turn(FMars_Request_FoodBoard_Turn(k_YawDegrees));
        Chop(_Board, Make_WorldPlane(Centre, Get_BoardWorld(_Board).TransformVectorNoScale(FVector::RightVector)));
    }

    UFUNCTION()
    private void Check_AllAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto IsQuiet = true;
        for (const auto& Piece : _Board.Get_Held())
        { IsQuiet = IsQuiet && Piece.Get_HasBoardCutPending() == false; }

        auto Res = OutResult;
        Res.Set(_Answers.Num() >= 3 && IsQuiet);
    }

    UFUNCTION()
    private void Step_AssertOrder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Answers.Num(), 3, "two chops and one turn answered");
        if (_Answers.Num() != 3)
        { return; }

        Assert_True(_Answers[0] == "cut", f"the first chop was answered first (got {_Answers[0]})");
        Assert_True(_Answers[1] == "turn", f"the turn went before the chop queued behind it (got {_Answers[1]})");
        Assert_True(_Answers[2] == "cut", f"the second chop was answered last (got {_Answers[2]})");
        Assert_True(Get_WasCut(_Board, _Source), "the first chop cut the box");
    }

    UFUNCTION()
    private void OnCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue)
    {
        _Answers.Add("cut");
    }

    UFUNCTION()
    private void OnTurned(FCk_Handle_FoodBoard InBoard, float32 InYawDegrees)
    {
        _Answers.Add("turn");
    }
}
