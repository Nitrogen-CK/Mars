// A Turn requested in the frame of a Cut waits for that cut: it turns the halves once the cut commits, never the source under
// the blade. A box on a yawed board is cut through its centre and turned 90 degrees about a pivot 10 cm off it, in one
// step. OnTurned fires once, after the cut committed, with the two halves held; each half's rotation is the source's yawed
// 90 degrees, and the halves' midpoint (the parting is symmetric about the source) is the source's location yawed about the
// pivot.
class UMars_AutoTest_FoodBoard_TurnWaitsForTheInFlightCut : UMars_AutoTestRig_FoodBoard
{
    private const float64 k_LocationToleranceCm = 0.05;
    private const float64 k_AngleToleranceDegrees = 0.1;
    private const float32 k_YawDegrees = 90.0f;

    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_FoodPiece _Source;
    private FTransform _SourceWorld;
    private FVector _Pivot;
    // What the board held as each Turn was applied.
    private TArray<FCk_Handle_FoodPiece> _HeldAtTurn;
    private int32 _Turns = 0;
    private int32 _PieceCutsAtTurn = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 30.0, 0.0), FVector(7600.0, 3000.0, -42000.0)), Make_Tuners());
        _Board.BindTo_OnTurned(FMars_Delegate_FoodBoard_OnTurned(this, n"OnTurned"));
        _Source = Build_BoxOn(_Board, FTransform(FRotator(0.0, 20.0, 0.0), FVector(2.0, -3.0, 0.0)), 1.2);
        Place(_Board, _Source);

        Add_Step_WaitUntil("the box is Ready and placed", n"Check_ReadyAndPlaced");
        Add_Step("cut the box through its centre and turn the board in the same step", n"Step_CutAndTurn");
        Add_Step_WaitUntil("the board turned", n"Check_Turned", 0, 3.0f);
        Add_Step_WaitFrames("the turned poses land", 2);
        Add_Step("the halves were turned, not the source", n"Step_AssertHalvesTurned");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) == 1 && Get_HasReadied(_Source));
    }

    UFUNCTION()
    private void Step_CutAndTurn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SourceWorld = Get_World(_Source);
        _Pivot = Get_BoardWorld(_Board).TransformPosition(FVector(10.0, 0.0, 0.0));

        const auto Normal = Get_BoardWorld(_Board).TransformVectorNoScale(FVector::ForwardVector);
        Chop(_Board, Make_WorldPlane(Get_WorldBoundsCenter(_Source), Normal));
        _Board.Request_Turn(FMars_Request_FoodBoard_Turn(FTransform(FRotator::ZeroRotator, _Pivot), k_YawDegrees));
    }

    UFUNCTION()
    private void Check_Turned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Turns > 0);
    }

    UFUNCTION()
    private void Step_AssertHalvesTurned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Turns, 1, "OnTurned fired once");
        Assert_Equals_Int(_PieceCutsAtTurn, 1, "the cut had committed when the board turned");
        Assert_Equals_Int(_HeldAtTurn.Num(), 2, "the board held the two halves when it turned");
        Assert_False(_HeldAtTurn.Contains(_Source), "the source was not held when the board turned");

        const auto PieceCuts = Get_PieceCuts(_Board);
        Assert_Equals_Int(PieceCuts.Num(), 1, "one committed cut");
        if (PieceCuts.Num() != 1)
        { return; }

        const auto Yaw = FQuat(FVector::UpVector, Math::DegreesToRadians(float64(k_YawDegrees)));
        const auto Positive = Get_World(PieceCuts[0].Positive);
        const auto Negative = Get_World(PieceCuts[0].Negative);

        const auto ExpectedForward = Yaw.RotateVector(_SourceWorld.TransformVectorNoScale(FVector::ForwardVector));
        const auto ExpectedUp = Yaw.RotateVector(_SourceWorld.TransformVectorNoScale(FVector::UpVector));
        Assert_True(Get_AngleDegrees(Positive.TransformVectorNoScale(FVector::ForwardVector), ExpectedForward) <= k_AngleToleranceDegrees
            && Get_AngleDegrees(Positive.TransformVectorNoScale(FVector::UpVector), ExpectedUp) <= k_AngleToleranceDegrees,
            "the positive half's rotation is the source's yawed 90 degrees");
        Assert_True(Get_AngleDegrees(Negative.TransformVectorNoScale(FVector::ForwardVector), ExpectedForward) <= k_AngleToleranceDegrees
            && Get_AngleDegrees(Negative.TransformVectorNoScale(FVector::UpVector), ExpectedUp) <= k_AngleToleranceDegrees,
            "the negative half's rotation is the source's yawed 90 degrees");

        const auto Midpoint = (Positive.GetLocation() + Negative.GetLocation()) * 0.5;
        const auto Expected = _Pivot + Yaw.RotateVector(_SourceWorld.GetLocation() - _Pivot);
        Assert_True(Midpoint.Equals(Expected, k_LocationToleranceCm),
            f"the halves' midpoint is the source's location yawed about the pivot ({Midpoint} vs {Expected})");
    }

    UFUNCTION()
    private void OnTurned(FCk_Handle_FoodBoard InBoard, float32 InYawDegrees)
    {
        ++_Turns;
        _HeldAtTurn = InBoard.Get_Held();
        _PieceCutsAtTurn = Get_PieceCuts(InBoard).Num();
    }

    private float64 Get_AngleDegrees(FVector InA, FVector InB) const
    {
        const auto Dot = Math::Clamp(InA.GetSafeNormal().DotProduct(InB.GetSafeNormal()), -1.0, 1.0);
        return Math::RadiansToDegrees(Math::Acos(Dot));
    }
}
