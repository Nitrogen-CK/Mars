// A client asks for a station through its Act cue: the authority reserves it, and on both machines the station names the
// subject and the subject's back-ref names the station. The client raised OnReserved once and its Use interactable holds
// the Operated claim; nobody ensures.
// Surface: Ck.Station.Net.AS_Station_AClientReservesAStationOnEveryMachine
class UCk_AutoTest_Net_Station_AClientReservesAStationOnEveryMachine : UMars_AutoTestRig_NetStation
{
    private const FVector k_Base = FVector(88000.0, 0.0, 5000.0);

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
        const auto NewEnsures = Get_NewEnsures();
        Assert_True(NewEnsures == 0, f"the server fired no ensure (got {NewEnsures})");
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
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Held = Get_IsHeldBy(Get_SubjectOperator());
        const auto Claimed = Get_UseIsClaimed();
        const auto NewEnsures = Get_NewEnsures();
        Assert_True(Held, "the client's station names the subject and the subject's back-ref names it");
        Assert_True(_Reserved.Num() == 1, f"the client raised OnReserved once (got {_Reserved.Num()})");
        Assert_True(_Reserved.Num() == 0 || _Reserved[0] == Get_SubjectEntity(), "the client's OnReserved names the subject");
        Assert_True(Claimed, "the client's Use interactable holds the Operated claim");
        Assert_True(NewEnsures == 0, f"the client fired no ensure (got {NewEnsures})");
        Log(f"[StationNetTest] client reserve held={Held} reserved={_Reserved.Num()} claimed={Claimed} ensures={NewEnsures}");
        FinishSuccess();
    }
}
