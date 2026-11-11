// A client that holds a station leaves through its Act cue: on both machines nobody operates it and the subject's back-ref
// is clear. The client raised OnReleased once, naming the subject and OperatorRequested, and the Operated claim is gone.
// Surface: Ck.Station.Net.AS_Station_AClientLeavesAndTheStationIsFree
class UCk_AutoTest_Net_Station_AClientLeavesAndTheStationIsFree : UMars_AutoTestRig_NetStation
{
    private const FVector k_Base = FVector(90000.0, 0.0, 5000.0);

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
        WaitUntil(n"Is_HeldBySubject", n"OnServerHeldBySubject", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHeldBySubject(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_FreeOfSubject", n"OnServerFree", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Station.Get_ReleaseSerial() == 1, f"the server released once (got {_Station.Get_ReleaseSerial()})");
        Assert_True(_Station.Get_LastReleaseReason() == EMars_Station_ReleaseReason::OperatorRequested,
            f"the server's release says OperatorRequested (got {_Station.Get_LastReleaseReason() :n})");
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_station::Request_ActFor(_Station, Get_SubjectEntity(), EMars_Station_Verb::Reserve);
        WaitUntil(n"Is_HeldBySubject", n"OnClientHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientHeldSettled");
    }

    UFUNCTION()
    private void OnClientHeldSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_UseIsClaimed(), "the client's Use interactable holds the Operated claim while held");
        _Released.Empty();
        _ReleaseReasons.Empty();
        utils_station::Request_ActFor(_Station, Get_SubjectEntity(), EMars_Station_Verb::Leave);
        WaitUntil(n"Is_ReleasedOnce", n"OnClientFree", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    // The client's ledger records the release.
    UFUNCTION()
    private void Is_ReleasedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Station) && _Station.Get_ReleaseSerial() > 0);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Free = Get_IsFreeOf(Get_SubjectOperator());
        const auto Claimed = Get_UseIsClaimed();
        Assert_False(_Station.Get_IsOperated(), "the client's station is free");
        Assert_True(ck::Is_NOT_Valid(Get_SubjectOperator().Get_Station()), "the client's subject back-ref is clear");
        Assert_True(_Released.Num() == 1, f"the client raised OnReleased once (got {_Released.Num()})");
        if (_Released.Num() == 1)
        {
            Assert_True(_Released[0] == Get_SubjectEntity(), "the client's OnReleased names the subject");
            Assert_True(_ReleaseReasons[0] == EMars_Station_ReleaseReason::OperatorRequested,
                f"the client's OnReleased says OperatorRequested (got {_ReleaseReasons[0] :n})");
        }

        Assert_False(Claimed, "the client's Operated claim is gone");
        Log(f"[StationNetTest] client leave free={Free} released={_Released.Num()} claimed={Claimed} ensures={Get_NewEnsures()}");
        FinishSuccess();
    }
}
