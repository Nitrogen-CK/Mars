// Chop, turn, chop: the cross cut. A centre chop halves the meat joint; the turn yaws both halves a quarter turn about the
// pile, carrying the first cut's cap plane with them; a second centre chop then cuts both halves across it. The first cut's
// plane (as each board cut is submitted, its source's pending cut plane), carried in the positive half's frame through the
// turn, ends up orthogonal to the second cut's plane, and the four pieces lie one in each quadrant about their centre.
class UMars_AutoTest_CuttingStation_ACrossCutAfterATurnPartsAcrossTheFirstCut : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(16800.0, -19000.0, -30000.0);
    // The normals of two orthogonal planes: their dot is within this of zero.
    private const float64 k_OrthogonalTolerance = 0.02;

    // Every board cut's plane, in submission order.
    private TArray<FMars_FoodPiece_WorldPlane> _CutPlanes;
    // The first cut's normal in the positive half's frame, taken once that half exists.
    private FVector _FirstNormalInHalf;
    private FCk_Handle_FoodPiece _PositiveHalf;
    // The first cut's normal in the world once the turn carried the half (read before the second chop cuts the half).
    private FVector _FirstNormalTurned;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());

        Add_Steps_FeedTheJoint();
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", 0, 5.0f);
        Add_Step_WaitUntil("the cleaver is back up", n"Check_ChopDone", 0, 2.0f);
        Add_Step("carry the first cut's plane into the positive half's frame, then turn", n"Step_Turn");
        Add_Step_WaitUntil("the board turned", n"Check_Turned", 0, 2.0f);
        Add_Step_WaitFrames("the turned poses land", 2);
        Add_Step("read the turned first cut, then chop at the board's centre again", n"Step_ChopAcross");
        Add_Step_WaitUntil("both halves were cut and every piece is shown", n"Check_FourShown", 0, 5.0f);
        Add_Step("the second cut crosses the first", n"Step_AssertCrossed");
        Run_Steps(InHandle);
    }

    // The frame a chop's cuts are submitted: each cut source carries the board's plane until its cut resolves.
    protected void On_CutIssued(const FMars_FoodBoard_CutIssue& InIssue) override
    {
        for (const auto& Piece : _Board.Get_Held())
        {
            const auto& Membership = Piece.Get_Fragment(FMars_Fragment_FoodBoard_Membership);
            if (Membership.PendingCutPlane.IsSet())
            { _CutPlanes.Add(Membership.PendingCutPlane.GetValue()); }
        }
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop();
    }

    // A chop that issued nothing settles at once so the assertions report it.
    UFUNCTION()
    private void Check_TwoShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_Issues.Num() > 0 && _Issues[0].Issued == 0) || (_PieceCuts >= 1 && _Board.Get_HeldCount() == 2 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Step_Turn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CutPlanes.Num(), 1, "the first chop submitted one cut");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the board holds the two halves");
        if (_CutPlanes.Num() != 1 || _Board.Get_HeldCount() != 2)
        { return; }

        _PositiveHalf = _Board.Get_Held()[0];
        _FirstNormalInHalf = Get_World(_PositiveHalf).InverseTransformVectorNoScale(_CutPlanes[0].Normal);
        utils_cutting::Request_Turn(_Station);
    }

    UFUNCTION()
    private void Step_ChopAcross(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstNormalTurned = Get_World(_PositiveHalf).TransformVectorNoScale(_FirstNormalInHalf).GetSafeNormal();
        Chop();
    }

    UFUNCTION()
    private void Check_Turned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Turns.Num() > 0);
    }

    UFUNCTION()
    private void Check_FourShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Knocked = _Issues.Num() > 1 && _Issues[1].Issued < 2;
        Res.Set(Knocked || (_PieceCuts >= 3 && _Board.Get_HeldCount() == 4 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Step_AssertCrossed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Turns.Num(), 1, "the board turned once");
        Assert_True(_Issues.Num() == 2 && _Issues[1].Issued == 2, "the second chop cut both halves");
        Assert_Equals_Int(_CutPlanes.Num(), 3, "three board cuts were submitted");
        Assert_Equals_Int(_Board.Get_HeldCount(), 4, "four pieces are held");
        if (_CutPlanes.Num() != 3 || _Board.Get_HeldCount() != 4)
        { return; }

        // The first cut's cap plane, where the turn carried it, against the second chop's.
        for (int32 Index = 1; Index < 3; ++Index)
        {
            const auto Second = _CutPlanes[Index].Normal.GetSafeNormal();
            Assert_True(Math::Abs(_FirstNormalTurned.DotProduct(Second)) <= k_OrthogonalTolerance,
                f"the second chop's cut {Index} is orthogonal to the turned first cut ({_FirstNormalTurned} . {Second})");
        }

        const auto FirstNormal = _CutPlanes[0].Normal.GetSafeNormal();
        Assert_True(Math::Abs(FirstNormal.DotProduct(_CutPlanes[1].Normal.GetSafeNormal())) > 1.0 - k_OrthogonalTolerance,
            "the blade itself never turned: both chops cut along the same world plane");

        // One piece in each quadrant about the pieces' mean centroid, in the station's frame.
        const auto StationWorld = Get_StationWorld();
        const auto Held = _Board.Get_Held();
        auto Mean = FVector::ZeroVector;
        for (const auto& Piece : Held)
        { Mean += StationWorld.InverseTransformPosition(Get_WorldCentroid(Piece)); }

        Mean /= float64(Held.Num());

        TArray<int32> Quadrants;
        for (const auto& Piece : Held)
        {
            const auto Local = StationWorld.InverseTransformPosition(Get_WorldCentroid(Piece)) - Mean;
            const auto Quadrant = (Local.X >= 0.0 ? 1 : 0) + (Local.Y >= 0.0 ? 2 : 0);
            Assert_False(Quadrants.Contains(Quadrant), f"[{Piece.ToString()}] shares quadrant {Quadrant} with another piece");
            Quadrants.Add(Quadrant);
        }
    }
}
