// One board under test: its three boxes, their Ids before the chop, and how many cuts its budget allows.
struct FMars_AutoTest_FoodBoard_BudgetCase
{
    FCk_Handle_FoodBoard Board;
    TArray<FCk_Handle_FoodPiece> Row;
    TArray<FGuid> RowIds;
    int32 ExpectedCuts = 0;
}

// Three boxes in a row along each board's X; the plane x + y = 17 (board frame) crosses the first two and misses the third,
// and its position is nearer the first. With MaxCutsPerChop 1 only the nearer box is cut; with 4 both are; the third is
// never touched. Each chop reports the two straddling pieces, its budget and the cuts it issued, and the halves take their
// sources' places in order.
class UMars_AutoTest_FoodBoard_CutTargetsOnlyStraddlingPiecesWithinBudget : UMars_AutoTestRig_FoodBoard
{
    private FMars_AutoTest_FoodBoard_BudgetCase _One;
    private FMars_AutoTest_FoodBoard_BudgetCase _Four;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto TunersOne = Make_Tuners();
        TunersOne.MaxCutsPerChop = 1;
        _One.Board = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(3600.0, 3000.0, -42000.0)), TunersOne);
        _One.Row = Build_Row(_One.Board);
        _One.ExpectedCuts = 1;

        _Four.Board = Build_Board(InHandle, FTransform(FRotator(0.0, -120.0, 0.0), FVector(3600.0, 3400.0, -42000.0)), Make_Tuners());
        _Four.Row = Build_Row(_Four.Board);
        _Four.ExpectedCuts = 2;

        Add_Step_WaitUntil("all six boxes are Ready and placed", n"Check_ReadyAndPlaced");
        Add_Step("chop both boards along the same board-frame plane", n"Step_Chop");
        Add_Step_WaitUntil("each board committed the cuts its budget allows", n"Check_CutsCommitted");
        Add_Step_WaitSeconds("a cut beyond the budget would commit in this window", 0.3f);
        Add_Step("only straddling pieces were cut, nearest first, within budget", n"Step_Assert");
        Run_Steps(InHandle);
    }

    private TArray<FCk_Handle_FoodPiece> Build_Row(FCk_Handle_FoodBoard InBoard)
    {
        TArray<FCk_Handle_FoodPiece> Row;
        for (int32 Index = 0; Index < 3; ++Index)
        {
            const auto Piece = Build_BoxOn(InBoard, FTransform(FRotator::ZeroRotator, FVector(14.0 * Index, 0.0, 0.0)), 1.0);
            Place(InBoard, Piece);
            Row.Add(Piece);
        }

        return Row;
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsReadyAndPlaced(_One) && Get_IsReadyAndPlaced(_Four));
    }

    private bool Get_IsReadyAndPlaced(const FMars_AutoTest_FoodBoard_BudgetCase& InCase) const
    {
        if (Get_PlacedCount(InCase.Board) < InCase.Row.Num())
        { return false; }

        for (const auto& Piece : InCase.Row)
        {
            if (Get_HasReadied(Piece) == false)
            { return false; }
        }

        return true;
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Record_Ids(_One);
        Record_Ids(_Four);

        const auto Position = FVector(8.0, 9.0, 5.0);
        const auto Normal = FVector(1.0, 1.0, 0.0);
        Chop(_One.Board, Make_BoardPlane(_One.Board, Position, Normal));
        Chop(_Four.Board, Make_BoardPlane(_Four.Board, Position, Normal));
    }

    private void Record_Ids(FMars_AutoTest_FoodBoard_BudgetCase& InOutCase)
    {
        InOutCase.RowIds.Empty();
        for (const auto& Piece : InOutCase.Row)
        { InOutCase.RowIds.Add(Piece.Get_Id()); }
    }

    // A chop that issued an unexpected number of cuts settles at once so the assertions report it.
    UFUNCTION()
    private void Check_CutsCommitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSettled(_One) && Get_IsSettled(_Four));
    }

    private bool Get_IsSettled(const FMars_AutoTest_FoodBoard_BudgetCase& InCase) const
    {
        const auto Issues = Get_Issues(InCase.Board);
        if (Issues.Num() == 0)
        { return false; }

        if (Issues[0].Issued != InCase.ExpectedCuts)
        { return true; }

        return Get_PieceCuts(InCase.Board).Num() >= InCase.ExpectedCuts;
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Case(_One);
        Assert_Case(_Four);
    }

    private void Assert_Case(const FMars_AutoTest_FoodBoard_BudgetCase& InCase)
    {
        auto Board = InCase.Board;
        const auto MaxCuts = Board.Get_Tuners().MaxCutsPerChop;
        const auto Label = f"[MaxCutsPerChop {MaxCuts}]";

        const auto Issues = Get_Issues(Board);
        Assert_Equals_Int(Issues.Num(), 1, f"{Label} one chop reported");
        if (Issues.Num() != 1)
        { return; }

        Assert_Equals_Int(Issues[0].Straddling, 2, f"{Label} the plane straddles the first two boxes");
        Assert_Equals_Int(Issues[0].Budget, MaxCuts, f"{Label} the budget is MaxCutsPerChop (the board has room)");
        Assert_Equals_Int(Issues[0].Issued, InCase.ExpectedCuts, f"{Label} cuts issued");

        const auto PieceCuts = Get_PieceCuts(Board);
        Assert_Equals_Int(PieceCuts.Num(), InCase.ExpectedCuts, f"{Label} committed cuts");
        if (PieceCuts.Num() != InCase.ExpectedCuts)
        { return; }

        const auto Nearer = InCase.Row[0];
        const auto Farther = InCase.Row[1];
        const auto Missed = InCase.Row[2];
        Assert_True(Get_WasCut(Board, Nearer), f"{Label} the nearer box was cut");
        Assert_False(Get_WasCut(Board, Missed), f"{Label} the box the plane misses was not cut");
        Assert_True(ck::IsValid(Missed) && Missed.Get_Id() == InCase.RowIds[2], f"{Label} the missed box is the same piece");
        Assert_True(Missed.Get_Status() == EMars_FoodPiece_Status::Ready && Missed.Get_IsCutting() == false
            && Missed.Get_HasBoardCutPending() == false, f"{Label} the missed box is Ready and idle");

        TArray<FCk_Handle_FoodPiece> Expected;
        Add_Halves(Expected, Get_CutOf(PieceCuts, Nearer));
        if (InCase.ExpectedCuts == 2)
        {
            Assert_True(Get_WasCut(Board, Farther), f"{Label} the farther straddling box was cut too");
            Add_Halves(Expected, Get_CutOf(PieceCuts, Farther));
        }
        else
        {
            Assert_False(Get_WasCut(Board, Farther), f"{Label} the farther straddling box was past the budget");
            Assert_True(ck::IsValid(Farther) && Farther.Get_Id() == InCase.RowIds[1] && Farther.Get_HasBoardCutPending() == false,
                f"{Label} the farther box is the same piece, with no cut pending");
            Expected.Add(Farther);
        }

        Expected.Add(Missed);
        Assert_True(Get_IsSameOrder(Board.Get_Held(), Expected), f"{Label} the halves hold their sources' places, positive first ({Board.Get_HeldCount()} held)");
        Assert_False(Board.Get_IsUntouched(), f"{Label} a committed cut touches the board");
    }

    private void Add_Halves(TArray<FCk_Handle_FoodPiece>& InOutPieces, const FMars_AutoTest_FoodBoard_PieceCut& InPieceCut)
    {
        InOutPieces.Add(InPieceCut.Positive);
        InOutPieces.Add(InPieceCut.Negative);
    }

    private FMars_AutoTest_FoodBoard_PieceCut Get_CutOf(TArray<FMars_AutoTest_FoodBoard_PieceCut> InPieceCuts, FCk_Handle_FoodPiece InSource) const
    {
        for (const auto& PieceCut : InPieceCuts)
        {
            if (PieceCut.Source == InSource)
            { return PieceCut; }
        }

        return FMars_AutoTest_FoodBoard_PieceCut();
    }
}
