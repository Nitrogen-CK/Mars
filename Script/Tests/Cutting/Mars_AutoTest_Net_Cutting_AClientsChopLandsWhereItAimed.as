// The server seats the subject. The client, seeing the subject operate, chops through utils_cutting::Request_ChopFor with an
// aim of its own: on the server the hand is that aim (clamped to the board) when the chop lands, and both machines raise one
// start and one landing.
// Surface: Ck.Cutting.Net.AS_Cutting_AClientsChopLandsWhereItAimed
class UCk_AutoTest_Net_Cutting_AClientsChopLandsWhereItAimed : UMars_AutoTestRig_NetCutting
{
    private const FVector k_Location = FVector(110000.0, 0.0, 5000.0);
    private const float32 k_AimCm = -17.5f;

    private float32 Get_ExpectedHand() const
    {
        return Math::Clamp(k_AimCm, -constants_cutting_net_autotest::k_BoardHalfWidth, constants_cutting_net_autotest::k_BoardHalfWidth);
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_CuttingHeldBySubject", n"OnClientSeesOperator", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSeesOperator(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_cutting::Request_ChopFor(_Cutting, Get_SubjectEntity(), k_AimCm);
        WaitUntil(n"Is_TwoEventsRaised", n"OnClientRaisedTwo", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRaisedTwo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] AClientsChopLandsWhereItAimed client: events [{Get_EventsText()}], ledger hand {_Cutting.Get_HandLateral()} (aim {k_AimCm}), ensures {Get_NewEnsures()}");
        Assert_True(Get_IsOneChop(), f"the client raises one start then one landing (got [{Get_EventsText()}])");
        Assert_True(Get_IsNear(_Cutting.Get_HandLateral(), Get_ExpectedHand()), f"the client's ledger hand is the aim {Get_ExpectedHand()} (got {_Cutting.Get_HandLateral()})");
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
        const auto Landing = _HandAtLanding[0];
        Log(f"[CuttingNetTest] AClientsChopLandsWhereItAimed server: events [{Get_EventsText()}], hand at landing {Landing} (aim {k_AimCm}), ensures {Get_NewEnsures()}");
        Assert_True(Get_IsOneChop(), f"the server raises one start then one landing (got [{Get_EventsText()}])");
        Assert_True(Get_IsNear(Landing, Get_ExpectedHand()), f"the hand is the aim {Get_ExpectedHand()} when the chop lands (got {Landing})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
