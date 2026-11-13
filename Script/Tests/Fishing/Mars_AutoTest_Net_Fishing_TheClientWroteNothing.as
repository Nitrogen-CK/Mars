// The server engages its spot directly, reports step 1 and watches 5 s. At step 1 the client reads its ledger, then asks its
// own copy directly to aim, cast, force a bite, strike, hold the reel, force a landing, collect, leave, reset and disengage:
// 1.5 s later its ledger is unchanged, it raised nothing since, its station holds no fishing request, and it reads engaged
// and Idle. At the end the server's spot reads Idle with no cast, no tally and its aim at 0, and no world item lies within
// 1000 cm of the spot.
// Surface: Ck.Fishing.Net.AS_Fishing_TheClientWroteNothing
class UCk_AutoTest_Net_Fishing_TheClientWroteNothing : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 470000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const float64 k_NearCm = 1000.0;

    // Client: what it read when it asked.
    private FString _LedgerBefore;
    private int32 _SignalsBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    protected void On_ServerStationReady() override
    {
        _Fishing.Request_Engage(FMars_Request_Fishing_Engage());
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Aim = _Fishing.Get_Aim();
        const auto Items = Count_WorldItemsNear(Get_StationLocation(), k_NearCm);
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, f"the server's spot reads Idle ({Describe_Fishing()})");
        Assert_Equals_Int(_Fishing.Get_Ledger().CastSerial, 0, f"the server's spot never cast ({Describe_Fishing()})");
        Assert_Equals_Int(_Fishing.Get_Tally(), 0, "the server tallied nothing");
        Assert_True(Aim.YawDeg == 0.0f && Aim.PitchDeg == 0.0f, f"the server's aim stands at 0 ({Aim.YawDeg}/{Aim.PitchDeg})");
        Assert_Equals_Int(Items, 0, f"no world item lies near the server's spot ({Items})");
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        _LedgerBefore = Describe_Ledger(_Fishing.Get_Ledger());
        _SignalsBefore = _Signals.Num();

        _Fishing.Request_Aim(FMars_Request_Fishing_Aim(20.0f, 5.0f));
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
        _Fishing.Request_ForceBite(FMars_Request_Fishing_ForceBite());
        _Fishing.Request_Hook(FMars_Request_Fishing_Hook());
        _Fishing.Request_ReelHold(FMars_Request_Fishing_ReelHold());
        _Fishing.Request_ForceLand(FMars_Request_Fishing_ForceLand());
        _Fishing.Request_Collect(FMars_Request_Fishing_Collect());
        _Fishing.Request_Leave(FMars_Request_Fishing_Leave());
        _Fishing.Request_Reset(FMars_Request_Fishing_Reset());
        _Fishing.Request_Disengage(FMars_Request_Fishing_Disengage());
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Describe_Ledger(_Fishing.Get_Ledger());
        Assert_True(Ledger == _LedgerBefore, f"the client's ledger is unchanged ({Ledger} was {_LedgerBefore})");
        Assert_Equals_Int(_Signals.Num(), _SignalsBefore, f"the client raised nothing since it asked ({Describe_Record()})");
        Assert_True(_Fishing.Has_Fragment(FMars_Fragment_Fishing_Requests) == false, "the client's station holds no fishing request");
        Assert_True(_Fishing.Get_IsEngaged(), f"the client still reads engaged ({Describe_Fishing()})");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, f"the client still reads Idle ({Describe_Fishing()})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
