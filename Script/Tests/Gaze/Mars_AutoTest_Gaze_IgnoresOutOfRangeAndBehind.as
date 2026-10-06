// Three sensed targets the gaze must not look at: one just beyond RangeCm (its probe still overlaps the sense sphere),
// one inside MinRangeCm and one behind the eye node. The gaze stays on no target with a zero aim and OnTargetChanged
// never fires; moving the out-of-range target into range then makes it the target. Isolated Z band: -56000.
class UMars_AutoTest_Gaze_IgnoresOutOfRangeAndBehind : UMars_AutoTestRig_Gaze
{
    private FVector _Origin = FVector(0.0, 0.0, -56000.0);
    private FCk_Handle _BeyondRange;
    private FCk_Handle _InsideMinRange;
    private FCk_Handle _Behind;
    private int32 _TargetChangedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeNode = Make_EyeNode(InHandle, _Origin);

        auto Spec = MakeSpec();
        Spec.MinRangeCm = 50.0f;
        _Gaze = utils_gaze::Add(EyeNode, Spec);
        _Gaze.BindTo_OnTargetChanged(FMars_Delegate_Gaze_OnTargetChanged(this, n"OnTargetChanged"));

        // The 20 cm probe at 310 cm still reaches into the 300 cm sense sphere, so only the range check can reject it.
        _BeyondRange = MakeTarget(InHandle, _Origin + FVector(310.0, 0.0, 0.0));
        _InsideMinRange = MakeTarget(InHandle, _Origin + FVector(30.0, 0.0, 0.0));
        _Behind = MakeTarget(InHandle, _Origin + FVector(-150.0, 0.0, 0.0));

        Add_Step_WaitUntil("all three targets are sensed", n"Check_AllSensed");
        Add_Step_WaitSeconds("let the gaze evaluate them", 0.25);
        Add_Step("no target, zero aim, OnTargetChanged never fired", n"Step_AssertNoTarget");
        Add_Step("move the out-of-range target into range", n"Step_MoveIntoRange");
        Add_Step_WaitUntil("the gaze looks at it", n"Check_LooksAtMoved");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnTargetChanged(FCk_Handle_Gaze InGaze, FCk_Handle_Transform InPrevious, FCk_Handle_Transform InCurrent)
    {
        ++_TargetChangedCount;
    }

    UFUNCTION()
    private void Check_AllSensed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(DoGet_IsSensed(_BeyondRange) && DoGet_IsSensed(_InsideMinRange) && DoGet_IsSensed(_Behind));
    }

    UFUNCTION()
    private void Step_AssertNoTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Gaze.Get_HasTarget(), "Get_HasTarget() is false with only out-of-range, too-close and behind targets");
        Assert_Invalid(_Gaze.Get_Target(), "Get_Target() is none with only out-of-range, too-close and behind targets");

        const auto Aim = _Gaze.Get_AimYawPitchDeg();
        Assert_True(Aim.IsNearlyZero(), f"the aim is zero without a target (got [{Aim.ToString()}])");
        Assert_Equals_Int(_TargetChangedCount, 0, "OnTargetChanged never fired");
    }

    UFUNCTION()
    private void Step_MoveIntoRange(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_BeyondRange.As_Transform(), FCk_Request_Transform_SetLocation(_Origin + FVector(200.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Check_LooksAtMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == DoGet_Head(_BeyondRange) && _TargetChangedCount == 1);
    }
}
