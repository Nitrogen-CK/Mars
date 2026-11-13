// In the continuation in which the server first finds its station it engages and casts directly; once Waiting it forces a
// bite and strikes; it holds 4 s, forces the landing and reports once its spot reads Landed. The client starts counting
// what its copy raises only once its ledger reads Reeling with one cast (a listener that arrives after them): its bait then
// lies within 5 cm of the ledger's and it has a line out; from then on it raises OnLanded once and OnCast, OnBite and
// OnBiteEnded never.
// Surface: Ck.Fishing.Net.AS_Fishing_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Fishing_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 468000.0;
    private const float32 k_HoldSeconds = 4.0f;
    private const float64 k_MaxBaitErrorCm = 5.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientLedgerReeling", n"OnClientLedgerReeling", k_SlowPolls); }
    }

    protected EMars_TESTONLY_NetMinigameFound On_ServerStationFound() override
    {
        _Fishing.Request_Engage(FMars_Request_Fishing_Engage());
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
        Await_Phase(EMars_Fishing_Phase::Waiting, n"OnServerWaiting");
        return EMars_TESTONLY_NetMinigameFound::TestContinues;
    }

    UFUNCTION()
    private void OnServerWaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_ForceBite(FMars_Request_Fishing_ForceBite());
        _Fishing.Request_Hook(FMars_Request_Fishing_Hook());
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_ForceLand(FMars_Request_Fishing_ForceLand());
        Await_Phase(EMars_Fishing_Phase::Landed, n"OnServerLanded");
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    UFUNCTION()
    private void Is_ClientLedgerReeling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Try_FindStation() == false)
        {
            Result.Set(false);
            return;
        }

        const auto Ledger = _Fishing.Get_Ledger();
        Result.Set(Ledger.Phase == EMars_Fishing_Phase::Reeling && Ledger.CastSerial == 1);
    }

    // The listener arrives now: what its copy raised before is not its to count.
    UFUNCTION()
    private void OnClientLedgerReeling(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Minigame(f"before the clear: {Describe_Record()} foundFrame={_StationFoundFrame} now={utils_time::Get_FrameCounter()}");
        Clear_Record();
        const auto Bait = _Fishing.Get_Bait().Position;
        const auto Expected = _Fishing.Get_Ledger().BaitPosition;
        Assert_True(Bait.Distance(Expected) <= k_MaxBaitErrorCm, f"the client's bait lies on the ledger's ({Bait} vs {Expected})");
        Assert_True(_Fishing.Get_HasLineOut(), f"the client has a line out as it starts counting ({Describe_Fishing()})");
        Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnLanded), 1, f"the client raised OnLanded once since it started counting ({Describe_Record()})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnCast), 0, f"the client raised no OnCast since it started counting ({Describe_Record()})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnBite), 0, f"the client raised no OnBite since it started counting ({Describe_Record()})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnBiteEnded), 0, f"the client raised no OnBiteEnded since it started counting ({Describe_Record()})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
