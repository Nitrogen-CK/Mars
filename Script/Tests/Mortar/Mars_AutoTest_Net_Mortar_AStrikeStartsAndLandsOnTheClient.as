// The server engages its mortar and strikes a hit directly; once it has landed it reports. The client raised
// OnStrikeStarted once, then OnStrikeLanded once with Hit, then OnBatchChanged once with one hit, in that order, and its
// label says "crush 1/2".
// Surface: Ck.Mortar.Net.AS_Mortar_AStrikeStartsAndLandsOnTheClient
class UCk_AutoTest_Net_Mortar_AStrikeStartsAndLandsOnTheClient : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 441000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    protected void On_ServerStationReady() override
    {
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
        Hit_Directly();
        WaitUntil(n"Is_ServerLanded", n"OnServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Landings.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Landings[0] == EMars_Mortar_Strike::Hit, f"the server's strike landed a hit ({Describe_Record()})");
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Label = Get_Label();
        const auto IsInOrder = _Signals.Num() == 3 && _Signals[0] == EMars_TESTONLY_NetMortarSignal::StrikeStarted
            && _Signals[1] == EMars_TESTONLY_NetMortarSignal::StrikeLanded && _Signals[2] == EMars_TESTONLY_NetMortarSignal::BatchChanged;
        Assert_True(IsInOrder, f"the client raised started, landed, batch changed once each in that order ({Describe_Record()})");
        Assert_True(_Landings.Num() == 1 && _Landings[0] == EMars_Mortar_Strike::Hit, f"the client's landing was a hit ({Describe_Record()})");
        Assert_True(_Batches.Num() == 1 && _Batches[0].CrushHits == 1, f"the client's batch broadcast carried one hit ({Describe_Record()})");
        Assert_True(Label.Contains("crush 1/2"), f"the client's label says crush 1/2 ('{Label}')");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
