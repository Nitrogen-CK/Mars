// The control's turn (what R issues) yaws the food on the board a quarter turn about the pile point: with the meat joint on
// the board, its world rotation is the old one yawed 90 degrees about the vertical, and its location is the pivot plus the
// old offset yawed the same (within 0.5 cm and 0.5 degree). OnTurned fires once, with 90.
class UMars_AutoTest_CuttingStation_TurnYawsTheBoardsPiecesAboutThePile : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(16800.0, -17000.0, -30000.0);
    private const float64 k_LocationToleranceCm = 0.5;
    private const float64 k_AngleToleranceDegrees = 0.5;

    private FCk_Handle_FoodPiece _Joint;
    private FTransform _Before;
    private FVector _Pivot;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());

        Add_Steps_FeedTheJoint();
        Add_Step("turn the food on the board", n"Step_Turn");
        Add_Step_WaitUntil("the board turned", n"Check_Turned", 0, 2.0f);
        Add_Step_WaitFrames("the turned pose lands", 2);
        Add_Step("the joint yawed 90 degrees about the pile point", n"Step_AssertTurned");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Turn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _Board.Get_Held()[0];
        _Before = Get_World(_Joint);
        _Pivot = utils_cutting::Get_PileCentreWorld(Get_StationWorld()).GetLocation();
        utils_cutting::Request_Turn(_Station);
    }

    UFUNCTION()
    private void Check_Turned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Turns.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertTurned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Turns.Num(), 1, "OnTurned fired once");
        if (_Turns.Num() > 0)
        { Assert_Equals_Float(_Turns[0], utils_cutting::k_TurnDegrees, 0.0001, "the turn is a quarter turn"); }

        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the board still holds the joint");

        const auto Yaw = FQuat(FVector::UpVector, Math::DegreesToRadians(float64(utils_cutting::k_TurnDegrees)));
        const auto After = Get_World(_Joint);

        const auto ExpectedLocation = _Pivot + Yaw.RotateVector(_Before.GetLocation() - _Pivot);
        Assert_True(After.GetLocation().Equals(ExpectedLocation, k_LocationToleranceCm),
            f"the joint sits at the pivot plus its yawed offset ({After.GetLocation()} vs {ExpectedLocation})");

        const auto ForwardError = Get_AngleDegrees(After.TransformVectorNoScale(FVector::ForwardVector),
            Yaw.RotateVector(_Before.TransformVectorNoScale(FVector::ForwardVector)));
        const auto UpError = Get_AngleDegrees(After.TransformVectorNoScale(FVector::UpVector),
            Yaw.RotateVector(_Before.TransformVectorNoScale(FVector::UpVector)));
        Assert_True(ForwardError <= k_AngleToleranceDegrees && UpError <= k_AngleToleranceDegrees,
            f"the joint's rotation is the old one yawed 90 degrees (forward off by {ForwardError}, up by {UpError})");
    }

    private float64 Get_AngleDegrees(FVector InA, FVector InB) const
    {
        const auto Dot = Math::Clamp(InA.GetSafeNormal().DotProduct(InB.GetSafeNormal()), -1.0, 1.0);
        return Math::RadiansToDegrees(Math::Acos(Dot));
    }
}
