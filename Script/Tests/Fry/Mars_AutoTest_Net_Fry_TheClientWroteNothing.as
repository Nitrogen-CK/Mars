// The real fry station, nobody operating, its faces too slow to change a tenth of heat while the test runs. The server
// batters a slab and admits it; once it is in the oil it reports (step 1) and watches 5 s. At step 1 the client reads both
// ledgers, then asks its own copy of the kernel to drive, to dip, ten looks of 3 degrees, a reset, a take-out naming its
// copy, a readopt of its copy, an admission of its copy and a station take-out: 1.5 s later both its ledgers are unchanged,
// it raised nothing since, its station holds no fry request, an empty inbox and no take-out queue, and its scoop moved less
// than 0.5 cm. At the end the server's skimmer is Idle, carrying, its target at its park, it holds one piece and every
// serial of its ledger is 0.
// Surface: Ck.Fry.Net.AS_Fry_TheClientWroteNothing
class UCk_AutoTest_Net_Fry_TheClientWroteNothing : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 368000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const int32 k_LookCount = 10;
    // Seconds from pale to golden: a face heats less than a tenth while the test runs.
    private const float32 k_GoldenSeconds = 1000.0f;
    private const float64 k_StillCm = 0.5;

    private FMars_CookingFeed_PieceId _Id;

    // Client: what it read when it asked, and the scoop samples it had then.
    private FMars_Fragment_Fry_Net _LedgerBefore;
    private FMars_Fragment_Fry_SkimmerNet _SkimmerBefore;
    private int32 _SignalsBefore = 0;
    private int32 _SamplesBefore = 0;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
    }

    protected FMars_Fry_Spec Make_FrySpec() const override
    {
        auto Spec = FMars_Fry_Spec();
        Spec.Heat.GoldenSeconds = k_GoldenSeconds;
        return Spec;
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

    private int32 Get_SignalCount()
    {
        return _SkimChanges.Num() + _FryAddedIds.Num() + _SkimRefusals.Num() + _FryTakeOutRefusals.Num()
            + _FryAdmissionRefusals.Num() + _Stages.Num() + _DrainedIds.Num();
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
        TArray<FCk_Handle_FoodPiece> Battered;
        Battered.Add(_Foods[0].As_FoodPiece());
        Batter_Then(Battered, n"OnServerBattered");
    }

    UFUNCTION()
    private void OnServerBattered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerInOil", n"OnServerInOil", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerInOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsInOil(_Id));
    }

    UFUNCTION()
    private void OnServerInOil(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Fry.Get_Ledger();
        const auto Park = _Fry.Get_SkimmerPark();
        Assert_True(_Fry.Get_Drive() == EMars_Implement_Drive::Idle, "the server's skimmer is Idle");
        Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Carry, "the server's skimmer carries");
        Assert_True((_Fry.Get_SkimmerTarget() - Park).Size() < 0.001, f"the server's target is at its park (target {_Fry.Get_SkimmerTarget()}, park {Park})");
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 1, "the server holds one piece");
        Assert_True(Ledger.SkimRefusalSerial == 0 && Ledger.TakeOutRefusalSerial == 0 && Ledger.AdmissionRefusalSerial == 0,
            f"every serial of the server's ledger is 0 ({Describe_FryLedger()})");
        End_HeatServer(f"{Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        _LedgerBefore = _Fry.Get_Ledger();
        _SkimmerBefore = _Fry.Get_SkimmerLedger();
        _SignalsBefore = Get_SignalCount();
        _SamplesBefore = _ScoopSamples.Num();
        const auto Copy = Get_FollowedCopy(0);
        const auto Id = _LedgerBefore.Pieces.Num() > 0 ? _LedgerBefore.Pieces[0].Id : FMars_CookingFeed_PieceId();
        Assert_True(Get_IsLive(Copy), "the client has its copy of the piece");

        _Fry.Request_SetDrive(FMars_Request_Fry_SetDrive(EMars_Implement_Drive::Driven));
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Dip));
        for (int32 Index = 0; Index < k_LookCount; ++Index)
        { _Fry.Request_Look(FMars_Request_Fry_Look(FVector(3.0, 0.0, 0.0))); }

        _Fry.Request_Reset(FMars_Request_Fry_Reset());
        _Fry.Request_TakeOut(FMars_Request_Fry_TakeOut(TOptional<FCk_Handle_FoodPiece>(Copy), TOptional<int32>()));
        _Fry.Request_Readopt(FMars_Request_Fry_Readopt(Id, Copy));
        auto Station = _Station;
        auto Release = FMars_CookingFeed_Release(FMars_CookingFeed_PieceId(constants_heat_station_net_autotest::k_RigGeneration, 50),
            utils_transform::Get_EntityCurrentTransform(_Feed.Get_ReleaseNode()), FVector::ZeroVector);
        Release.Piece = Copy;
        utils_cooking_feed::Request_Admit(Station, Release);
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(4, FCk_Handle_Platter()));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Fry.Get_Ledger();
        const auto Skimmer = _Fry.Get_SkimmerLedger();
        const auto Inbox = _Station.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Num();
        auto LargestMove = 0.0;
        if (_SamplesBefore < _ScoopSamples.Num())
        {
            const auto From = _ScoopSamples[_SamplesBefore].Root;
            for (int32 Index = _SamplesBefore; Index < _ScoopSamples.Num(); ++Index)
            { LargestMove = Math::Max(LargestMove, _ScoopSamples[Index].Root.Distance(From)); }
        }

        const auto IsSameSkimmer = Skimmer.Drive == _SkimmerBefore.Drive && Skimmer.Skim == _SkimmerBefore.Skim && Skimmer.Target == _SkimmerBefore.Target;
        Assert_True(utils_fry::Get_IsSameLedger(Ledger, _LedgerBefore), f"the client's kernel ledger is unchanged ({Describe_FryLedger()})");
        Assert_True(IsSameSkimmer, f"the client's skimmer ledger is unchanged ({Describe_FryLedger()})");
        Assert_Equals_Int(Get_SignalCount(), _SignalsBefore, f"the client raised nothing since it asked ({Describe_FryRecord()})");
        Assert_False(_Station.Has_Fragment(FMars_Fragment_Fry_Requests), "the client's station holds no fry request");
        Assert_Equals_Int(Inbox, 0, "the client's inbox is empty");
        Assert_False(_Station.Has_Fragment(FMars_Fragment_StationTakeOut_Requests), "the client's station has no take-out queue");
        Assert_True(LargestMove < k_StillCm, f"the client's scoop moved less than 0.5 cm (largest {LargestMove})");
        End_HeatClient(f"largestMove={LargestMove} inbox={Inbox} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }
}
