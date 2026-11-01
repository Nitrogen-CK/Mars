// A hostile target stands 380 uu ahead: the mimic wakes and chases it. Once it has walked 100 uu from home the target
// leaves (to 3000 uu, past HomeRadius and LoseRadius): the mimic loses it, goes Return, walks back to within HomeTolerance
// of home, goes Disguised and sits back down (tucked, lid shut).
class UMars_AutoTest_PickleMimic_ReturnsHomeAndSitsBackDown : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-170000.0, 110000.0, 600.0);

    private bool _SawReturn = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMimic(InHandle, FMars_PickleMimic_Spec());
        SpawnTarget(InHandle, FVector(380.0, 0.0, 0.0));

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("it walked 100 uu from home after the target", n"Check_LeftHome", 0, 8.0f);
        Add_Step("the target leaves", n"Step_TargetLeaves");
        Add_Step_WaitUntil("it is home and sat down", n"Check_SatDown", 0, 12.0f);
        Add_Step("it went home and back into its disguise", n"Step_AssertHome");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_LeftHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Away = _Mimic.Get_Location() - _Mimic.Get_Home();
        Res.Set(FVector(Away.X, Away.Y, 0.0).Size() >= 100.0);
    }

    UFUNCTION()
    private void Step_TargetLeaves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveTarget(FVector(3000.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_SatDown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _SawReturn = _SawReturn || _Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Return;
        Res.Set(_Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Disguised && _Mimic.Get_IsTucked());
    }

    UFUNCTION()
    private void Step_AssertHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawReturn, "the behaviour went through Return");
        Assert_True(_Mimic.Get_HasTarget() == false, "the target was lost");
        const auto Away = _Mimic.Get_Location() - _Mimic.Get_Home();
        const auto Distance = FVector(Away.X, Away.Y, 0.0).Size();
        Assert_True(Distance <= utils_pickle_mimic::HomeTolerance + 5.0, f"it sat down at home ({Distance} uu away)");
        Assert_True(_Mimic.Get_LidOpen() <= 0.01f, f"the lid is shut ({_Mimic.Get_LidOpen()})");
    }
}
