// A commit asked of the client's copy is dropped there: the copy's drain removes it and judges nothing, the server's
// lock never hears of it, and nothing is published after the client found its copy.
// Surface: Ck.Bellkeeper.Net.AS_Bellkeeper_AClientsCommitIsDropped
class UCk_AutoTest_Net_Bellkeeper_AClientsCommitIsDropped : UMars_AutoTestRig_NetBellkeeper
{
    default _TimeoutSeconds = 25.0f;

    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_DroppedLookSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(FVector(784000.0, 0.0, 5000.0));
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PanelFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
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
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("AClientsCommitIsDropped");
        const auto Ledger = Get_Ledger();
        Assert_Equals_Int(_Lock.Get_FailedCommits(), 0, f"the server's lock counts no failure ({Line})");
        Assert_False(_Lock.Get_IsSolved(), f"the server's lock is not solved ({Line})");
        Assert_Equals_Int(_FailedFrames.Num(), 0, f"the server raised no failure ({Line})");
        Assert_True(Ledger.FailedCommits == 0 && Ledger.Lock == EMars_Bellkeeper_Lock::Sealed
            && Get_IndicesRead(Ledger.DialIndices, FIntVector(0, 0, 0)), f"the server's ledger still reads 0, Sealed, [0, 0, 0] ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ArriveSeconds, n"OnClientCommit");
    }

    UFUNCTION()
    private void OnClientCommit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Lock.Request_Commit(FMars_Request_Bellkeeper_Commit());
        WaitSeconds(k_DroppedLookSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("AClientsCommitIsDropped");
        Assert_False(_Lock.Has_Fragment(FMars_Fragment_Bellkeeper_Requests), f"the client's copy holds no request ({Line})");
        Assert_Equals_Int(_Lock.Get_FailedCommits(), 0, f"the client's lock counts no failure ({Line})");
        Assert_Equals_Int(_FailedFrames.Num() + _SolvedFrames.Num() + _StateFrames.Num(), 0, f"no lock signal was raised ({Line})");
        Assert_Equals_Int(Count_NotifiesAfter(_FoundFrame), 0, f"no ledger application after the find ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
