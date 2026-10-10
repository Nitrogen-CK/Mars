// A release capped at two hands off the first two of three held boxes, in board order: each is still alive, has no body and
// no membership (the board no longer names it). The third stays held. An uncapped release after it hands the last box off
// too, still without a body.
class UMars_AutoTest_FoodBoard_HandoffReleaseLeavesNoBodyAndStopsAtMaxPieces : UMars_AutoTestRig_FoodBoard
{
    private const FVector k_Origin = FVector(12800.0, -16000.0, -30000.0);
    private const int32 k_HandoffCap = 2;

    private FCk_Handle_FoodBoard _Board;
    private TArray<FCk_Handle_FoodPiece> _Boxes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Board = Build_Board(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_Tuners());
        for (int32 Index = 0; Index < 3; ++Index)
        {
            const auto Box = Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(30.0 * Index, 0.0, 0.0)), 0.5);
            _Boxes.Add(Box);
            Place(_Board, Box);
        }

        Add_Step_WaitUntil("the three boxes are Ready and placed", n"Check_ReadyAndPlaced");
        Add_Step("hand off at most two", n"Step_Handoff");
        Add_Step_WaitUntil("two pieces were handed off", n"Check_HandedOff");
        Add_Step_WaitFrames("nothing else moves", 2);
        Add_Step("the first two left without bodies; the third stays held", n"Step_AssertHandoff");
        Add_Step("hand off the rest, uncapped", n"Step_HandoffRest");
        Add_Step_WaitUntil("the last box was handed off", n"Check_LastHandedOff");
        Add_Step("the last box left without a body; nothing is held", n"Step_AssertRest");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllReady = Get_PlacedCount(_Board) == _Boxes.Num();
        for (const auto& Box : _Boxes)
        { AllReady = AllReady && Get_HasReadied(Box); }

        auto Res = OutResult;
        Res.Set(AllReady);
    }

    UFUNCTION()
    private void Step_Handoff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Board = _Board;
        Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>(k_HandoffCap)));
    }

    UFUNCTION()
    private void Check_HandedOff(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_Board).Num() >= k_HandoffCap);
    }

    UFUNCTION()
    private void Step_AssertHandoff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<FCk_Handle_FoodPiece> Expected;
        Expected.Add(_Boxes[0]);
        Expected.Add(_Boxes[1]);
        Assert_True(Get_IsSameOrder(Get_ReleasedEvents(_Board), Expected), "OnReleased named the first two boxes, in board order");

        for (int32 Index = 0; Index < k_HandoffCap; ++Index)
        {
            const auto Box = _Boxes[Index];
            FCk_Handle Entity = Box;
            Assert_True(ck::IsValid(Box), f"handed-off box {Index} is alive");
            Assert_False(Entity.Is_JoltBody(), f"handed-off box {Index} has no body");
            Assert_False(Box.Has_Fragment(FMars_Fragment_FoodBoard_Membership), f"handed-off box {Index} has no board membership");
            Assert_True(ck::Is_NOT_Valid(Box.TryGet_FoodBoard()), f"handed-off box {Index} names no board");
        }

        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "one box is still held");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Boxes[2], "the third box is the one held");
    }

    UFUNCTION()
    private void Step_HandoffRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Board = _Board;
        Board.Request_Release(FMars_Request_FoodBoard_Release());
    }

    UFUNCTION()
    private void Check_LastHandedOff(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_Board).Num() >= 3);
    }

    UFUNCTION()
    private void Step_AssertRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "nothing is held");
        Assert_True(Get_ReleasedEvents(_Board).Num() == 3 && Get_ReleasedEvents(_Board)[2] == _Boxes[2], "OnReleased named the last box third");

        for (int32 Index = 0; Index < _Boxes.Num(); ++Index)
        {
            FCk_Handle HandedOff = _Boxes[Index];
            Assert_True(ck::IsValid(_Boxes[Index]), f"handed-off box {Index} is alive");
            Assert_False(HandedOff.Is_JoltBody(), f"handed-off box {Index} has no body");
            Assert_True(ck::Is_NOT_Valid(_Boxes[Index].TryGet_FoodBoard()), f"handed-off box {Index} names no board");
        }
    }
}
