// The client holds Interact_Primary for k_HoldFrames frames and sends as an operating client does (on a change, or the
// keep-alive when nothing changed): the server reads the intent active from the press until the release arrives, through
// the keep-alive alone, and inactive after it.
// Surface: Ck.InputIntents.Net.AS_InputIntents_AReleaseClearsTheHold
class UCk_AutoTest_Net_InputIntents_AReleaseClearsTheHold : UMars_AutoTestRig_NetInputIntents
{
    private const int32 k_HoldFrames = 90;
    // The server must read the hold this many frames in a row: far more than k_KeepAliveFrames, far less than the hold.
    private const int32 k_ServerMinHeldFrames = 45;

    private EMars_TESTONLY_HoldPhase _ClientPhase = EMars_TESTONLY_HoldPhase::Seeding;
    private int32 _ClientPhaseFrames = 0;

    private int32 _ServerHeldFrames = 0;
    private int32 _ServerHolds = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetInputIntentsTest();
        _SendPolicy = EMars_TESTONLY_SendPolicy::OnChangeOrKeepAlive;

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            Build_ClientKeys(InHandle);
            WaitUntil(n"Is_ClientKeysReady", n"OnClientKeysReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ServerHeld", n"OnServerHeld_Begins", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientKeysReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientDone", n"OnClientDone", k_SlowPolls);
    }

    // Seed frames, press, hold k_HoldFrames frames past the client's own reading, release, flush.
    UFUNCTION()
    private void Is_ClientDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _ClientPhaseFrames += 1;
        const auto IsHeld = _Intents.Get_IsIntentActive(k_Intent);

        if (_ClientPhase == EMars_TESTONLY_HoldPhase::Seeding && _ClientPhaseFrames >= k_SeedFrames)
        {
            _Keys.Press_Row(k_Intent);
            Enter_ClientPhase(EMars_TESTONLY_HoldPhase::Pressing);
        }
        else if (_ClientPhase == EMars_TESTONLY_HoldPhase::Pressing && IsHeld)
        { Enter_ClientPhase(EMars_TESTONLY_HoldPhase::Holding); }
        else if (_ClientPhase == EMars_TESTONLY_HoldPhase::Holding && _ClientPhaseFrames >= k_HoldFrames)
        {
            _Keys.Release_Row(k_Intent);
            Enter_ClientPhase(EMars_TESTONLY_HoldPhase::Flushing);
        }

        Sample_AndSend();
        Result.Set(_ClientPhase == EMars_TESTONLY_HoldPhase::Flushing && IsHeld == false && _ClientPhaseFrames >= k_FlushFrames);
    }

    private void Enter_ClientPhase(EMars_TESTONLY_HoldPhase InPhase)
    {
        _ClientPhase = InPhase;
        _ClientPhaseFrames = 0;
    }

    UFUNCTION()
    private void OnClientDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[InputIntentsNet] the client held for {k_HoldFrames} frames; {_SamplesSent} of {_SamplesMade} samples sent");
        Assert_True(_SamplesSent < _SamplesMade, "the client sent only on a change or the keep-alive");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ServerHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Intents.Get_IsIntentActive(k_Intent));
    }

    UFUNCTION()
    private void OnServerHeld_Begins(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto IsHeld = _Intents.Get_IsIntentActive(k_Intent);
        if (IsHeld)
        { _ServerHeldFrames += 1; }

        Result.Set(IsHeld == false);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (_Intents.Get_IsIntentActive(k_Intent))
        { _ServerHolds += 1; }

        _ServerSettleFrames += 1;
        Result.Set(_ServerSettleFrames >= k_ServerSettleFrames);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[InputIntentsNet] the server read the hold for {_ServerHeldFrames} frames in a row, then inactive for {k_ServerSettleFrames - _ServerHolds} of {k_ServerSettleFrames} frames");
        Assert_True(_ServerHeldFrames >= k_ServerMinHeldFrames, f"the server read the hold through the keep-alive ({_ServerHeldFrames} frames, at least {k_ServerMinHeldFrames})");
        Assert_True(_ServerHolds == 0, f"the server read the intent inactive after the release (active on {_ServerHolds} frames)");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}

enum EMars_TESTONLY_HoldPhase
{
    Seeding,
    Pressing,
    Holding,
    Flushing
}
