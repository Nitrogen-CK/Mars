// While the client holds Interact_Primary, the server reserves a station for the subject and then releases it: the
// release clears the subject's remote input, so with the client still holding (and still sending Held) the server reads
// the intent inactive, the next sample seeds without raising a press (one press in all), and samples keep arriving.
// Surface: Ck.InputIntents.Net.AS_InputIntents_LeavingClearsTheRemoteState
class UCk_AutoTest_Net_InputIntents_LeavingClearsTheRemoteState : UMars_AutoTestRig_NetInputIntents
{
    private const FVector k_Base = FVector(102000.0, 0.0, 5000.0);
    // Frames the client keeps holding after its copy of the station is free again.
    private const int32 k_HoldAfterFreeFrames = 60;
    private const int32 k_ServerAfterFreeFrames = 30;

    private EMars_TESTONLY_LeavePhase _ClientPhase = EMars_TESTONLY_LeavePhase::Seeding;
    private int32 _ClientPhaseFrames = 0;
    private int32 _ServerActiveAfterFree = 0;

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

    UFUNCTION()
    private void OnClientKeysReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientDone", n"OnClientDone", k_SlowPolls);
    }

    // Seed frames, press and hold until this copy mirrors the station's release (the reserve and the release can reach it
    // in one update, so the release serial is what it waits on), then
    // k_HoldAfterFreeFrames more, release, flush. Every frame is sampled and sent.
    UFUNCTION()
    private void Is_ClientDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _ClientPhaseFrames += 1;

        if (_ClientPhase == EMars_TESTONLY_LeavePhase::Seeding && _ClientPhaseFrames >= k_SeedFrames)
        {
            _Keys.Press_Row(k_Intent);
            Enter_ClientPhase(EMars_TESTONLY_LeavePhase::HoldingUntilReleased);
        }
        else if (_ClientPhase == EMars_TESTONLY_LeavePhase::HoldingUntilReleased && Get_IsStationFound()
            && _Station.Get_ReleaseSerial() >= 1 && Get_IsFreeOf(Get_SubjectOperator()))
        {
            Log("[InputIntentsNet] the client's copy of the station has been released");
            Enter_ClientPhase(EMars_TESTONLY_LeavePhase::HoldingAfterFree);
        }
        else if (_ClientPhase == EMars_TESTONLY_LeavePhase::HoldingAfterFree && _ClientPhaseFrames >= k_HoldAfterFreeFrames)
        {
            _Keys.Release_Row(k_Intent);
            Enter_ClientPhase(EMars_TESTONLY_LeavePhase::Flushing);
        }

        Sample_AndSend();
        Result.Set(_ClientPhase == EMars_TESTONLY_LeavePhase::Flushing && _ClientPhaseFrames >= k_FlushFrames);
    }

    private void Enter_ClientPhase(EMars_TESTONLY_LeavePhase InPhase)
    {
        _ClientPhase = InPhase;
        _ClientPhaseFrames = 0;
    }

    UFUNCTION()
    private void OnClientDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[InputIntentsNet] the client held through the station's reserve and release; its sampler counted {Get_ClientPressSerial()} press(es)");
        Assert_True(Get_ClientPressSerial() == 1, f"the client pressed once (got {Get_ClientPressSerial()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStation(k_Base);
        WaitUntil(n"Is_ServerFoundAndHeldDown", n"OnServerFoundAndHeldDown", k_SlowPolls);
    }

    // The station has composed and the client's hold has arrived.
    UFUNCTION()
    private void Is_ServerFoundAndHeldDown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Tick_ServerEdge();
        Result.Set(Get_IsStationFound() && _Intents.Get_IsIntentActive(k_Intent));
    }

    UFUNCTION()
    private void OnServerFoundAndHeldDown(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Station.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        WaitUntil(n"Is_ServerHeldBySubject", n"OnServerHeldBySubject", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHeldBySubject(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Tick_ServerEdge();
        Result.Set(Get_IsHeldBy(Get_SubjectOperator()));
    }

    UFUNCTION()
    private void OnServerHeldBySubject(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Intents.Get_IsIntentActive(k_Intent), "the server reads the hold while the subject operates");
        _Station.Request_Release(FMars_Request_Station_Release(Get_SubjectEntity(), EMars_Station_ReleaseReason::StationRequested));
        WaitUntil(n"Is_ServerFree", n"OnServerFree", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Tick_ServerEdge();
        Result.Set(Get_IsFreeOf(Get_SubjectOperator()));
    }

    UFUNCTION()
    private void OnServerFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerSettledAfterFree", n"OnServerSettledAfterFree", k_SlowPolls);
    }

    // The clear lands a drain after the release: the first frames after it are not counted.
    UFUNCTION()
    private void Is_ServerSettledAfterFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Tick_ServerEdge();
        _ServerSettleFrames += 1;
        if (_ServerSettleFrames > 5 && _Intents.Get_IsIntentActive(k_Intent))
        { _ServerActiveAfterFree += 1; }

        Result.Set(_ServerSettleFrames >= k_ServerAfterFreeFrames);
    }

    UFUNCTION()
    private void OnServerSettledAfterFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto& Remote = _Intents.Get_Fragment(FMars_Fragment_InputIntents_Remote);
        Log(f"[InputIntentsNet] after the release the server read the hold on {_ServerActiveAfterFree} frames; {_ServerPresses} press(es) in all; reseeded {Remote.LookTotal.IsSet()}");
        Assert_True(_ServerActiveAfterFree == 0, f"the server reads the intent inactive after the release (active on {_ServerActiveAfterFree} frames)");
        Assert_True(_ServerPresses == 1, f"the reseed raised no press (got {_ServerPresses} presses)");
        Assert_True(Remote.LookTotal.IsSet(), "a sample after the clear seeded the remote state again");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}

enum EMars_TESTONLY_LeavePhase
{
    Seeding,
    HoldingUntilReleased,
    HoldingAfterFree,
    Flushing
}
