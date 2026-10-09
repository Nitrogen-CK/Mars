// A Handoff release capped at two lets go of the first two of three held boxes, in board order: each is still alive, has no
// body and no membership, and is not in Released (the board no longer names it). The third stays held and the board is
// touched. A Loose release after it gives the last box its body and its Released entry, as a sweep always did.
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
        Add_Step("release the rest loose", n"Step_Loose");
        Add_Step_WaitUntil("the last box has a settled body", n"Check_LastBody");
        Add_Step("the last box was released loose, as before", n"Step_AssertLoose");
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
        Board.Request_Release(FMars_Request_FoodBoard_Release(EMars_FoodBoard_ReleaseMode::Handoff, TOptional<int32>(k_HandoffCap)));
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

        Assert_Equals_Int(_Board.Get_Released().Num(), 0, "a hand-off keeps nothing in Released");
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "one box is still held");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Boxes[2], "the third box is the one held");
        Assert_False(_Board.Get_IsUntouched(), "a hand-off touches the board");
    }

    UFUNCTION()
    private void Step_Loose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Board = _Board;
        Board.Request_Release(FMars_Request_FoodBoard_Release(EMars_FoodBoard_ReleaseMode::Loose, TOptional<int32>()));
    }

    // A body that failed settles at once so the assertions report it.
    UFUNCTION()
    private void Check_LastBody(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Boxes[2];
        const auto IsSettled = Entity.Is_JoltBody() && utils_jolt_body::Get_SetupState(Entity.As_JoltBody()) != ECk_JoltBody_SetupState::Pending;

        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_Board).Num() >= 3 && IsSettled);
    }

    UFUNCTION()
    private void Step_AssertLoose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Boxes[2];
        const auto Body = Entity.As_JoltBody();
        Assert_True(utils_jolt_body::Get_SetupState(Body) == ECk_JoltBody_SetupState::Ready, "the last box has a Ready body");
        Assert_True(utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Dynamic, "the last box's body is dynamic");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "nothing is held");
        Assert_True(_Board.Get_Released().Num() == 1 && _Board.Get_Released()[0] == _Boxes[2], "only the loose box is in Released");

        for (int32 Index = 0; Index < k_HandoffCap; ++Index)
        {
            FCk_Handle HandedOff = _Boxes[Index];
            Assert_False(HandedOff.Is_JoltBody(), f"handed-off box {Index} still has no body");
        }
    }
}
