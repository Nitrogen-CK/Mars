// The client predicts its hand (PredictHand): its own lateral node shows the prediction within a frame or two. The server
// then nudges the ledger's hand elsewhere: the client's ledger follows, but its node stays on the prediction. Clearing the
// prediction returns the node to the ledger's hand.
// Surface: Ck.Cutting.Net.AS_Cutting_TheOperatorsOwnHandIsPredicted
class UCk_AutoTest_Net_Cutting_TheOperatorsOwnHandIsPredicted : UMars_AutoTestRig_NetCutting
{
    private const FVector k_Location = FVector(113000.0, 0.0, 5000.0);
    private const float32 k_PredictedCm = 12.0f;
    private const float32 k_LedgerCm = 20.0f;
    // The node shows a prediction, or the ledger after a clear, within this many polls of the request.
    private const int32 k_MaxFramesToShow = 2;
    // Frames the client watches its node stay on the prediction once the ledger moved.
    private const int32 k_StandFrames = 10;
    private const float32 k_ServerLeadSeconds = 2.0f;
    private const float32 k_ServerWindowSeconds = 4.0f;

    private int32 _PollFrames = 0;
    private int32 _FramesToPredict = 0;
    private int32 _FramesToClear = 0;
    private float32 _NodeWhileLedgerMoved = 0.0f;

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
        _PollFrames = 0;
        _Cutting.Request_PredictHand(FMars_Request_Cutting_PredictHand(k_PredictedCm));
        WaitUntil(n"Is_NodeOnPrediction", n"OnClientNodeOnPrediction", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_NodeOnPrediction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _PollFrames += 1;
        Result.Set(Get_IsCuttingStationFound() && Get_IsNear(Get_NodeHand(), k_PredictedCm));
    }

    UFUNCTION()
    private void OnClientNodeOnPrediction(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _FramesToPredict = _PollFrames;
        WaitUntil(n"Is_LedgerMoved", n"OnClientLedgerMoved", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_LedgerMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCuttingStationFound() && Get_IsNear(_Cutting.Get_HandLateral(), k_LedgerCm));
    }

    UFUNCTION()
    private void OnClientLedgerMoved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_StandFrames, n"OnClientPredictionStood");
    }

    UFUNCTION()
    private void OnClientPredictionStood(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _NodeWhileLedgerMoved = Get_NodeHand();
        _PollFrames = 0;
        _Cutting.Request_ClearPrediction(FMars_Request_Cutting_ClearPrediction());
        WaitUntil(n"Is_NodeOnLedger", n"OnClientNodeOnLedger", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_NodeOnLedger(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _PollFrames += 1;
        Result.Set(Get_IsCuttingStationFound() && Get_IsNear(Get_NodeHand(), k_LedgerCm));
    }

    UFUNCTION()
    private void OnClientNodeOnLedger(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _FramesToClear = _PollFrames;
        Log(f"[CuttingNetTest] TheOperatorsOwnHandIsPredicted client: node on the prediction after {_FramesToPredict} polls, node {_NodeWhileLedgerMoved} while the ledger read {k_LedgerCm}, node on the ledger {_FramesToClear} polls after the clear, prediction set {_Cutting.TryGet_PredictedHand().IsSet()}, ensures {Get_NewEnsures()}");
        Assert_True(_FramesToPredict <= k_MaxFramesToShow, f"the node shows the prediction within {k_MaxFramesToShow} frames (took {_FramesToPredict})");
        Assert_True(Get_IsNear(_NodeWhileLedgerMoved, k_PredictedCm), f"a later ledger value does not move the node while the prediction stands (node {_NodeWhileLedgerMoved})");
        Assert_True(_FramesToClear <= k_MaxFramesToShow, f"the node returns to the ledger within {k_MaxFramesToShow} frames of the clear (took {_FramesToClear})");
        Assert_True(_Cutting.TryGet_PredictedHand().IsSet() == false, "the prediction is cleared");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCuttingStation(k_Location);
        WaitUntil(n"Is_CuttingStationFound", n"OnServerFound", k_SlowPolls);
    }

    // The lead gives the client time to compose and predict before the ledger moves.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerLeadSeconds, n"OnServerNudge");
    }

    UFUNCTION()
    private void OnServerNudge(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge(k_LedgerCm));
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] TheOperatorsOwnHandIsPredicted server: hand {_Cutting.Get_HandLateral()}, node {Get_NodeHand()}, ensures {Get_NewEnsures()}");
        Assert_True(Get_IsNear(_Cutting.Get_HandLateral(), k_LedgerCm) && Get_IsNear(Get_NodeHand(), k_LedgerCm),
            f"the server's hand and node are at {k_LedgerCm} (got {_Cutting.Get_HandLateral()}, {Get_NodeHand()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
