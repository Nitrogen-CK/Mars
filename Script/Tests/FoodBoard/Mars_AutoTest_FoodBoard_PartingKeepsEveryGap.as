// Every committed cut parts the whole board along its plane, so earlier gaps keep their width. A box cut right of its middle
// and then left of it ends as three pieces SeparationCm apart (each half moving only away from its own cut closed the first
// gap back to half). One chop that cuts four boxes parts the board once even though its cuts commit over two frames
// (RuntimeMesh slices two per frame): a fifth box beyond them moves half a separation, and every cut box's gap is
// SeparationCm wide and centred on the blade (a box moved by an early parting before its own cut landed would be off it).
class UMars_AutoTest_FoodBoard_PartingKeepsEveryGap : UMars_AutoTestRig_FoodBoard
{
    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_FoodBoard _RowBoard;
    private FCk_Handle_FoodPiece _Beyond;
    private FTransform _BeyondStart;
    private float32 _SeparationCm = 1.0f;
    private int32 _RowBoxes = 4;
    private float64 _RowBladeX = 5.0;
    private int64 _FirstRowCutFrame = -1;
    private int64 _LastRowCutFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Tuners = Make_Tuners();
        Tuners.SeparationCm = _SeparationCm;

        _Board = Build_Board(InHandle, FTransform(FVector(4800.0, 3000.0, -42000.0)), Tuners);
        Place(_Board, Build_BoxOn(_Board, FTransform(), 1.0));

        // Room for five boxes and the four halves the chop adds; one chop may cut all four.
        auto RowTuners = Tuners;
        RowTuners.MaxHeldPieces = 12;
        RowTuners.MaxCutsPerChop = _RowBoxes;
        _RowBoard = Build_Board(InHandle, FTransform(FVector(4800.0, 3200.0, -42000.0)), RowTuners);
        _RowBoard.BindTo_OnPieceCut(FMars_Delegate_FoodBoard_OnPieceCut(this, n"OnRowPieceCut"));
        for (int32 Index = 0; Index < _RowBoxes; ++Index)
        { Place(_RowBoard, Build_BoxOn(_RowBoard, FTransform(FVector(0.0, 15.0 * Index, 0.0)), 1.0)); }

        _Beyond = Build_BoxOn(_RowBoard, FTransform(FVector(20.0, 0.0, 0.0)), 1.0);
        Place(_RowBoard, _Beyond);

        Add_Step_WaitUntil("every box is Ready and placed", n"Check_AllPlaced");
        Add_Step("cut the single box right of its middle", n"Step_CutRight");
        Add_Step_WaitUntil("the right cut committed", n"Check_OneCut");
        Add_Step_WaitFrames("the parting lands", 2);
        Add_Step("cut the left piece left of the middle", n"Step_CutLeft");
        Add_Step_WaitUntil("the left cut committed", n"Check_TwoCuts");
        Add_Step_WaitFrames("the parting lands", 2);
        Add_Step("three pieces, every gap SeparationCm", n"Step_AssertGaps");
        Add_Step("one chop across the row of boxes", n"Step_ChopRow");
        Add_Step_WaitUntil("every row cut committed", n"Check_RowCut");
        Add_Step_WaitFrames("the parting lands", 2);
        Add_Step("one parting: the box beyond moved half a separation, every gap on the blade", n"Step_AssertRow");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_AllPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) == 1 && Get_PlacedCount(_RowBoard) == _RowBoxes + 1 && Get_IsFreeAll(_Board) && Get_IsFreeAll(_RowBoard));
    }

    UFUNCTION()
    private void Step_CutRight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop(_Board, Make_BoardPlane(_Board, FVector(7.0, 5.0, 5.0), FVector::ForwardVector));
    }

    UFUNCTION()
    private void Check_OneCut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceCuts(_Board).Num() == 1);
    }

    // After the first cut the left piece spans about -0.5..6.5 in the board's X; a plane at 3 cuts only it.
    UFUNCTION()
    private void Step_CutLeft(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop(_Board, Make_BoardPlane(_Board, FVector(3.0, 5.0, 5.0), FVector::ForwardVector));
    }

    UFUNCTION()
    private void Check_TwoCuts(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceCuts(_Board).Num() == 2);
    }

    UFUNCTION()
    private void Step_AssertGaps(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Held = _Board.Get_Held();
        Assert_Equals_Int(Held.Num(), 3, "two cuts leave three pieces");
        if (Held.Num() != 3)
        { return; }

        // Each piece's span along the board's X, sorted by where it starts.
        TArray<FVector2D> Spans;
        for (const auto& Piece : Held)
        { Spans.Add(Get_SpanX(_Board, Piece)); }

        for (int32 Pass = 0; Pass < Spans.Num(); ++Pass)
        {
            for (int32 Index = 1; Index < Spans.Num(); ++Index)
            {
                if (Spans[Index].X < Spans[Index - 1].X)
                {
                    const auto Swap = Spans[Index];
                    Spans[Index] = Spans[Index - 1];
                    Spans[Index - 1] = Swap;
                }
            }
        }

        Assert_Equals_Float(Spans[1].X - Spans[0].Y, _SeparationCm, 0.01, f"the left gap is SeparationCm ({Spans[1].X - Spans[0].Y})");
        Assert_Equals_Float(Spans[2].X - Spans[1].Y, _SeparationCm, 0.01, f"the first (right) gap kept SeparationCm ({Spans[2].X - Spans[1].Y})");
    }

    UFUNCTION()
    private void Step_ChopRow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _BeyondStart = Get_World(_Beyond);
        Chop(_RowBoard, Make_BoardPlane(_RowBoard, FVector(_RowBladeX, 25.0, 5.0), FVector::ForwardVector));
    }

    UFUNCTION()
    private void Check_RowCut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceCuts(_RowBoard).Num() == _RowBoxes);
    }

    UFUNCTION()
    private void Step_AssertRow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Issues = Get_Issues(_RowBoard);
        Assert_True(Issues.Num() == 1 && Issues[0].Issued == _RowBoxes, f"one chop cut all {_RowBoxes} boxes");
        Assert_True(_LastRowCutFrame > _FirstRowCutFrame,
            f"the chop's cuts committed over more than one frame ({_FirstRowCutFrame}..{_LastRowCutFrame}), so the parting had to wait for the last");

        const auto Normal = Get_BoardWorld(_RowBoard).TransformVectorNoScale(FVector::ForwardVector);
        const auto Moved = (Get_World(_Beyond).GetLocation() - _BeyondStart.GetLocation()).DotProduct(Normal);
        Assert_Equals_Float(Moved, 0.5 * _SeparationCm, 0.01, f"the box beyond moved half a separation, once ({Moved})");

        for (const auto& PieceCut : Get_PieceCuts(_RowBoard))
        {
            const auto Negative = Get_SpanX(_RowBoard, PieceCut.Negative);
            const auto Positive = Get_SpanX(_RowBoard, PieceCut.Positive);
            const auto Gap = Positive.X - Negative.Y;
            const auto Middle = 0.5 * (Positive.X + Negative.Y);
            Assert_Equals_Float(Gap, _SeparationCm, 0.01, f"[{PieceCut.Source.ToString()}] its gap is SeparationCm ({Gap})");
            Assert_Equals_Float(Middle, _RowBladeX, 0.01, f"[{PieceCut.Source.ToString()}] its gap is centred on the blade ({Middle})");
        }
    }

    UFUNCTION()
    private void OnRowPieceCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative)
    {
        const auto Frame = utils_time::Get_FrameCounter();
        if (_FirstRowCutFrame < 0)
        { _FirstRowCutFrame = Frame; }

        _LastRowCutFrame = Frame;
    }

    // InPiece's span along InBoard's X, from its bounds at its current pose.
    private FVector2D Get_SpanX(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece) const
    {
        const auto PieceWorld = Get_World(InPiece);
        const auto Metrics = utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
        const auto Board = Get_BoardWorld(InBoard);
        const auto Min = Board.InverseTransformPosition(PieceWorld.TransformPosition(Metrics.Get_BoundsMinCm())).X;
        const auto Max = Board.InverseTransformPosition(PieceWorld.TransformPosition(Metrics.Get_BoundsMaxCm())).X;
        return FVector2D(Math::Min(Min, Max), Math::Max(Min, Max));
    }

    private bool Get_IsFreeAll(FCk_Handle_FoodBoard InBoard) const
    {
        for (const auto& Piece : InBoard.Get_Held())
        {
            if (Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
            { return false; }
        }

        return true;
    }
}
