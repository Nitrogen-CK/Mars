// A box yawed on a yawed board, cut through its centre along the board's X: the halves take its place in Held (positive
// first), carry the board's membership with no cut pending, keep its rotation, sit SeparationCm apart along the cut normal
// (half each way from the source), and their masses sum to the source's. The board watches the halves too: a parallel cut
// 4.5 cm into the positive half (past every bounds corner of the negative half) replaces it in turn.
class UMars_AutoTest_FoodBoard_CutReplacesHeldAndSeparatesHalves : UMars_AutoTestRig_FoodBoard
{
    private float _MassKg = 1.6;
    private float32 _SeparationCm = 2.0f;

    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_FoodPiece _Source;
    private FTransform _SourceWorld;
    private FVector _SourceCentre;
    private FVector _Normal;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Tuners = Make_Tuners();
        Tuners.SeparationCm = _SeparationCm;
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(4400.0, 3000.0, -42000.0)), Tuners);
        _Source = Build_BoxOn(_Board, FTransform(FRotator(0.0, 30.0, 0.0), FVector(5.0, 3.0, 0.0)), _MassKg);
        Place(_Board, _Source);

        Add_Step_WaitUntil("the box is Ready and placed", n"Check_ReadyAndPlaced");
        Add_Step("cut the box through its centre along the board's X", n"Step_Cut");
        Add_Step_WaitUntil("the cut committed and the halves parted", n"Check_HalvesParted");
        Add_Step("the halves replace the source and part along the normal", n"Step_AssertHalves");
        Add_Step("cut the positive half 4.5 cm past the first plane", n"Step_Recut");
        Add_Step_WaitUntil("the second cut committed", n"Check_RecutCommitted");
        Add_Step("the positive half's halves replace it", n"Step_AssertRecut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) == 1 && Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SourceWorld = Get_World(_Source);
        _SourceCentre = Get_WorldBoundsCenter(_Source);
        _Normal = Get_BoardWorld(_Board).TransformVectorNoScale(FVector::ForwardVector);
        Chop(_Board, Make_WorldPlane(_SourceCentre, _Normal));
    }

    // A chop that issued nothing settles at once so the assertions report it.
    UFUNCTION()
    private void Check_HalvesParted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Issues = Get_Issues(_Board);
        if (Issues.Num() > 0 && Issues[0].Issued == 0)
        {
            Res.Set(true);
            return;
        }

        const auto PieceCuts = Get_PieceCuts(_Board);
        if (PieceCuts.Num() == 0)
        {
            Res.Set(false);
            return;
        }

        const auto Moved = (Get_World(PieceCuts[0].Positive).GetLocation() - _SourceWorld.GetLocation()).Size();
        Res.Set(Moved > 0.25 * _SeparationCm);
    }

    UFUNCTION()
    private void Step_AssertHalves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceCuts = Get_PieceCuts(_Board);
        Assert_Equals_Int(PieceCuts.Num(), 1, "one committed cut");
        if (PieceCuts.Num() != 1)
        { return; }

        const auto PieceCut = PieceCuts[0];
        const auto Positive = PieceCut.Positive;
        const auto Negative = PieceCut.Negative;
        Assert_True(PieceCut.Source == _Source, "the cut names the source");
        Assert_True(ck::Is_NOT_Valid(_Source), "the source is destroyed");

        const auto PieceResult = Get_FirstCut(EMars_FoodPiece_CutOutcome::Cut);
        Assert_True(PieceResult.Positive == Positive && PieceResult.Negative == Negative, "the board names the halves as the piece's cut did");

        TArray<FCk_Handle_FoodPiece> Expected;
        Expected.Add(Positive);
        Expected.Add(Negative);
        Assert_True(Get_IsSameOrder(_Board.Get_Held(), Expected), "the halves replace the source, positive first");

        Assert_True(Positive.TryGet_FoodBoard() == _Board && Negative.TryGet_FoodBoard() == _Board, "both halves carry the board");
        Assert_False(Positive.Get_HasBoardCutPending() || Negative.Get_HasBoardCutPending(), "neither half has a cut pending");

        const auto PositiveWorld = Get_World(Positive);
        const auto NegativeWorld = Get_World(Negative);
        const auto HalfSeparation = _Normal * (0.5 * float(_SeparationCm));
        Assert_True(PositiveWorld.GetLocation().Equals(_SourceWorld.GetLocation() + HalfSeparation, 0.01),
            f"the positive half moved half the separation along the normal ({PositiveWorld.GetLocation() - _SourceWorld.GetLocation()})");
        Assert_True(NegativeWorld.GetLocation().Equals(_SourceWorld.GetLocation() - HalfSeparation, 0.01),
            f"the negative half moved half the separation against the normal ({NegativeWorld.GetLocation() - _SourceWorld.GetLocation()})");
        Assert_Equals_Float((PositiveWorld.GetLocation() - NegativeWorld.GetLocation()).DotProduct(_Normal), _SeparationCm, 0.01,
            "the halves sit SeparationCm apart along the normal");
        Assert_True(PositiveWorld.GetRotation().Equals(_SourceWorld.GetRotation(), 0.0001)
            && NegativeWorld.GetRotation().Equals(_SourceWorld.GetRotation(), 0.0001), "the halves keep the source's rotation");

        Assert_True(Math::Abs(Positive.Get_MassKg() + Negative.Get_MassKg() - _MassKg) <= 0.000000001, "the halves' masses sum to the source's");
        Assert_False(_Board.Get_IsUntouched(), "a committed cut touches the board");
    }

    UFUNCTION()
    private void Step_Recut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Offset = 0.5 * float(_SeparationCm) + 4.5;
        Chop(_Board, Make_WorldPlane(_SourceCentre + _Normal * Offset, _Normal));
    }

    UFUNCTION()
    private void Check_RecutCommitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Issues = Get_Issues(_Board);
        Res.Set(Get_PieceCuts(_Board).Num() >= 2 || (Issues.Num() >= 2 && Issues[1].Issued == 0));
    }

    UFUNCTION()
    private void Step_AssertRecut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceCuts = Get_PieceCuts(_Board);
        Assert_Equals_Int(PieceCuts.Num(), 2, "two committed cuts");
        if (PieceCuts.Num() != 2)
        { return; }

        Assert_True(PieceCuts[1].Source == PieceCuts[0].Positive, "the second cut is the positive half's");

        TArray<FCk_Handle_FoodPiece> Expected;
        Expected.Add(PieceCuts[1].Positive);
        Expected.Add(PieceCuts[1].Negative);
        Expected.Add(PieceCuts[0].Negative);
        Assert_True(Get_IsSameOrder(_Board.Get_Held(), Expected), f"the positive half's halves take its place ({_Board.Get_HeldCount()} held)");
    }
}
