// A pull let go at 0.3 s (the interaction cancelled before the 0.7 s Grip + Tug completes) finishes Failed and consumes
// nothing: no release, the charge still there, the target still enabled, and no yield appears afterwards.
class UMars_AutoTest_ScreamingTurnip_ACancelledPullKeepsTheCharge : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 21000.0, -30000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        Build_Floor(InHandle);
        Spawn_Bed(InHandle);

        Add_Step_WaitUntil("the bed is constructed", n"Check_BedReady");
        Add_Step("start a pull with free hands", n"Step_Pull");
        Add_Step_WaitUntil("the pull is live", n"Check_PullStarted", k_SlowPolls);
        Add_Step_WaitSeconds("hold for 0.3 s", 0.3f);
        Add_Step("let go", n"Step_LetGo");
        Add_Step_WaitUntil("the pull finishes", n"Check_PullFinished", k_SlowPolls);
        Add_Step_WaitSeconds("past where the full pull would have completed", 0.8f);
        Add_Step("nothing consumed", n"Step_AssertKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Pull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Start_Pull();
    }

    UFUNCTION()
    private void Check_PullStarted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PullsStarted >= 1);
    }

    UFUNCTION()
    private void Step_LetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PullResults.Num(), 0, "the pull is still live at 0.3 s");
        Cancel_Pull();
    }

    UFUNCTION()
    private void Check_PullFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PullResults.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PullResults[0] == ECk_SucceededFailed::Failed, "a let-go pull finishes Failed");
        Assert_Equals_Int(_Released.Num(), 0, "no release");
        Assert_Equals_Int(_BedForage.Get_ChargesLeft(), 1, "the charge is kept");
        Assert_False(_BedForage.Get_IsExhausted(), "the bed is not exhausted");
        Assert_True(_BedInteractable.Get_EnableDisable() == ECk_EnableDisable::Enable, "the target is still enabled");
        Assert_Equals_Int(Get_YieldCountNearBed(InHandle), 0, "no root lies by the bed");
    }
}
