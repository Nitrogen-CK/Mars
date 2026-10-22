// Dedicated-cycle replacement of the legacy powered-coupling repro; that original red topology is frozen in evidence.
class UMars_AutoTest_Bellkeeper_RecommitRestartsThePoweredBurst : UMars_AutoTestRig_BellkeeperDedicatedVent
{
    default _TimeoutSeconds = 12.0f;
    private FCk_Handle_Timer _OldTimer;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddDedicatedLock(InHandle);
        Add_Step("wrong commit", n"Step_Commit");
        Add_Step_WaitUntil("first actual Telegraph, disarmed", n"Check_FirstTelegraph", k_SlowPolls, 0);
        Add_Step("wrong again during Telegraph", n"Step_Commit");
        Add_Step_WaitUntil("second actual Telegraph", n"Check_SecondTelegraph", k_SlowPolls, 0);
        Add_Step_WaitUntil("second pulse reaches actual Fire", n"Check_FirstFire", k_SlowPolls, 0);
        Add_Step("wrong again during Fire", n"Step_CommitDuringFire");
        Add_Step_WaitUntil("third actual Telegraph, disarmed", n"Check_ThirdTelegraph", k_SlowPolls, 0);
        Add_Step("stale previous expiry cannot cut the replacement", n"Step_StaleExpiry");
        Add_Step_WaitUntil("final complete burst ends", n"Check_Finished", k_SlowPolls, 0);
        Add_Step("final durations complete and attempt remains", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Commit(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit()); }

    UFUNCTION()
    private void Check_FirstTelegraph(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_TelegraphTimes.Num() == 1 && Get_IsTelegraphing() && _VentSource.Get_IsAsserted());
    }

    UFUNCTION()
    private void Check_SecondTelegraph(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_TelegraphTimes.Num() == 2 && _StopTimes.Num() == 1 && Get_IsTelegraphing());
    }

    UFUNCTION()
    private void Check_FirstFire(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_FireTimes.Num() == 1 && Get_IsFiring());
    }

    UFUNCTION()
    private void Step_CommitDuringFire(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _OldTimer = _Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper).VentTimer;
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_ThirdTelegraph(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_TelegraphTimes.Num() == 3 && _StopTimes.Num() == 2 && Get_IsTelegraphing());
    }

    UFUNCTION()
    private void Step_StaleExpiry(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Bellkeeper.Request_EndVent(FMars_Request_Bellkeeper_EndVent(_OldTimer)); }

    UFUNCTION()
    private void Check_Finished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_FireTimes.Num() == 2 && _StopTimes.Num() == 3 && _VentCycle.Get_IsRunning() == false
            && _Hazard.Get_IsArmed() == false && _Bellkeeper.Get_IsVenting() == false && _VentSource.Get_IsAsserted() == false);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Bellkeeper.Get_FailedCommits(), 3, "three wrong commits charged once each");
        Assert_Equals_Int(_Bellkeeper.Get_RemainingRewards(), 1, "final reward remains");
        Assert_True(_FireTimes[1] - _TelegraphTimes[2] >= 0.8, "final Telegraph completed authored0.8seconds");
        Assert_True(_StopTimes[2] - _FireTimes[1] >= 1.2, "final Fire completed authored1.2seconds");
        for (const auto& Dial : _Dials)
        { Assert_Equals_Int(Dial.Get_Index(), 0, "failed commits preserve attempt"); }
    }
}
