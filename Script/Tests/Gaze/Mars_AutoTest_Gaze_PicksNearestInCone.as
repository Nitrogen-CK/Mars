// With two targets in range and in the cone, the gaze looks at the nearer one's Head: A ahead-right-above (yaw and pitch
// positive). Once A is moved out of range it looks at B ahead-left-below (yaw and pitch negative). Isolated Z band:
// -55500.
class UMars_AutoTest_Gaze_PicksNearestInCone : UMars_AutoTestRig_Gaze
{
    private FVector _Origin = FVector(0.0, 0.0, -55500.0);
    private FCk_Handle _TargetA;
    private FCk_Handle _TargetB;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeNode = Make_EyeNode(InHandle, _Origin);
        _Gaze = utils_gaze::Add(EyeNode, MakeSpec());

        _TargetA = MakeTarget(InHandle, _Origin + FVector(150.0, 80.0, 60.0));
        _TargetB = MakeTarget(InHandle, _Origin + FVector(250.0, -80.0, -60.0));

        Add_Step_WaitUntil("both targets are sensed and the gaze looks at the nearer A", n"Check_LooksAtA");
        Add_Step("A is to the right and above", n"Step_AssertAimAtA");
        Add_Step("move A out of range", n"Step_MoveAAway");
        Add_Step_WaitUntil("the gaze looks at B", n"Check_LooksAtB");
        Add_Step("B is to the left and below", n"Step_AssertAimAtB");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_LooksAtA(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(DoGet_IsSensed(_TargetA) && DoGet_IsSensed(_TargetB) && _Gaze.Get_Target() == DoGet_Head(_TargetA));
    }

    UFUNCTION()
    private void Step_AssertAimAtA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gaze.Get_HasTarget(), "Get_HasTarget() is true while looking at A");

        const auto Aim = _Gaze.Get_AimYawPitchDeg();
        Assert_True(Aim.X > 0.0, f"yaw toward a target on the right is positive (got [{Aim.X}])");
        Assert_True(Aim.Y > 0.0, f"pitch toward a target above is positive (got [{Aim.Y}])");
        Assert_Equals_Float(Aim.X, Math::RadiansToDegrees(Math::Atan2(80.0, 150.0)), 0.1, "the yaw points at A");
        Assert_Equals_Float(Aim.Y, Math::RadiansToDegrees(Math::Atan2(60.0, Math::Sqrt(150.0 * 150.0 + 80.0 * 80.0))), 0.1, "the pitch points at A");
    }

    UFUNCTION()
    private void Step_MoveAAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_TargetA.As_Transform(), FCk_Request_Transform_SetLocation(_Origin + FVector(1000.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Check_LooksAtB(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == DoGet_Head(_TargetB));
    }

    UFUNCTION()
    private void Step_AssertAimAtB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Aim = _Gaze.Get_AimYawPitchDeg();
        Assert_True(Aim.X < 0.0, f"yaw toward a target on the left is negative (got [{Aim.X}])");
        Assert_True(Aim.Y < 0.0, f"pitch toward a target below is negative (got [{Aim.Y}])");
        Assert_Equals_Float(Aim.X, Math::RadiansToDegrees(Math::Atan2(-80.0, 250.0)), 0.1, "the yaw points at B");
        Assert_Equals_Float(Aim.Y, Math::RadiansToDegrees(Math::Atan2(-60.0, Math::Sqrt(250.0 * 250.0 + 80.0 * 80.0))), 0.1, "the pitch points at B");
    }
}
