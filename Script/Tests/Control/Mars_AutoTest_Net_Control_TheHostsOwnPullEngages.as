// On the server, the subject's own copy starts the interaction on the replicated lever, grips it and pulls it past the
// threshold, as the listen host's player does: the grip ledger reads Gripped by the subject, then Released, and both
// machines count one engagement.
// Surface: Ck.Control.Net.AS_Control_TheHostsOwnPullEngages
class UCk_AutoTest_Net_Control_TheHostsOwnPullEngages : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(139000.0, 0.0, 5000.0);

    private int32 _SerialWhenGripped = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_LeverFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EngagedOnce", n"OnClientEngaged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEngaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] TheHostsOwnPullEngages client: engagements {Get_Engagements()}, onEngaged {_EngagedCount}, active {_Control.Get_IsActive()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(Get_Engagements() == 1 && _EngagedCount == 1, f"the client mirrors one engagement (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Control.Get_IsActive(), "the client's lever is active");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Inactive);
        WaitUntil(n"Is_LeverFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnServerInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        WaitUntil(n"Is_GrippedBySubject", n"OnServerGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialWhenGripped = _Control.Get_GripSerial();
        WaitUntil(n"Is_PulledUntilEnded", n"OnServerCrossed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerCrossed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EngagedOnce", n"OnServerEngaged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEngaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Result = _FinishedResults.Num() > 0 ? _FinishedResults[0] : ECk_SucceededFailed::Failed;
        Log(f"[ControlNetTest] TheHostsOwnPullEngages server: serialWhenGripped {_SerialWhenGripped}, finished {_FinishedResults.Num()} first {Result :n}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, active {_Control.Get_IsActive()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_SerialWhenGripped == 1, f"the ledger read Gripped by the subject, the first grant (got serial {_SerialWhenGripped})");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_GripSerial() == 1, "the grip was released once it crossed");
        Assert_True(_FinishedResults.Num() == 1 && Result == ECk_SucceededFailed::Succeeded, f"the interaction ended Succeeded (got {_FinishedResults.Num()}, {Result :n})");
        Assert_True(Get_Engagements() == 1 && _EngagedCount == 1, f"the host's pull engaged once (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Control.Get_IsActive(), "the server's lever is active");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
