// The real tumbler station, nobody operating. The server crumbs a slab to 0.5, points at the shut hatch and opens it, admits
// the slab and, once it is in the drum, points at the open hatch and closes it; once the hatch is Closed it reports (step 1).
// It points at the lever, grips it, rocks it for 2 s (one look a frame along the pull, its sign flipping every 20 frames),
// lets go, and once the drum is Home reports the slab's coverage (step 2). At step 1 the client reads the slab's coverage
// 0.5; at step 2 its coverage is at most 0.1 below the reported one and never above it, and the first row's coverage it
// sampled never went down.
// Surface: Ck.Tumbler.Net.AS_Tumbler_TheCoverageReachesTheClient
class UCk_AutoTest_Net_Tumbler_TheCoverageReachesTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 383000.0;
    private const float32 k_SeedCrumb = 0.5f;
    private const float32 k_LedgerStep = 0.1f;
    private const float32 k_Exact = 0.001f;
    private const float32 k_RockSeconds = 2.0f;
    private const float64 k_RockDegrees = 2.0;
    private const int32 k_RockHalfCycleFrames = 20;

    private FMars_CookingFeed_PieceId _Id;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Tumbler;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_HeatStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Spawn_FoodsThen(mars_items::Food_MeatSlab(), 1, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TArray<FCk_Handle_FoodPiece> Pieces;
        Pieces.Add(_Foods[0].As_FoodPiece());
        Crumb_Then(Pieces, k_SeedCrumb, n"OnServerCrumbed");
    }

    UFUNCTION()
    private void OnServerCrumbed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointedShut");
    }

    UFUNCTION()
    private void OnServerPointedShut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        WaitUntil(n"Is_ServerOpen", n"OnServerOpen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Open);
    }

    UFUNCTION()
    private void OnServerOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_HasPiece(_Id));
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointedOpen");
    }

    UFUNCTION()
    private void OnServerPointedOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        WaitUntil(n"Is_ServerClosed", n"OnServerClosed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Closed);
    }

    UFUNCTION()
    private void OnServerClosed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Point_AtThen(EMars_Tumbler_Target::Lever, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointedLever");
    }

    UFUNCTION()
    private void OnServerPointedLever(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        WaitUntil(n"Is_ServerGripped", n"OnServerGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Gripped && _Tumbler.Get_Drum() == EMars_Tumbler_Drum::Gripped);
    }

    UFUNCTION()
    private void OnServerGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("rock");
        auto Rock = FMars_TESTONLY_NetTumblerRock();
        Rock.Seconds = k_RockSeconds;
        Rock.Degrees = k_RockDegrees;
        Rock.HalfCycleFrames = k_RockHalfCycleFrames;
        Rock.Look = EMars_TESTONLY_NetTumblerLook::Kernel;
        Rock_LeverThen(Rock, n"OnServerRocked");
    }

    UFUNCTION()
    private void OnServerRocked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Tumbler.Request_Release(FMars_Request_Tumbler_Release());
        WaitUntil(n"Is_ServerHome", n"OnServerHome", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home);
    }

    UFUNCTION()
    private void OnServerHome(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        _ReportValue = _Tumbler.Get_PieceCoverage(_Id);
        Report_HeatStep(2);
        End_HeatServer(f"coverage={_ReportValue} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // The first row's coverage never went down across this machine's samples.
    private bool Get_NeverFell(FString& OutWhere)
    {
        auto Highest = -1.0f;
        auto IsMonotonic = true;
        for (int32 Index = 0; Index < _MoverSamples.Num(); ++Index)
        {
            const auto Coverage = _MoverSamples[Index].FirstCoverage;
            if (Coverage < 0.0f)
            { continue; }

            if (Coverage < Highest)
            {
                IsMonotonic = false;
                OutWhere = f"sample {Index}: {Highest}->{Coverage}";
            }

            Highest = Math::Max(Highest, Coverage);
        }

        return IsMonotonic;
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        const auto Report = Get_HeatStationReport();
        _Id = Report.BowlIds.Num() > 0 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();
        const auto HasPiece = _Tumbler.Get_HasPiece(_Id);
        const auto Coverage = HasPiece ? _Tumbler.Get_PieceCoverage(_Id) : -1.0f;
        if (InStep == 1)
        {
            Assert_True(HasPiece && Math::Abs(Coverage - k_SeedCrumb) <= k_Exact, f"at step 1 the client reads the slab's coverage 0.5 (got {Coverage}, {Describe_TumblerLedger()})");
            Await_Step(2);
            return;
        }

        FString FellAt = "";
        const auto NeverFell = Get_NeverFell(FellAt);
        Assert_True(HasPiece && Coverage >= Report.Value - k_LedgerStep - k_Exact && Coverage <= Report.Value + k_Exact,
            f"at step 2 the client's coverage is at most a tenth below the server's and never above it (client {Coverage}, server {Report.Value})");
        Assert_True(NeverFell, f"the client's coverage never went down ({FellAt})");
        End_HeatClient(f"coverage={Coverage} reported={Report.Value} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
