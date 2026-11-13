// The real searing station, nobody operating. The server admits the slab on a cold pan, reports (step 1) and watches 5 s.
// At step 1 the client reads both ledgers, then asks its own copy of the kernel to heat, ten looks of 3 degrees, a reset, a
// take-out naming its copy, a readopt of its copy, an admission of its copy and a station take-out: 1.5 s later both its
// ledgers are unchanged, it raised nothing since, its station holds no searing request, an empty inbox and no take-out
// queue, its pan's tilt stayed under 0.5 degrees and its pan is not Driven. At the end the server's pan is cold with one
// piece Cooking, its ledgers' serial and kick total are 0 and its pan is level.
// Surface: Ck.Searing.Net.AS_Searing_TheClientWroteNothing
class UCk_AutoTest_Net_Searing_TheClientWroteNothing : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 328000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const int32 k_LookCount = 10;

    private FMars_CookingFeed_PieceId _Id;

    // Client: what it read when it asked, and the first pan sample after.
    private FMars_Fragment_Searing_Net _LedgerBefore;
    private FMars_Fragment_Searing_PanNet _PanLedgerBefore;
    private int32 _SignalsBefore = 0;
    private int32 _SamplesBefore = 0;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Searing;
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
        return _HeatChanges.Num() + _PanAddedIds.Num() + _SearedIds.Num() + _PanTakeOutRefusals.Num() + _LostIds.Num();
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
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerOnBooks", n"OnServerOnBooks", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOnBooks(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_HasPiece(_Id));
    }

    UFUNCTION()
    private void OnServerOnBooks(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Searing.Get_Ledger();
        const auto Tilt = _Searing.Get_PanTilt();
        Assert_False(_Searing.Get_IsHot(), "the server's pan is cold");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "the server's pan holds one piece");
        Assert_True(_Searing.Get_HasPiece(_Id) && _Searing.Get_PieceStatus(_Id) == EMars_Searing_PieceStatus::Cooking, "the server's piece is Cooking");
        Assert_Equals_Int(Ledger.TakeOutRefusalSerial, 0, f"the server's ledger's serial is 0 ({Describe_SearingLedger()})");
        Assert_True(_Searing.Get_PanLedger().Pan.KickTotal == 0.0f, f"the server's pan ledger's kick total is 0 ({Describe_SearingLedger()})");
        Assert_True(Tilt.IsNearlyZero(0.001), f"the server's pan is level (tilt {Tilt})");
        End_HeatServer(f"{Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        _LedgerBefore = _Searing.Get_Ledger();
        _PanLedgerBefore = _Searing.Get_PanLedger();
        _SignalsBefore = Get_SignalCount();
        _SamplesBefore = _PanSamples.Num();
        const auto Copy = Get_FollowedCopy(0);
        const auto Id = _LedgerBefore.Pieces.Num() > 0 ? _LedgerBefore.Pieces[0].Id : FMars_CookingFeed_PieceId();
        Assert_True(Get_IsLive(Copy), "the client has its copy of the piece");

        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
        for (int32 Index = 0; Index < k_LookCount; ++Index)
        { _Searing.Request_Look(FMars_Request_Searing_Look(FVector(3.0, 0.0, 0.0))); }

        _Searing.Request_Reset(FMars_Request_Searing_Reset());
        _Searing.Request_TakeOut(FMars_Request_Searing_TakeOut(TOptional<FCk_Handle_FoodPiece>(Copy), TOptional<int32>()));
        _Searing.Request_Readopt(FMars_Request_Searing_Readopt(Id, Copy));
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
        const auto Ledger = _Searing.Get_Ledger();
        const auto PanLedger = _Searing.Get_PanLedger();
        const auto Inbox = _Station.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Num();
        auto LargestRoll = 0.0f;
        for (int32 Index = _SamplesBefore; Index < _PanSamples.Num(); ++Index)
        { LargestRoll = Math::Max(LargestRoll, Math::Abs(_PanSamples[Index].Roll)); }

        const auto Tilt = _Searing.Get_PanTilt();
        const auto LargestTilt = Math::Max(LargestRoll, float32(Math::Max(Math::Abs(Tilt.Pitch), Math::Abs(Tilt.Roll))));
        Assert_True(utils_searing::Get_IsSameLedger(Ledger, _LedgerBefore), f"the client's kernel ledger is unchanged ({Describe_SearingLedger()})");
        Assert_True(Get_IsSameCommand(PanLedger.Pan, _PanLedgerBefore.Pan), f"the client's pan ledger is unchanged ({Describe_SearingLedger()})");
        Assert_Equals_Int(Get_SignalCount(), _SignalsBefore, f"the client raised nothing since it asked ({Describe_SearingRecord()})");
        Assert_False(_Station.Has_Fragment(FMars_Fragment_Searing_Requests), "the client's station holds no searing request");
        Assert_Equals_Int(Inbox, 0, "the client's inbox is empty");
        Assert_False(_Station.Has_Fragment(FMars_Fragment_StationTakeOut_Requests), "the client's station has no take-out queue");
        Assert_True(LargestTilt < 0.5f, f"the client's pan's tilt stayed under 0.5 degrees (largest {LargestTilt})");
        Assert_False(_Searing.Get_Pan().Get_IsDriven(), "the client's pan is not Driven");
        End_HeatClient(f"largestTilt={LargestTilt} inbox={Inbox} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    private bool Get_IsSameCommand(FMars_Implement_Command InA, FMars_Implement_Command InB)
    {
        return InA.Drive == InB.Drive && InA.Tilt.Equals(InB.Tilt, 0.0) && InA.Lift == InB.Lift && InA.Slide == InB.Slide
            && InA.KickTotal == InB.KickTotal && InA.OrbitPhase == InB.OrbitPhase;
    }
}
