// Place refuses, without deferring, a piece past MaxHeldPieces (Full), one the board already holds (AlreadyHeld, within the
// very drain that placed it), one another board holds (HeldElsewhere) and one destroyed before the drain (Gone). Accepted
// pieces are held in request order and stamped with their board; a placement onto an empty board leaves it untouched, one
// onto a board already holding a piece does not.
class UMars_AutoTest_FoodBoard_PlaceRefusesPastLimitDuplicateAndForeign : UMars_AutoTestRig_FoodBoard
{
    private FCk_Handle_FoodBoard _BoardA;
    private FCk_Handle_FoodBoard _BoardB;
    private FCk_Handle_FoodPiece _P1;
    private FCk_Handle_FoodPiece _P2;
    private FCk_Handle_FoodPiece _P3;
    private FCk_Handle_FoodPiece _P4;
    private FCk_Handle_FoodPiece _Doomed;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto TunersA = Make_Tuners();
        TunersA.MaxHeldPieces = 2;
        _BoardA = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(3000.0, 3000.0, -42000.0)), TunersA);
        _BoardB = Build_Board(InHandle, FTransform(FRotator(0.0, -35.0, 0.0), FVector(3200.0, 3000.0, -42000.0)), Make_Tuners());

        _P1 = Build_BoxOn(_BoardA, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 0.0)), 1.0);
        _P2 = Build_BoxOn(_BoardA, FTransform(FRotator::ZeroRotator, FVector(15.0, 0.0, 0.0)), 1.0);
        _P3 = Build_BoxOn(_BoardA, FTransform(FRotator::ZeroRotator, FVector(30.0, 0.0, 0.0)), 1.0);
        _P4 = Build_BoxOn(_BoardB, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 0.0)), 1.0);
        _Doomed = Build_BoxOn(_BoardB, FTransform(FRotator::ZeroRotator, FVector(15.0, 0.0, 0.0)), 1.0);

        Add_Step("place three pieces and the first again on a two-piece board", n"Step_PlaceOnA");
        Add_Step_WaitUntil("board A answered all four placements", n"Check_AnsweredA");
        Add_Step("place board A's second piece, a free piece and a destroyed piece on board B", n"Step_PlaceOnB");
        Add_Step_WaitUntil("board B answered all three placements", n"Check_AnsweredB");
        Add_Step("the refusals, the ledgers and the memberships", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PlaceOnA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Place(_BoardA, _P1);
        Place(_BoardA, _P2);
        Place(_BoardA, _P3);
        Place(_BoardA, _P1);
    }

    UFUNCTION()
    private void Check_AnsweredA(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_BoardA) + Get_Refusals(_BoardA).Num() >= 4);
    }

    UFUNCTION()
    private void Step_PlaceOnB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Place(_BoardB, _P2);
        Place(_BoardB, _P4);
        Place(_BoardB, _Doomed);
        utils_entity_lifetime::Request_DestroyEntity(_Doomed);
    }

    UFUNCTION()
    private void Check_AnsweredB(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_BoardB) + Get_Refusals(_BoardB).Num() >= 3);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_PlacedCount(_BoardA), 2, "board A placed two pieces");
        Assert_True(Get_IsSameOrder(_BoardA.Get_Held(), Pieces(_P1, _P2)), "board A holds the first two pieces, in request order");
        Assert_Equals_Int(_BoardA.Get_Occupancy(), 2, "board A is full");

        const auto RefusalsA = Get_Refusals(_BoardA);
        Assert_Equals_Int(RefusalsA.Num(), 2, "board A refused two placements");
        if (RefusalsA.Num() == 2)
        {
            Assert_True(RefusalsA[0].Piece == _P3 && RefusalsA[0].Refusal == EMars_FoodBoard_PlaceRefusal::Full,
                f"the third piece is refused Full (got {RefusalsA[0].Refusal :n})");
            Assert_True(RefusalsA[1].Piece == _P1 && RefusalsA[1].Refusal == EMars_FoodBoard_PlaceRefusal::AlreadyHeld,
                f"the first piece placed again is refused AlreadyHeld (got {RefusalsA[1].Refusal :n})");
        }

        Assert_Equals_Int(Get_PlacedCount(_BoardB), 1, "board B placed one piece");
        const auto HeldB = _BoardB.Get_Held();
        Assert_True(HeldB.Num() == 1 && HeldB[0] == _P4, "board B holds only its free piece");

        const auto RefusalsB = Get_Refusals(_BoardB);
        Assert_Equals_Int(RefusalsB.Num(), 2, "board B refused two placements");
        if (RefusalsB.Num() == 2)
        {
            Assert_True(RefusalsB[0].Piece == _P2 && RefusalsB[0].Refusal == EMars_FoodBoard_PlaceRefusal::HeldElsewhere,
                f"board A's piece is refused HeldElsewhere (got {RefusalsB[0].Refusal :n})");
            Assert_True(RefusalsB[1].Piece == _Doomed && RefusalsB[1].Refusal == EMars_FoodBoard_PlaceRefusal::Gone,
                f"the destroyed piece is refused Gone (got {RefusalsB[1].Refusal :n})");
        }

        Assert_True(_P1.TryGet_FoodBoard() == _BoardA && _P2.TryGet_FoodBoard() == _BoardA, "board A's pieces carry board A");
        Assert_True(_P4.TryGet_FoodBoard() == _BoardB, "board B's piece carries board B");
        Assert_True(ck::Is_NOT_Valid(_P3.TryGet_FoodBoard()), "the refused piece carries no board");

        Assert_False(_BoardA.Get_IsUntouched(), "a placement onto a board already holding a piece touches it");
        Assert_True(_BoardB.Get_IsUntouched(), "a placement onto an empty board leaves it untouched");
    }

    private TArray<FCk_Handle_FoodPiece> Pieces(FCk_Handle_FoodPiece InFirst, FCk_Handle_FoodPiece InSecond) const
    {
        TArray<FCk_Handle_FoodPiece> Result;
        Result.Add(InFirst);
        Result.Add(InSecond);
        return Result;
    }
}
