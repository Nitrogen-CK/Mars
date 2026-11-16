// The host turns two dials a step at a time: the lock's ledger carries their indices, and the client's own dials step
// there the shorter way round, a click per detent: dial 0 two detents forward, dial 2 one back past Square. No lock
// signal is raised on the client and the untouched dial raises nothing.
// Surface: Ck.Bellkeeper.Net.AS_Bellkeeper_TheHostsDialsTurnOnTheClient
class UCk_AutoTest_Net_Bellkeeper_TheHostsDialsTurnOnTheClient : UMars_AutoTestRig_NetBellkeeper
{
    default _TimeoutSeconds = 25.0f;

    private const float32 k_BetweenStepsSeconds = 1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(FVector(781000.0, 0.0, 5000.0));
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PanelFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // A copy the server already destroyed is not read.
    UFUNCTION()
    private void Is_LedgerTurned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLockAlive() && Get_IndicesRead(Get_Ledger().DialIndices, FIntVector(2, 0, 5)));
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
        WaitSeconds(k_SettleSeconds, n"OnServerFirstStep");
    }

    UFUNCTION()
    private void OnServerFirstStep(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Dials = _Lock.Get_Dials();
        Dials[0].Request_Step(FMars_Request_Dial_Step(2));
        WaitSeconds(k_BetweenStepsSeconds, n"OnServerSecondStep");
    }

    UFUNCTION()
    private void OnServerSecondStep(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Dials = _Lock.Get_Dials();
        Dials[2].Request_Step(FMars_Request_Dial_Step(-1));
        WaitUntil(n"Is_LedgerTurned", n"OnServerTurned", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerTurned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("TheHostsDialsTurnOnTheClient");
        Assert_True(Get_IndicesRead(Get_DialIndices(), FIntVector(2, 0, 5)), f"the server's dials read 2, 0, 5 ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_LedgerTurned", n"OnClientTurned", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientTurned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ArriveSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = Log_BellLine("TheHostsDialsTurnOnTheClient");
        Assert_True(Get_IndicesRead(Get_DialIndices(), FIntVector(2, 0, 5)), f"the client's own dials read 2, 0, 5 ({Line})");
        Assert_Equals_Int(Get_CrossingsOf(0), 2, f"dial 0 clicked once per detent it passed ({Line})");
        Assert_Equals_Int(Get_CrossingsOf(2), 1, f"dial 2 went back the shorter way, one detent ({Line})");
        Assert_Equals_Int(Count_DialSignalsOf(1), 0, f"dial 1 raised nothing ({Line})");
        Assert_Equals_Int(Count_LockedDials(), 0, f"no client dial is locked ({Line})");
        Assert_Equals_Int(_FailedFrames.Num() + _SolvedFrames.Num() + _StateFrames.Num(), 0, f"no lock signal was raised ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
