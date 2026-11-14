// The server spawns a cutting station that starts a chop as it composes, and one second after it finds it chops again.
// The client's copy is born into the first chop started and not landed: it raises that chop's landing and the whole
// second chop, never the first chop's start, and its ledger counts two chops started and landed.
// Surface: Ck.Cutting.Net.AS_Cutting_ACopyBornIntoAChopRaisesOnlyItsLanding
class UCk_AutoTest_Net_Cutting_ACopyBornIntoAChopRaisesOnlyItsLanding : UMars_AutoTestRig_NetCutting
{
    private const FVector k_Location = FVector(115000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientTwoLanded", n"OnClientTwoLanded", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // Quiet once the copy is gone: the server may already have destroyed it.
    UFUNCTION()
    private void Is_ClientTwoLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCuttingStationFound() && _Cutting.Get_LandSerial() >= 2);
    }

    // A settle, so a duplicate would have arrived.
    UFUNCTION()
    private void OnClientTwoLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto First = Get_FirstNotifyLedger();
        const auto ChopSerial = _Cutting.Get_ChopSerial();
        const auto LandSerial = _Cutting.Get_LandSerial();
        const auto Started = Get_EventCount(EMars_TESTONLY_CuttingEvent::Started);
        const auto Landed = Get_EventCount(EMars_TESTONLY_CuttingEvent::Landed);
        const auto InFirstFrame = Get_EventsInFrame(Get_FirstNotifyFrame());
        const auto Line = f"[CuttingNetTest] ACopyBornIntoAChopRaisesOnlyItsLanding client: {Describe_Find()} serials {ChopSerial}/{LandSerial} node={Get_NodeHand()} hand={_Cutting.Get_HandLateral()} ensures {Get_NewEnsures()}";
        Log(Line);

        Assert_True(Get_CuttingInitialState() == EMars_Net_InitialState::Taken, "the client's copy took the state it was born into");
        Assert_True(_InitialAtFind == EMars_Net_InitialState::Awaited, "the client found its copy before its ledger's first application");
        Assert_True(Get_HasFirstNotify(), "the client recorded a rep-notify of its copy's ledger");
        Assert_Equals_Int(First.ChopSerial, 1, "the first notify carried the chop the station was born into");
        Assert_Equals_Int(Started, ChopSerial - First.ChopSerial, f"the client started only the chops after its first notify ({Describe_Find()})");
        Assert_Equals_Int(Landed, LandSerial - First.LandSerial, f"the client landed only the chops after its first notify ({Describe_Find()})");
        Assert_True(_Events.Num() > 0 && _Events[0] == EMars_TESTONLY_CuttingEvent::Landed, f"the first event the client raised is a landing ({Describe_Find()})");
        Assert_Equals_Int(InFirstFrame, 0, f"the client raised nothing in its first notify's frame ({Describe_Find()})");
        Assert_True(Get_IsNear(Get_NodeHand(), _Cutting.Get_HandLateral()), "the client's lateral node shows the ledger's hand");
        Assert_True(ChopSerial == 2 && LandSerial == 2, f"the client's ledger counts two chops (got {ChopSerial}/{LandSerial})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCuttingStationOfClass(k_Location, UMars_TESTONLY_NetCuttingStation_BornChopping_EntityScript);
        WaitUntil(n"Is_CuttingStationFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[CuttingNetTest] ACopyBornIntoAChopRaisesOnlyItsLanding server found: {Describe_Find()} serials {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()} chopping {_Cutting.Get_IsChopping()}";
        Log(Line);
        WaitSeconds(k_SettleSeconds, n"OnServerSecondChop");
    }

    UFUNCTION()
    private void OnServerSecondChop(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Cutting.Request_Chop(FMars_Request_Cutting_Chop());
        WaitUntil(n"Is_ServerTwoLanded", n"OnServerTwoLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTwoLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cutting.Get_LandSerial() >= 2 && _Cutting.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void OnServerTwoLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[CuttingNetTest] ACopyBornIntoAChopRaisesOnlyItsLanding server: {Describe_Find()} serials {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()} ensures {Get_NewEnsures()}";
        Log(Line);
        Assert_True(_Cutting.Get_ChopSerial() == 2 && _Cutting.Get_LandSerial() == 2,
            f"the server's ledger counts two chops (got {_Cutting.Get_ChopSerial()}/{_Cutting.Get_LandSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
