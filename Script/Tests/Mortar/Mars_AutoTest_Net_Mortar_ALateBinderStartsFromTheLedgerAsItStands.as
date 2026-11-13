// In the continuation in which the server first finds its station it engages and strikes a hit directly; once that has
// landed it holds 4 s, strikes a second hit, and reports once that has landed. The client starts counting what its copy
// raises only once its ledger reads one landing and one hit (a listener that arrives after them): its batch then shows one
// hit and it reads engaged; from then on it raises OnStrikeStarted, OnStrikeLanded and OnBatchChanged once each, and its
// batch reads Grind.
// Surface: Ck.Mortar.Net.AS_Mortar_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Mortar_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 449000.0;
    private const float32 k_HoldBeforeSecondHitSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientLedgerOneHit", n"OnClientLedgerOneHit", k_SlowPolls); }
    }

    protected EMars_TESTONLY_NetMinigameFound On_ServerStationFound() override
    {
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
        Hit_Directly();
        WaitUntil(n"Is_ServerLandedOnce", n"OnServerLandedOnce", k_SlowPolls);
        return EMars_TESTONLY_NetMinigameFound::TestContinues;
    }

    UFUNCTION()
    private void Is_ServerLandedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Landings.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerLandedOnce(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_HoldBeforeSecondHitSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hit_Directly();
        WaitUntil(n"Is_ServerLandedTwice", n"OnServerLandedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLandedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Landings.Num() >= 2);
    }

    UFUNCTION()
    private void OnServerLandedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    UFUNCTION()
    private void Is_ClientLedgerOneHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Try_FindStation() == false)
        {
            Result.Set(false);
            return;
        }

        const auto Ledger = _Mortar.Get_Ledger();
        Result.Set(Ledger.LandedSerial == 1 && Ledger.Batch.CrushHits == 1);
    }

    // The listener arrives now: what its copy raised before is not its to count.
    UFUNCTION()
    private void OnClientLedgerOneHit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Minigame(f"before the clear: {Describe_Record()} foundFrame={_StationFoundFrame} now={utils_time::Get_FrameCounter()}");
        Clear_Record();
        Assert_Equals_Int(_Mortar.Get_Batch().CrushHits, 1, f"the client's batch shows one hit as it starts counting ({Describe_Mortar()})");
        Assert_True(_Mortar.Get_IsEngaged(), "the client reads engaged as it starts counting");
        Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::StrikeStarted), 1, f"the client raised OnStrikeStarted once since it started counting ({Describe_Record()})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::StrikeLanded), 1, f"the client raised OnStrikeLanded once since it started counting ({Describe_Record()})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::BatchChanged), 1, f"the client raised OnBatchChanged once since it started counting ({Describe_Record()})");
        Assert_True(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Grind, f"the client's batch reads Grind ({Describe_Mortar()})");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
