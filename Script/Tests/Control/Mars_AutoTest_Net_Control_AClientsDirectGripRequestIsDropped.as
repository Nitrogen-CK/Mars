// The client issues a grip claim straight on its copy of a replicated lever, bypassing the cue: its drain drops it, so
// neither the server's grip ledger nor the client's moves.
// Surface: Ck.Control.Net.AS_Control_AClientsDirectGripRequestIsDropped
class UCk_AutoTest_Net_Control_AClientsDirectGripRequestIsDropped : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(135000.0, 0.0, 5000.0);
    private const float32 k_ClientWindowSeconds = 1.0f;
    private const float32 k_ServerWindowSeconds = 4.0f;

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
        _Control.Request_Grip(FMars_Request_Control_Grip(Get_SubjectEntity(), EMars_Control_GripVerb::Begin));
        WaitSeconds(k_ClientWindowSeconds, n"OnClientWindowOver");
    }

    UFUNCTION()
    private void OnClientWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientsDirectGripRequestIsDropped client: authority {utils_net::Get_HasAuthority(_Control)}, arbitrated {_Control.Get_IsGripArbitrated()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_False(utils_net::Get_HasAuthority(_Control), "the client's lever has no authority");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_GripSerial() == 0 && _Control.Get_RefusalSerial() == 0,
            "the client's grip ledger did not move");
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
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientsDirectGripRequestIsDropped server: arbitrated {_Control.Get_IsGripArbitrated()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsGripArbitrated(), "the server's lever is arbitrated");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_GripSerial() == 0 && _Control.Get_RefusalSerial() == 0,
            "the server's grip ledger did not move");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
