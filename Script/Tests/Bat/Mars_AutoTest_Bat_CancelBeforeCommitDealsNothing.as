// The bat telegraphs a swoop at a hostile target and the control layer cancels it before it commits: OnSwoopCancelled
// reports Cancelled, it never swoops, the target takes no damage and the bat goes back to flying (Approaching or Returning).
class UMars_AutoTest_Bat_CancelBeforeCommitDealsNothing : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -174000.0, 2000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("it telegraphs a swoop", n"Check_Telegraphing", 0, k_FlightSeconds);
        Add_Step("the swoop is cancelled before it commits", n"Step_Cancel");
        Add_Step_WaitUntil("it flies again", n"Check_Flying", 0, 5.0f);
        Add_Step("nothing was dealt", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Telegraphing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Bat) && _Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::Telegraphing);
    }

    UFUNCTION()
    private void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Bat.Request_CancelSwoop(FMars_Request_Bat_CancelSwoop(EMars_Bat_SwoopCancel::Cancelled));
    }

    UFUNCTION()
    private void Check_Flying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Phase = _Bat.Get_Phase();
        Res.Set(_Cancels.Num() > 0 && (Phase == EMars_Bat_Phase::Approaching || Phase == EMars_Bat_Phase::Returning));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cancels.Num(), 1, "one swoop was cancelled");
        Assert_True(_Cancels.Num() > 0 && _Cancels[0] == EMars_Bat_SwoopCancel::Cancelled, "its reason is Cancelled");
        Assert_False(Get_SawPhase(EMars_Bat_Phase::Swooping), f"it never committed (saw {Get_PhaseTrail()})");
        Assert_Equals_Int(_TargetDamaged, 0, "the target took no damage");
        Assert_Equals_Int(_Landed.Num(), 0, "no swoop landed");
        Assert_True(_Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::None, "no swoop runs");
        Assert_True(_Bat.Get_SwoopLedger().Cooldown > 0.0f, "the cancelled swoop's cooldown runs");
    }
}
