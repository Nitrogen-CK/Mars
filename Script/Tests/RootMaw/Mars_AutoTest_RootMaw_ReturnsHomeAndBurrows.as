// A hostile target stands 380 uu ahead: the Maw bursts up and glides after it. Once it has glided 100 uu from home the
// target leaves (to 3000 uu, past HomeRadius and LoseRadius): the Maw loses it, goes Return, glides back to within
// HomeTolerance of home, goes Buried and sinks back into the ground (jaw shut).
class UMars_AutoTest_RootMaw_ReturnsHomeAndBurrows : UMars_AutoTestRig_RootMaw
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-250000.0, 120000.0, 600.0);

    private bool _SawReturn = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMaw(InHandle, FMars_RootMaw_Spec());
        SpawnTarget(InHandle, FVector(380.0, 0.0, 0.0));

        Add_Step_WaitUntil("the Maw is composed and grounded", n"Check_Ready", k_SlowPolls, 0);
        Add_Step_WaitUntil("it glided 100 uu from home after the target", n"Check_LeftHome", 0, 8.0f);
        Add_Step("the target leaves", n"Step_TargetLeaves");
        Add_Step_WaitUntil("it is home and buried", n"Check_Buried", 0, 12.0f);
        Add_Step("it went home and back under the ground", n"Step_AssertHome");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_LeftHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Away = _Maw.Get_Location() - _Maw.Get_Home();
        Res.Set(FVector(Away.X, Away.Y, 0.0).Size() >= 100.0);
    }

    UFUNCTION()
    private void Step_TargetLeaves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveTarget(FVector(3000.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_Buried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _SawReturn = _SawReturn || _Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Return;
        Res.Set(_Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Buried && _Maw.Get_IsBuried());
    }

    UFUNCTION()
    private void Step_AssertHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawReturn, "the behaviour went through Return");
        Assert_True(_Maw.Get_HasTarget() == false, "the target was lost");
        const auto Away = _Maw.Get_Location() - _Maw.Get_Home();
        const auto Distance = FVector(Away.X, Away.Y, 0.0).Size();
        Assert_True(Distance <= utils_root_maw::HomeTolerance + 5.0, f"it burrowed at home ({Distance} uu away)");
        Assert_True(_Maw.Get_JawOpen() <= 0.01f, f"the jaw is shut ({_Maw.Get_JawOpen()})");
    }
}
