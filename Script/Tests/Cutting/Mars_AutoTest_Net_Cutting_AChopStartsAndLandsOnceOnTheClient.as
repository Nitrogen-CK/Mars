// The server chops, and asks a second chop the next frame while the first swings: the second changes nothing. The client
// raises OnChopStarted once and OnChopLanded once, in that order, and its ledger counts one chop started and landed.
// Surface: Ck.Cutting.Net.AS_Cutting_AChopStartsAndLandsOnceOnTheClient
class UCk_AutoTest_Net_Cutting_AChopStartsAndLandsOnceOnTheClient : UMars_AutoTestRig_NetCutting
{
    private const FVector k_Location = FVector(109000.0, 0.0, 5000.0);

    private bool _SecondAskedWhileSwinging = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientRaisedTwo", n"OnClientRaisedTwo", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRaisedTwo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCuttingStationFound() && _Events.Num() >= 2);
    }

    // A settle, so a duplicate would have arrived.
    UFUNCTION()
    private void OnClientRaisedTwo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] AChopStartsAndLandsOnceOnTheClient client: events [{Get_EventsText()}], serials {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()}, ensures {Get_NewEnsures()}");
        Assert_True(Get_IsOneChop(), f"the client raises one start then one landing (got [{Get_EventsText()}])");
        Assert_True(_Cutting.Get_ChopSerial() == 1 && _Cutting.Get_LandSerial() == 1,
            f"the client's ledger counts one chop (got {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCuttingStation(k_Location);
        WaitUntil(n"Is_CuttingStationFound", n"OnServerFound", k_SlowPolls);
    }

    // A beat for the client's copy to compose before the chop, so it mirrors the chop rather than composing after it.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerChop");
    }

    UFUNCTION()
    private void OnServerChop(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
        WaitFrames(2, n"OnServerSecondChop");
    }

    UFUNCTION()
    private void OnServerSecondChop(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SecondAskedWhileSwinging = _Cutting.Get_IsChopping();
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
        WaitUntil(n"Is_ServerChopDone", n"OnServerChopDone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cutting.Get_LandSerial() >= 1 && _Cutting.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void OnServerChopDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] AChopStartsAndLandsOnceOnTheClient server: events [{Get_EventsText()}], serials {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()}, second asked while swinging {_SecondAskedWhileSwinging}, ensures {Get_NewEnsures()}");
        Assert_True(_SecondAskedWhileSwinging, "the second chop was asked while the first swung");
        Assert_True(Get_IsOneChop(), f"the server raises one start then one landing (got [{Get_EventsText()}])");
        Assert_True(_Cutting.Get_ChopSerial() == 1 && _Cutting.Get_LandSerial() == 1,
            f"the second chop changes nothing (got {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
