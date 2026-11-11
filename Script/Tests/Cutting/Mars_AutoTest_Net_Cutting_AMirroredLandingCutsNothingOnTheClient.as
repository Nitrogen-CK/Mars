// The server seats the subject, so both machines' control is in Operated with the cut bridge, and the server chops: the
// server's board answers one cut, and the client's copy raises the landing but its board answers none.
// Surface: Ck.Cutting.Net.AS_Cutting_AMirroredLandingCutsNothingOnTheClient
class UCk_AutoTest_Net_Cutting_AMirroredLandingCutsNothingOnTheClient : UMars_AutoTestRig_NetCutting
{
    private const FVector k_Location = FVector(114000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientLanded", n"OnClientLanded", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCuttingStationFound() && _Station.Get_IsOperatedBy(Get_SubjectEntity()) && _HandAtLanding.Num() >= 1);
    }

    // A settle, so a cut the bridge issued would have been answered.
    UFUNCTION()
    private void OnClientLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] AMirroredLandingCutsNothingOnTheClient client: events [{Get_EventsText()}], cuts answered {_CutsIssued}, ensures {Get_NewEnsures()}");
        Assert_True(Get_IsOneChop(), f"the client raises one start then one landing (got [{Get_EventsText()}])");
        Assert_True(_CutsIssued == 0, f"the client's board answers no cut (got {_CutsIssued})");
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
        _Station.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        WaitUntil(n"Is_CuttingHeldBySubject", n"OnServerHeldBySubject", k_SlowPolls);
    }

    // A beat for both machines' control to enter Operated before the chop.
    UFUNCTION()
    private void OnServerHeldBySubject(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerChop");
    }

    UFUNCTION()
    private void OnServerChop(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
        WaitUntil(n"Is_ServerLanded", n"OnServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_HandAtLanding.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] AMirroredLandingCutsNothingOnTheClient server: events [{Get_EventsText()}], cuts answered {_CutsIssued}, ensures {Get_NewEnsures()}");
        Assert_True(Get_IsOneChop(), f"the server raises one start then one landing (got [{Get_EventsText()}])");
        Assert_True(_CutsIssued == 1, f"the server's board answers the one cut (got {_CutsIssued})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
