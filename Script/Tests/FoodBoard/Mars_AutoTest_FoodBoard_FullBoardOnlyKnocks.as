// A board of MaxHeldPieces 3 holding two boxes the plane crosses. Two chops in one frame: the first has room for one more
// piece and cuts only the nearer box; the second already counts that cut's second half and only knocks (budget 0). Once the
// cut commits the board is full, and a third chop over the same food knocks too: no cut is issued, nothing is cutting, and
// the uncut box is the same piece.
class UMars_AutoTest_FoodBoard_FullBoardOnlyKnocks : UMars_AutoTestRig_FoodBoard
{
    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_FoodPiece _Nearer;
    private FCk_Handle_FoodPiece _Farther;
    private FGuid _FartherId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Tuners = Make_Tuners();
        Tuners.MaxHeldPieces = 3;
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(4000.0, 3000.0, -42000.0)), Tuners);
        _Nearer = Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 0.0)), 1.0);
        _Farther = Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(14.0, 0.0, 0.0)), 1.0);
        Place(_Board, _Nearer);
        Place(_Board, _Farther);

        Add_Step_WaitUntil("both boxes are Ready and placed", n"Check_ReadyAndPlaced");
        Add_Step("chop twice in one frame", n"Step_ChopTwice");
        Add_Step_WaitUntil("the one cut with room committed", n"Check_FirstCutCommitted");
        Add_Step("chop the full board", n"Step_ChopFull");
        Add_Step_WaitUntil("the third chop was reported", n"Check_ThirdChopReported");
        Add_Step_WaitSeconds("a cut issued by a knock would commit in this window", 0.3f);
        Add_Step("a chop with no room only knocks", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) == 2 && Get_HasReadied(_Nearer) && Get_HasReadied(_Farther));
    }

    UFUNCTION()
    private void Step_ChopTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FartherId = _Farther.Get_Id();
        Chop(_Board, Get_Plane());
        Chop(_Board, Get_Plane());
    }

    // Two chops reported and no cut is coming (one committed, or none was issued) settles so the assertions report it.
    UFUNCTION()
    private void Check_FirstCutCommitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Issues = Get_Issues(_Board);
        Res.Set(Issues.Num() >= 2 && (Get_PieceCuts(_Board).Num() >= 1 || Issues[0].Issued == 0));
    }

    UFUNCTION()
    private void Step_ChopFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Board.Get_HeldCount(), 3, "the committed cut filled the board");
        Chop(_Board, Get_Plane());
    }

    UFUNCTION()
    private void Check_ThirdChopReported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Issues(_Board).Num() >= 3);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Issues = Get_Issues(_Board);
        Assert_Equals_Int(Issues.Num(), 3, "three chops reported");
        if (Issues.Num() != 3)
        { return; }

        Assert_Equals_Int(Issues[0].Straddling, 2, "the first chop straddles both boxes");
        Assert_Equals_Int(Issues[0].Budget, 1, "the first chop has room for one more piece");
        Assert_Equals_Int(Issues[0].Issued, 1, "the first chop cuts one box");

        Assert_Equals_Int(Issues[1].Straddling, 1, "the second chop finds only the box not already cutting");
        Assert_Equals_Int(Issues[1].Budget, 0, "the second chop counts the first cut's second half: no room");
        Assert_Equals_Int(Issues[1].Issued, 0, "the second chop only knocks");

        Assert_True(Issues[2].Straddling > 0, f"the third chop is over food ({Issues[2].Straddling} straddling)");
        Assert_Equals_Int(Issues[2].Budget, 0, "the full board has no room");
        Assert_Equals_Int(Issues[2].Issued, 0, "the third chop only knocks");

        const auto PieceCuts = Get_PieceCuts(_Board);
        Assert_Equals_Int(PieceCuts.Num(), 1, "exactly one committed cut");
        if (PieceCuts.Num() == 1)
        { Assert_True(PieceCuts[0].Source == _Nearer, "the cut was the nearer box's"); }

        Assert_Equals_Int(_Board.Get_HeldCount(), 3, "the board stays full");
        Assert_Equals_Int(_Board.Get_Occupancy(), 3, "no cut is in flight");
        Assert_True(ck::IsValid(_Farther) && _Farther.Get_Id() == _FartherId, "the uncut box is the same piece");
        for (const auto& Piece : _Board.Get_Held())
        {
            Assert_True(Piece.Get_Status() == EMars_FoodPiece_Status::Ready && Piece.Get_IsCutting() == false,
                f"held piece [{Piece.ToString()}] is Ready and not cutting");
        }
    }

    // x + y = 17 in the board's frame: through both boxes, nearer the first.
    private FMars_FoodPiece_WorldPlane Get_Plane() const
    {
        return Make_BoardPlane(_Board, FVector(8.0, 9.0, 5.0), FVector(1.0, 1.0, 0.0));
    }
}
