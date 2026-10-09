// The board turns every world plane into the piece's own frame (utils_foodpiece::Get_LocalPlane). A yawed, pitched and rolled
// box on a yawed board: a world plane through its world centre, with a normal along none of its axes, halves it (500 cm3 and
// half the mass each); a world plane across its own world X axis, 2.5 cm past the centre, leaves 250 cm3 on the positive
// side, which holds only if both the position and the normal reached the piece's frame.
class UMars_AutoTest_FoodBoard_RotatedPieceCutsThroughItsCentre : UMars_AutoTestRig_FoodBoard
{
    private float _MassKg = 2.0;

    private FCk_Handle_FoodBoard _CentreBoard;
    private FCk_Handle_FoodBoard _OffsetBoard;
    private FCk_Handle_FoodPiece _CentrePiece;
    private FCk_Handle_FoodPiece _OffsetPiece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto PieceLocal = FTransform(FRotator(35.0, 50.0, 20.0), FVector(4.0, -6.0, 3.0));

        _CentreBoard = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(4800.0, 3000.0, -42000.0)), Make_Tuners());
        _CentrePiece = Build_BoxOn(_CentreBoard, PieceLocal, _MassKg);
        Place(_CentreBoard, _CentrePiece);

        _OffsetBoard = Build_Board(InHandle, FTransform(FRotator(0.0, -70.0, 0.0), FVector(4800.0, 3400.0, -42000.0)), Make_Tuners());
        _OffsetPiece = Build_BoxOn(_OffsetBoard, PieceLocal, _MassKg);
        Place(_OffsetBoard, _OffsetPiece);

        Add_Step_WaitUntil("both boxes are Ready and placed", n"Check_ReadyAndPlaced");
        Add_Step("cut one box through its world centre and the other across its own X", n"Step_Cut");
        Add_Step_WaitUntil("both cuts committed", n"Check_CutsCommitted");
        Add_Step("the halves have the volumes the piece-frame planes give", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_CentreBoard) == 1 && Get_PlacedCount(_OffsetBoard) == 1
            && Get_HasReadied(_CentrePiece) && Get_HasReadied(_OffsetPiece));
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop(_CentreBoard, Make_WorldPlane(Get_WorldBoundsCenter(_CentrePiece), FVector(0.3, -0.8, 0.52)));

        const auto OffsetWorld = Get_World(_OffsetPiece);
        const auto PieceX = OffsetWorld.TransformVectorNoScale(FVector::ForwardVector);
        Chop(_OffsetBoard, Make_WorldPlane(OffsetWorld.TransformPosition(FVector(7.5, 5.0, 5.0)), PieceX));
    }

    // A chop that issued nothing settles at once so the assertions report it.
    UFUNCTION()
    private void Check_CutsCommitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSettled(_CentreBoard) && Get_IsSettled(_OffsetBoard));
    }

    private bool Get_IsSettled(FCk_Handle_FoodBoard InBoard) const
    {
        const auto Issues = Get_Issues(InBoard);
        if (Issues.Num() > 0 && Issues[0].Issued == 0)
        { return true; }

        return Get_PieceCuts(InBoard).Num() >= 1;
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto CentreCuts = Get_PieceCuts(_CentreBoard);
        Assert_Equals_Int(CentreCuts.Num(), 1, "the box cut through its centre committed");
        if (CentreCuts.Num() == 1)
        {
            const auto Positive = CentreCuts[0].Positive;
            const auto Negative = CentreCuts[0].Negative;
            Assert_Equals_Float(Positive.Get_VolumeCm3(), 500.0, 0.05, "the centre cut's positive half is 500 cm3");
            Assert_Equals_Float(Negative.Get_VolumeCm3(), 500.0, 0.05, "the centre cut's negative half is 500 cm3");
            Assert_Equals_Float(Positive.Get_MassKg(), 0.5 * _MassKg, 0.0001, "the centre cut's positive half has half the mass");
            Assert_True(Math::Abs(Positive.Get_MassKg() + Negative.Get_MassKg() - _MassKg) <= 0.000000001, "the centre cut's halves sum to the whole");
        }

        const auto OffsetCuts = Get_PieceCuts(_OffsetBoard);
        Assert_Equals_Int(OffsetCuts.Num(), 1, "the box cut across its own X committed");
        if (OffsetCuts.Num() == 1)
        {
            const auto Positive = OffsetCuts[0].Positive;
            const auto Negative = OffsetCuts[0].Negative;
            Assert_Equals_Float(Positive.Get_VolumeCm3(), 250.0, 0.05, "the offset cut leaves 250 cm3 past the plane");
            Assert_Equals_Float(Negative.Get_VolumeCm3(), 750.0, 0.05, "the offset cut leaves 750 cm3 behind it");
            Assert_Equals_Float(Positive.Get_MassKg(), 0.25 * _MassKg, 0.0001, "the offset cut's positive half has a quarter of the mass");
        }
    }
}
