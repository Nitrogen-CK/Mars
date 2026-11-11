// A client that bypasses the cue and requests a Reserve on its own copy of the station changes nothing: its arbiter drops
// the request (it has no authority), so after a settle the station is free on both machines.
// Surface: Ck.Station.Net.AS_Station_AClientsDirectReserveIsDropped
class UCk_AutoTest_Net_Station_AClientsDirectReserveIsDropped : UMars_AutoTestRig_NetStation
{
    private const FVector k_Base = FVector(91000.0, 0.0, 5000.0);
    // The server checks after the client has requested and settled.
    private const float32 k_ServerCheckSeconds = 4.0f;
    private const float32 k_ClientSettleSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_StationFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStation(k_Base);
        WaitUntil(n"Is_StationFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerCheckSeconds, n"OnServerChecked");
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsFreeOf(Get_SubjectOperator()), "the server's station is still free");
        Assert_True(_Station.Get_ReleaseSerial() == 0 && _Station.Get_RefusalSerial() == 0, "the server's ledger never moved");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Station.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Free = Get_IsFreeOf(Get_SubjectOperator());
        Assert_True(Free, "the client's station is still free and the subject's back-ref is clear");
        Assert_True(_Reserved.Num() == 0, f"the client raised no OnReserved (got {_Reserved.Num()})");
        Log(f"[StationNetTest] client direct reserve dropped free={Free} reserved={_Reserved.Num()} ensures={Get_NewEnsures()}");
        FinishSuccess();
    }
}
