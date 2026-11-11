// The client calls Request_Nudge and Request_Chop on its own copy: its drain drops them, so neither machine's hand or
// serials move and no chop signal is raised.
// Surface: Ck.Cutting.Net.AS_Cutting_AClientsDirectRequestsAreDropped
class UCk_AutoTest_Net_Cutting_AClientsDirectRequestsAreDropped : UMars_AutoTestRig_NetCutting
{
    private const FVector k_Location = FVector(112000.0, 0.0, 5000.0);
    private const float32 k_NudgeCm = 10.0f;
    private const float32 k_ClientWindowSeconds = 2.0f;
    private const float32 k_ServerWindowSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_CuttingStationFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge(k_NudgeCm));
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
        WaitSeconds(k_ClientWindowSeconds, n"OnClientWindowOver");
    }

    UFUNCTION()
    private void OnClientWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] AClientsDirectRequestsAreDropped client: events [{Get_EventsText()}], serials {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()}, hand {_Cutting.Get_HandLateral()}, node {Get_NodeHand()}, ensures {Get_NewEnsures()}");
        Assert_True(_Events.Num() == 0, f"no chop signal on the client (got [{Get_EventsText()}])");
        Assert_True(_Cutting.Get_ChopSerial() == 0 && _Cutting.Get_LandSerial() == 0,
            f"the client's serials did not move (got {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()})");
        Assert_True(Get_IsNear(_Cutting.Get_HandLateral(), 0.0f) && Get_IsNear(Get_NodeHand(), 0.0f),
            f"the client's hand and node stayed at the centre (got {_Cutting.Get_HandLateral()}, {Get_NodeHand()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCuttingStation(k_Location);
        WaitUntil(n"Is_CuttingStationFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] AClientsDirectRequestsAreDropped server: events [{Get_EventsText()}], serials {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()}, hand {_Cutting.Get_HandLateral()}, ensures {Get_NewEnsures()}");
        Assert_True(_Events.Num() == 0, f"no chop signal on the server (got [{Get_EventsText()}])");
        Assert_True(_Cutting.Get_ChopSerial() == 0 && _Cutting.Get_LandSerial() == 0,
            f"the server's serials did not move (got {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()})");
        Assert_True(Get_IsNear(_Cutting.Get_HandLateral(), 0.0f), f"the server's hand stayed at the centre (got {_Cutting.Get_HandLateral()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
