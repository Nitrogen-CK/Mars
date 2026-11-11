// With the station free, the client chops through utils_cutting::Request_ChopFor for the subject: the authority refuses it,
// so no chop starts on either machine, and nothing ensures.
// Surface: Ck.Cutting.Net.AS_Cutting_AChopFromANonOperatorIsRefused
class UCk_AutoTest_Net_Cutting_AChopFromANonOperatorIsRefused : UMars_AutoTestRig_NetCutting
{
    private const FVector k_Location = FVector(111000.0, 0.0, 5000.0);
    private const float32 k_AimCm = 12.0f;
    // The client's window after its ask; the server's outlasts it.
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
        utils_cutting::Request_ChopFor(_Cutting, Get_SubjectEntity(), k_AimCm);
        WaitSeconds(k_ClientWindowSeconds, n"OnClientWindowOver");
    }

    UFUNCTION()
    private void OnClientWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] AChopFromANonOperatorIsRefused client: operated {_Station.Get_IsOperated()}, events [{Get_EventsText()}], serials {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()}, hand {_Cutting.Get_HandLateral()}, ensures {Get_NewEnsures()}");
        Assert_True(_Station.Get_IsOperated() == false, "the station stayed free");
        Assert_True(_Events.Num() == 0, f"no chop signal on the client (got [{Get_EventsText()}])");
        Assert_True(_Cutting.Get_ChopSerial() == 0, f"no chop started (got {_Cutting.Get_ChopSerial()})");
        Assert_True(Get_IsNear(_Cutting.Get_HandLateral(), 0.0f), f"the hand stayed at the centre (got {_Cutting.Get_HandLateral()})");
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
        Log(f"[CuttingNetTest] AChopFromANonOperatorIsRefused server: events [{Get_EventsText()}], serials {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()}, hand {_Cutting.Get_HandLateral()}, ensures {Get_NewEnsures()}");
        Assert_True(_Events.Num() == 0, f"no chop signal on the server (got [{Get_EventsText()}])");
        Assert_True(_Cutting.Get_ChopSerial() == 0, f"no chop started (got {_Cutting.Get_ChopSerial()})");
        Assert_True(Get_IsNear(_Cutting.Get_HandLateral(), 0.0f), f"the hand stayed at the centre (got {_Cutting.Get_HandLateral()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
