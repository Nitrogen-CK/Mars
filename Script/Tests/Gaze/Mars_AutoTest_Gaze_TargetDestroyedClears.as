// Destroying the owner the gaze looks at returns the gaze to no target: OnTargetChanged fires from that Head to nothing,
// Get_HasTarget() is false and the aim is zero, with no invalid-handle error on the way (any error fails the test).
// Isolated Z band: -58000.
class UMars_AutoTest_Gaze_TargetDestroyedClears : UMars_AutoTestRig_Gaze
{
    private FVector _Origin = FVector(0.0, 0.0, -58000.0);
    private FCk_Handle _Target;
    private FCk_Handle_Transform _TargetHead;
    private int32 _TargetChangedCount = 0;
    private FCk_Handle_Transform _LastPrevious;
    private FCk_Handle_Transform _LastCurrent;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto EyeNode = Make_EyeNode(InHandle, _Origin);
        _Gaze = utils_gaze::Add(EyeNode, MakeSpec());
        _Gaze.BindTo_OnTargetChanged(FMars_Delegate_Gaze_OnTargetChanged(this, n"OnTargetChanged"));

        _Target = MakeTarget(InHandle, _Origin + FVector(200.0, 0.0, 0.0));
        _TargetHead = DoGet_Head(_Target);

        Add_Step_WaitUntil("the gaze looks at the target", n"Check_LooksAtTarget");
        Add_Step("destroy the target's owner", n"Step_DestroyTarget");
        Add_Step_WaitUntil("OnTargetChanged fired from the target's Head to nothing", n"Check_Cleared");
        Add_Step("no target and a zero aim", n"Step_AssertCleared");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnTargetChanged(FCk_Handle_Gaze InGaze, FCk_Handle_Transform InPrevious, FCk_Handle_Transform InCurrent)
    {
        ++_TargetChangedCount;
        _LastPrevious = InPrevious;
        _LastCurrent = InCurrent;
    }

    UFUNCTION()
    private void Check_LooksAtTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gaze.Get_Target() == _TargetHead && _TargetChangedCount == 1);
    }

    UFUNCTION()
    private void Step_DestroyTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Target);
    }

    UFUNCTION()
    private void Check_Cleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TargetChangedCount == 2);
    }

    UFUNCTION()
    private void Step_AssertCleared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LastPrevious == _TargetHead, "the clearing OnTargetChanged comes from the destroyed target's Head");
        Assert_Invalid(_LastCurrent, "the clearing OnTargetChanged goes to no target");
        Assert_False(_Gaze.Get_HasTarget(), "Get_HasTarget() is false after the target's owner is destroyed");
        Assert_Invalid(_Gaze.Get_Target(), "Get_Target() is none after the target's owner is destroyed");

        const auto Aim = _Gaze.Get_AimYawPitchDeg();
        Assert_True(Aim.IsNearlyZero(), f"the aim is zero without a target (got [{Aim.ToString()}])");
    }
}
