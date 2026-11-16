// The server commits its starting dials, which are wrong: its lock counts one failure and raises it once. The client's
// copy raises that failure once as it arrives, carrying the two rewards still at stake, after or with the level change,
// and never a solve.
// Surface: Ck.Bellkeeper.Net.AS_Bellkeeper_AWrongCommitReachesTheClientOnce
class UCk_AutoTest_Net_Bellkeeper_AWrongCommitReachesTheClientOnce : UMars_AutoTestRig_NetBellkeeper
{
    default _TimeoutSeconds = 25.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(FVector(782000.0, 0.0, 5000.0));
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PanelFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The server reads its lock, the client its ledger. A copy the server already destroyed is not read.
    UFUNCTION()
    private void Is_OneFailure(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsLockAlive() == false)
        {
            Result.Set(false);
            return;
        }

        Result.Set(Get_IsServer() ? _Lock.Get_FailedCommits() >= 1 : Get_Ledger().FailedCommits >= 1);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPanel(UMars_Bellkeeper_EntityScript);
        WaitUntil(n"Is_PanelFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerCommit");
    }

    UFUNCTION()
    private void OnServerCommit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Lock.Request_Commit(FMars_Request_Bellkeeper_Commit());
        WaitUntil(n"Is_OneFailure", n"OnServerFailed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFailed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("AWrongCommitReachesTheClientOnce");
        Assert_Equals_Int(_Lock.Get_FailedCommits(), 1, f"the server's lock counts one failure ({Line})");
        Assert_False(_Lock.Get_IsSolved(), f"the server's lock is not solved ({Line})");
        Assert_True(_FailedRemaining.Num() == 1 && _FailedRemaining[0] == 2, f"the server raised its failure once, two rewards at stake ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_OneFailure", n"OnClientFailed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFailed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ArriveSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("AWrongCommitReachesTheClientOnce");
        Assert_True(_FailedRemaining.Num() == 1 && _FailedRemaining[0] == 2, f"the client raised the failure once, two rewards at stake ({Line})");
        Assert_True(_StateFrames.Num() >= 1 && _FailedFrames.Num() == 1 && _StateFrames[0] <= _FailedFrames[0],
            f"the level changed no later than the failure ({Line})");
        Assert_Equals_Int(_Lock.Get_RemainingRewards(), 2, f"two rewards at stake on the client ({Line})");
        Assert_Equals_Int(_SolvedFrames.Num(), 0, f"the client raised no solve ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
