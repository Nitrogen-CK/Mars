// The server reserves the station for a replicated operator of its own, lets the client see it, then destroys that
// operator: on both machines the station is free, the ledger says OperatorLost, and the client raised OnReleased once with
// that reason.
// Surface: Ck.Station.Net.AS_Station_AnOperatorThatEndsFreesTheStationOnEveryMachine
class UCk_AutoTest_Net_Station_AnOperatorThatEndsFreesTheStationOnEveryMachine : UMars_AutoTestRig_NetStation
{
    private const FVector k_Base = FVector(92000.0, 0.0, 5000.0);
    // How long the server lets the client see the held station before the operator ends.
    private const float32 k_ShowSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_HeldBySecond", n"OnClientSeesSecond", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStation(k_Base);
        Spawn_ServerOperator();
        WaitUntil(n"Is_StationAndSecondOperatorFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_SecondOperator));
        WaitUntil(n"Is_HeldBySecond", n"OnServerHeldBySecond", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHeldBySecond(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ShowSeconds, n"OnServerShown");
    }

    UFUNCTION()
    private void OnServerShown(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_entity_lifetime::Request_DestroyEntity(_SecondOperator);
        WaitUntil(n"Is_StationFree", n"OnServerFree", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Station.Get_ReleaseSerial() == 1, f"the server released once (got {_Station.Get_ReleaseSerial()})");
        Assert_True(_Station.Get_LastReleaseReason() == EMars_Station_ReleaseReason::OperatorLost,
            f"the server's release says OperatorLost (got {_Station.Get_LastReleaseReason() :n})");
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientSeesSecond(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Released.Empty();
        _ReleaseReasons.Empty();
        WaitUntil(n"Is_StationFree", n"OnClientFree", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Free = _Station.Get_IsOperated() == false;
        Assert_True(Free, "the client's station is free");
        Assert_True(_Station.Get_LastReleaseReason() == EMars_Station_ReleaseReason::OperatorLost,
            f"the client's ledger says OperatorLost (got {_Station.Get_LastReleaseReason() :n})");
        Assert_True(_Released.Num() == 1, f"the client raised OnReleased once (got {_Released.Num()})");
        if (_ReleaseReasons.Num() == 1)
        {
            Assert_True(_ReleaseReasons[0] == EMars_Station_ReleaseReason::OperatorLost,
                f"the client's OnReleased says OperatorLost (got {_ReleaseReasons[0] :n})");
        }

        const auto NewEnsures = Get_NewEnsures();
        Assert_True(NewEnsures == 0, f"the client fired no ensure (got {NewEnsures})");
        Log(f"[StationNetTest] client operator lost free={Free} released={_Released.Num()} reason={_Station.Get_LastReleaseReason() :n} ensures={NewEnsures}");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_StationFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Station) && _Station.Get_IsOperated() == false);
    }
}
