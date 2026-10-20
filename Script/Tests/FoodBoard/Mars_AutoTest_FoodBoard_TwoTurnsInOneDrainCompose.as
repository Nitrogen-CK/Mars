// A turn is an offset, not a heading: two 90-degree turns requested in one step reach the board in one drain and compose
// into half a turn about the board's pile node. A box off the pile node ends yawed 180 degrees, at the pile node plus its
// old offset yawed 180 (within 0.05 cm and 0.1 degree); OnTurned fires twice, 90 each, both in the same frame (one drain;
// two drains would land the same pose a frame apart).
class UMars_AutoTest_FoodBoard_TwoTurnsInOneDrainCompose : UMars_AutoTestRig_FoodBoard
{
    private const float64 k_LocationToleranceCm = 0.05;
    private const float64 k_AngleToleranceDegrees = 0.1;
    private const float32 k_YawDegrees = 90.0f;

    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_FoodPiece _Box;
    private FTransform _Before;
    private FVector _Pivot;
    private TArray<float32> _Turns;
    // In parallel: the frame each OnTurned fired in.
    private TArray<int64> _TurnFrames;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, -25.0, 0.0), FVector(8000.0, 3000.0, -42000.0)), Make_Tuners());
        _Board.BindTo_OnTurned(FMars_Delegate_FoodBoard_OnTurned(this, n"OnTurned"));
        _Box = Build_BoxOn(_Board, FTransform(FRotator(0.0, 15.0, 0.0), FVector(6.0, -4.0, 0.0)), 1.0);
        Place(_Board, _Box);

        Add_Step_WaitUntil("the box is Ready and placed", n"Check_ReadyAndPlaced", 0, 0);
        Add_Step("turn the board twice in one step", n"Step_TurnTwice");
        Add_Step_WaitUntil("the board turned twice", n"Check_Turned", 0, 0);
        Add_Step_WaitFrames("the turned pose lands", 2);
        Add_Step("the box turned half a turn about the pile node", n"Step_AssertComposed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) == 1 && Get_HasReadied(_Box));
    }

    UFUNCTION()
    private void Step_TurnTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Before = Get_World(_Box);
        _Pivot = _Board.Get_PileNodeWorld().GetLocation();
        _Board.Request_Turn(FMars_Request_FoodBoard_Turn(k_YawDegrees));
        _Board.Request_Turn(FMars_Request_FoodBoard_Turn(k_YawDegrees));
    }

    UFUNCTION()
    private void Check_Turned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Turns.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Turns.Num(), 2, "OnTurned fired once per turn");
        if (_Turns.Num() == 2)
        {
            Assert_Equals_Float(_Turns[0], k_YawDegrees, 0.0001, "the first turn reported 90");
            Assert_Equals_Float(_Turns[1], k_YawDegrees, 0.0001, "the second turn reported 90");
            Assert_True(_TurnFrames[0] == _TurnFrames[1], f"both turns fired in one drain (frames {_TurnFrames[0]} and {_TurnFrames[1]})");
        }


        const auto Yaw = FQuat(FVector::UpVector, Math::DegreesToRadians(2.0 * float64(k_YawDegrees)));
        const auto After = Get_World(_Box);

        const auto Expected = _Pivot + Yaw.RotateVector(_Before.GetLocation() - _Pivot);
        Assert_True(After.GetLocation().Equals(Expected, k_LocationToleranceCm),
            f"the box sits at the pile node plus its offset yawed 180 ({After.GetLocation()} vs {Expected})");

        const auto ExpectedForward = Yaw.RotateVector(_Before.TransformVectorNoScale(FVector::ForwardVector));
        const auto Dot = Math::Clamp(After.TransformVectorNoScale(FVector::ForwardVector).DotProduct(ExpectedForward), -1.0, 1.0);
        const auto AngleDegrees = Math::RadiansToDegrees(Math::Acos(Dot));
        Assert_True(AngleDegrees <= k_AngleToleranceDegrees, f"the box is yawed 180 degrees ({AngleDegrees} degrees off)");
    }

    UFUNCTION()
    private void OnTurned(FCk_Handle_FoodBoard InBoard, float32 InYawDegrees)
    {
        _Turns.Add(InYawDegrees);
        _TurnFrames.Add(utils_time::Get_FrameNumber());
    }
}
