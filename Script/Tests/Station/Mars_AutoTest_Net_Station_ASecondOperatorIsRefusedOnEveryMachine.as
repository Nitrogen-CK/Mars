// The server reserves the station for a replicated operator of its own; then the client asks for it for the subject. The
// authority rejects it Occupied: on both machines the first operator still holds it, and the refusal serial advanced by
// one naming the subject with the arbiter's reason. The client raised OnReserveRejected once.
// Surface: Ck.Station.Net.AS_Station_ASecondOperatorIsRefusedOnEveryMachine
class UCk_AutoTest_Net_Station_ASecondOperatorIsRefusedOnEveryMachine : UMars_AutoTestRig_NetStation
{
    private const FVector k_Base = FVector(89000.0, 0.0, 5000.0);

    private int32 _SerialAtAct = 0;

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
        _SerialAtAct = _Station.Get_RefusalSerial();
        WaitUntil(n"Is_Refused", n"OnServerRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Refusal("server");
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientSeesSecond(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialAtAct = _Station.Get_RefusalSerial();
        utils_station::Request_ActFor(_Station, Get_SubjectEntity(), EMars_Station_Verb::Reserve);
        WaitUntil(n"Is_Refused", n"OnClientRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Refusal("client");
        Assert_True(_Rejected.Num() == 1, f"the client raised OnReserveRejected once (got {_Rejected.Num()})");
        Assert_True(_Rejected.Num() == 0 || _Rejected[0] == Get_SubjectEntity(), "the client's OnReserveRejected names the subject");
        const auto NewEnsures = Get_NewEnsures();
        const auto StillSecond = Get_IsHeldBy(_SecondOperator);
        Assert_True(NewEnsures == 0, f"the client fired no ensure (got {NewEnsures})");
        Log(f"[StationNetTest] client refused serial={_Station.Get_RefusalSerial() - _SerialAtAct} reason={_Station.Get_LastRefusal() :n} "
            + f"rejected={_Rejected.Num()} stillSecond={StillSecond} ensures={NewEnsures}");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Station.Get_RefusalSerial() > _SerialAtAct);
    }

    private void Assert_Refusal(FString InMachine)
    {
        Assert_True(Get_IsHeldBy(_SecondOperator), f"the {InMachine}'s station is still held by the first operator");
        Assert_True(_Station.Get_RefusalSerial() == _SerialAtAct + 1,
            f"the {InMachine}'s refusal serial advanced by one (from {_SerialAtAct} to {_Station.Get_RefusalSerial()})");
        Assert_True(_Station.Get_LastRefused() == Get_SubjectEntity(), f"the {InMachine}'s refusal names the subject");
        Assert_True(_Station.Get_LastRefusal() == EMars_Station_RejectReason::Occupied,
            f"the {InMachine}'s refusal says Occupied (got {_Station.Get_LastRefusal() :n})");
    }
}
