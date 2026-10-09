// Two boxes are placed and released, two more placed. Clear destroys the two held pieces and only those: the released two
// live on, still in Released; Held is empty, the board is untouched, OnCleared fires once. A Clear of the now empty board
// broadcasts OnCleared again.
class UMars_AutoTest_FoodBoard_ClearDestroysHeldKeepsReleased : UMars_AutoTestRig_FoodBoard
{
    private FCk_Handle_FoodBoard _Board;
    private TArray<FCk_Handle_FoodPiece> _Loose;
    private TArray<FCk_Handle_FoodPiece> _Held;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(5600.0, 3000.0, -42000.0)), Make_Tuners());
        for (int32 Index = 0; Index < 4; ++Index)
        {
            const auto Piece = Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(15.0 * Index, 0.0, 0.0)), 0.5);
            if (Index < 2)
            {
                _Loose.Add(Piece);
                Place(_Board, Piece);
            }
            else
            { _Held.Add(Piece); }
        }

        Add_Step_WaitUntil("the first two boxes are Ready and placed", n"Check_FirstPlaced");
        Add_Step("release them", n"Step_Release");
        Add_Step_WaitUntil("both are released", n"Check_Released");
        Add_Step("place the other two", n"Step_PlaceRest");
        Add_Step_WaitUntil("the other two are placed", n"Check_RestPlaced");
        Add_Step("clear the board", n"Step_Clear");
        Add_Step_WaitUntil("the board cleared and its held pieces are destroyed", n"Check_Cleared");
        Add_Step("the released pieces survived; clear the empty board", n"Step_AssertAndClearAgain");
        Add_Step_WaitUntil("the empty board cleared", n"Check_ClearedAgain");
        Add_Step("an empty board's clear is announced too", n"Step_AssertClearedAgain");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_FirstPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) == 2 && Get_HasReadied(_Loose[0]) && Get_HasReadied(_Loose[1]));
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Board = _Board;
        Board.Request_Release(FMars_Request_FoodBoard_Release());
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_Board).Num() >= 2);
    }

    UFUNCTION()
    private void Step_PlaceRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _Held)
        { Place(_Board, Piece); }
    }

    UFUNCTION()
    private void Check_RestPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) >= 4);
    }

    UFUNCTION()
    private void Step_Clear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "two pieces are held before the clear");
        auto Board = _Board;
        Board.Request_Clear(FMars_Request_FoodBoard_Clear());
    }

    UFUNCTION()
    private void Check_Cleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ClearedCount(_Board) >= 1 && ck::Is_NOT_Valid(_Held[0]) && ck::Is_NOT_Valid(_Held[1]));
    }

    UFUNCTION()
    private void Step_AssertAndClearAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_ClearedCount(_Board), 1, "OnCleared fired once");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "nothing is held");
        Assert_True(_Board.Get_IsUntouched(), "a cleared board is untouched");
        Assert_True(ck::IsValid(_Loose[0]) && ck::IsValid(_Loose[1]), "the released pieces survived the clear");
        Assert_True(Get_IsSameOrder(_Board.Get_Released(), _Loose), "the released pieces are still the board's released ring");

        auto Board = _Board;
        Board.Request_Clear(FMars_Request_FoodBoard_Clear());
    }

    UFUNCTION()
    private void Check_ClearedAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ClearedCount(_Board) >= 2);
    }

    UFUNCTION()
    private void Step_AssertClearedAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_ClearedCount(_Board), 2, "the empty board's clear was announced");
        Assert_True(ck::IsValid(_Loose[0]) && ck::IsValid(_Loose[1]), "the released pieces survived the second clear");
        Assert_True(_Board.Get_IsUntouched(), "the board is still untouched");
    }
}
