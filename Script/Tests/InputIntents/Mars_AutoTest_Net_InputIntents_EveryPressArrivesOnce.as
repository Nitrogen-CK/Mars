// The client presses and releases Interact_Primary 20 times, each press and each release a frame or more long, and sends
// every sample: an FMars_IntentEdge on the server's copy of the subject's InputIntents counts 20 presses, and no more
// arrive after them.
// Surface: Ck.InputIntents.Net.AS_InputIntents_EveryPressArrivesOnce
class UCk_AutoTest_Net_InputIntents_EveryPressArrivesOnce : UMars_AutoTestRig_NetInputIntents
{
    private const int32 k_Presses = 20;

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

        WaitUntil(n"Is_ServerCountedAll", n"OnServerCountedAll", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientKeysReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_PressCycle(k_Presses);
        WaitUntil(n"Is_ClientCycleDone", n"OnClientCycleDone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientCycleDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Done = Tick_PressCycle();
        Sample_AndSend();
        Result.Set(Done);
    }

    UFUNCTION()
    private void OnClientCycleDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[InputIntentsNet] the client pressed {_PressesDone} times; its sampler counted {Get_ClientPressSerial()}; {_SamplesSent} of {_SamplesMade} samples sent");
        Assert_True(Get_ClientPressSerial() == k_Presses, f"the client's sampler counted {k_Presses} presses (got {Get_ClientPressSerial()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ServerCountedAll(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Tick_ServerEdge();
        Result.Set(_ServerPresses >= k_Presses);
    }

    UFUNCTION()
    private void OnServerCountedAll(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Tick_ServerEdge();
        _ServerSettleFrames += 1;
        Result.Set(_ServerSettleFrames >= k_ServerSettleFrames);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[InputIntentsNet] the server counted {_ServerPresses} presses of {k_Presses}");
        Assert_True(_ServerPresses == k_Presses, f"the server counted {k_Presses} presses (got {_ServerPresses})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
