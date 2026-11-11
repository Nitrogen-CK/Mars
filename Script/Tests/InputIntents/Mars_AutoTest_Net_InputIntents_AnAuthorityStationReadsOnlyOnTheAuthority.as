// Two reader stations (a test reader counts the operator's Interact_Primary presses on each machine's copy). The server
// reserves the Authority one for the subject and the client presses k_Presses times, streaming its samples: the server's
// copy counts them all and the client's copy, which does not read, counts none. The server then moves the subject to the
// PerMachine one and the client presses k_Presses times without streaming: the client's copy counts them all and the
// server's copy counts none from that client.
// Surface: Ck.InputIntents.Net.AS_InputIntents_AnAuthorityStationReadsOnlyOnTheAuthority
class UCk_AutoTest_Net_InputIntents_AnAuthorityStationReadsOnlyOnTheAuthority : UMars_AutoTestRig_NetInputIntents
{
    private const FVector k_Base = FVector(103000.0, 0.0, 5000.0);
    private const FVector k_PerMachineOffset = FVector(0.0, 300.0, 0.0);
    private const int32 k_Presses = 5;
    // How long the server leaves the PerMachine station operated: the client's presses fit well inside it.
    private const float32 k_PerMachineWindowSeconds = 5.0f;

    private FCk_Handle_Station _AuthorityStation;
    private FCk_Handle_Station _PerMachineStation;
    private EMars_TESTONLY_StancePhase _ClientPhase = EMars_TESTONLY_StancePhase::WaitingForAuthority;
    private int32 _ClientPhaseFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetInputIntentsTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            Build_ClientKeys(InHandle);
            WaitUntil(n"Is_ClientKeysReady", n"OnClientKeysReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // Both reader stations have composed on this machine (the server tracks them).
    private bool Get_AreStationsFound()
    {
        if (ck::Is_NOT_Valid(_AuthorityStation))
        {
            _AuthorityStation = Find_ReaderStation(EMars_Station_InputStance::Authority);
            if (ck::IsValid(_AuthorityStation) && utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(_AuthorityStation); }
        }

        if (ck::Is_NOT_Valid(_PerMachineStation))
        {
            _PerMachineStation = Find_ReaderStation(EMars_Station_InputStance::PerMachine);
            if (ck::IsValid(_PerMachineStation) && utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(_PerMachineStation); }
        }

        return ck::IsValid(_AuthorityStation) && ck::IsValid(_PerMachineStation);
    }

    UFUNCTION()
    private void OnClientKeysReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientDone", n"OnClientDone", k_SlowPolls);
    }

    // Waits for this copy to name the subject the Authority station's operator, presses streaming, waits for the
    // PerMachine station, presses without streaming.
    UFUNCTION()
    private void Is_ClientDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(false);
        _ClientPhaseFrames += 1;
        if (Get_AreStationsFound() == false)
        { return; }

        const auto Subject = Get_SubjectEntity();
        if (_ClientPhase == EMars_TESTONLY_StancePhase::WaitingForAuthority)
        {
            if (_AuthorityStation.Get_IsOperatedBy(Subject))
            {
                Start_PressCycle(k_Presses);
                Enter_ClientPhase(EMars_TESTONLY_StancePhase::PressingOnAuthority);
            }

            return;
        }

        if (_ClientPhase == EMars_TESTONLY_StancePhase::PressingOnAuthority)
        {
            const auto Done = Tick_PressCycle();
            Sample_AndSend();
            if (Done)
            { Enter_ClientPhase(EMars_TESTONLY_StancePhase::WaitingForPerMachine); }

            return;
        }

        if (_ClientPhase == EMars_TESTONLY_StancePhase::WaitingForPerMachine)
        {
            if (_PerMachineStation.Get_IsOperatedBy(Subject))
            {
                Start_PressCycle(k_Presses);
                Enter_ClientPhase(EMars_TESTONLY_StancePhase::PressingOnPerMachine);
            }

            return;
        }

        Result.Set(Tick_PressCycle());
    }

    private void Enter_ClientPhase(EMars_TESTONLY_StancePhase InPhase)
    {
        Log(f"[InputIntentsNet] the client enters {InPhase :n} after {_ClientPhaseFrames} frames");
        _ClientPhase = InPhase;
        _ClientPhaseFrames = 0;
    }

    UFUNCTION()
    private void OnClientDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto OnAuthority = Get_ReaderPresses(_AuthorityStation);
        const auto OnPerMachine = Get_ReaderPresses(_PerMachineStation);
        Log(f"[InputIntentsNet] the client's copies counted {OnAuthority} on the Authority station and {OnPerMachine} on the PerMachine station");
        Assert_True(OnAuthority == 0, f"the client's copy of the Authority station reads nothing (got {OnAuthority})");
        Assert_True(OnPerMachine == k_Presses, f"the client's copy of the PerMachine station counts {k_Presses} presses (got {OnPerMachine})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerReaderStation(k_Base, EMars_Station_InputStance::Authority);
        Spawn_ServerReaderStation(k_Base + k_PerMachineOffset, EMars_Station_InputStance::PerMachine);
        WaitUntil(n"Is_ServerStationsFound", n"OnServerStationsFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerStationsFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_AreStationsFound());
    }

    UFUNCTION()
    private void OnServerStationsFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AuthorityStation.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        WaitUntil(n"Is_ServerAuthorityCounted", n"OnServerAuthorityCounted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAuthorityCounted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_ReaderPresses(_AuthorityStation) >= k_Presses);
    }

    UFUNCTION()
    private void OnServerAuthorityCounted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerSettled", n"OnServerAuthoritySettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _ServerSettleFrames += 1;
        Result.Set(_ServerSettleFrames >= k_ServerSettleFrames);
    }

    UFUNCTION()
    private void OnServerAuthoritySettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto OnAuthority = Get_ReaderPresses(_AuthorityStation);
        Log(f"[InputIntentsNet] the server's copy of the Authority station counted {OnAuthority} of {k_Presses} presses");
        Assert_True(OnAuthority == k_Presses, f"the server's copy of the Authority station counts {k_Presses} presses (got {OnAuthority})");

        _AuthorityStation.Request_Release(FMars_Request_Station_Release(Get_SubjectEntity(), EMars_Station_ReleaseReason::StationRequested));
        WaitUntil(n"Is_ServerAuthorityReleased", n"OnServerAuthorityReleased", k_SlowPolls);
    }

    // An operator still seated at one station is refused by another: the second reserve waits for the release to land.
    UFUNCTION()
    private void Is_ServerAuthorityReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_AuthorityStation.Get_IsOperated() == false);
    }

    UFUNCTION()
    private void OnServerAuthorityReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PerMachineStation.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        WaitSeconds(k_PerMachineWindowSeconds, n"OnServerPerMachineWindowOver");
    }

    UFUNCTION()
    private void OnServerPerMachineWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto OnPerMachine = Get_ReaderPresses(_PerMachineStation);
        Log(f"[InputIntentsNet] the server's copy of the PerMachine station counted {OnPerMachine} presses from the client");
        Assert_True(_PerMachineStation.Get_IsOperatedBy(Get_SubjectEntity()), "the subject operated the PerMachine station through the window");
        Assert_True(OnPerMachine == 0, f"the server's copy of the PerMachine station counts none of the client's presses (got {OnPerMachine})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}

enum EMars_TESTONLY_StancePhase
{
    WaitingForAuthority,
    PressingOnAuthority,
    WaitingForPerMachine,
    PressingOnPerMachine
}
