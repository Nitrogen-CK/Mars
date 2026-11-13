// The server engages its mortar directly, reports step 1 and watches 5 s. At step 1 the client reads its ledger, then asks
// its own copy directly for a press, a release, a switch, a collect, a disengage and an engage: 1.5 s later its ledger is
// unchanged, it raised nothing since, its station holds no mortar request, and it still reads engaged and Salt. At the end
// the server's mortar started no strike, has no hit, holds Salt, tallied nothing and is engaged.
// Surface: Ck.Mortar.Net.AS_Mortar_TheClientWroteNothing
class UCk_AutoTest_Net_Mortar_TheClientWroteNothing : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 450000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    // Client: what it read when it asked.
    private FString _LedgerBefore;
    private int32 _SignalsBefore = 0;

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
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Batch = _Mortar.Get_Batch();
        const auto Tally = _Mortar.Get_Tally();
        Assert_Equals_Int(_Mortar.Get_Ledger().StrikeSerial, 0, f"the server's mortar started no strike ({Describe_Mortar()})");
        Assert_Equals_Int(Batch.CrushHits, 0, "the server's batch has no hit");
        Assert_True(Batch.Seasoning == EMars_Mortar_Seasoning::Salt, "the server's batch is Salt");
        Assert_True(Tally.Get_Count(EMars_Mortar_Seasoning::Salt) == 0 && Tally.Get_Count(EMars_Mortar_Seasoning::Pepper) == 0, "the server tallied nothing");
        Assert_True(_Mortar.Get_IsEngaged(), "the server's mortar is engaged");
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        _LedgerBefore = Describe_Ledger(_Mortar.Get_Ledger());
        _SignalsBefore = _Signals.Num();

        _Mortar.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Press, Get_HitSweep()));
        _Mortar.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Release));
        _Mortar.Request_SwitchSeasoning(FMars_Request_Mortar_SwitchSeasoning());
        _Mortar.Request_Collect(FMars_Request_Mortar_Collect());
        _Mortar.Request_Disengage(FMars_Request_Mortar_Disengage());
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Describe_Ledger(_Mortar.Get_Ledger());
        Assert_True(Ledger == _LedgerBefore, f"the client's ledger is unchanged ({Ledger} was {_LedgerBefore})");
        Assert_Equals_Int(_Signals.Num(), _SignalsBefore, f"the client raised nothing since it asked ({Describe_Record()})");
        Assert_True(_Mortar.Has_Fragment(FMars_Fragment_Mortar_Requests) == false, "the client's station holds no mortar request");
        Assert_True(_Mortar.Get_IsEngaged(), "the client still reads engaged");
        Assert_True(_Mortar.Get_Batch().Seasoning == EMars_Mortar_Seasoning::Salt, "the client still reads Salt");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
