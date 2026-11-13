// The real tumbler station, nobody operating. The server points at the shut hatch and opens it, admits a slab and, once it
// is in the drum, reports (step 1) and watches 5 s. At step 1 the client reads both ledgers, then asks its own copy of the
// kernel for ten looks, a press, a release, a cancel, a reset and a readopt of its copy, and its station for an admission of
// its copy and a take-out: 1.5 s later both ledgers are unchanged, it raised nothing since, its station holds no tumbler
// request, an empty inbox and no take-out queue, its hinge and axle Movers moved less than 0.005 and its copy of the slab is
// still there. At the end the server's hatch is Open, its drum Home, its hand Free, it holds one piece and both refusal
// serials of its ledger are 0.
// Surface: Ck.Tumbler.Net.AS_Tumbler_TheClientWroteNothing
class UCk_AutoTest_Net_Tumbler_TheClientWroteNothing : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 388000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const int32 k_LookCount = 10;
    private const float32 k_StillAlpha = 0.005f;

    // Client: what it read when it asked, and the samples it had then.
    private FMars_Fragment_Tumbler_Net _LedgerBefore;
    private FMars_Fragment_Tumbler_MotionNet _MotionBefore;
    private int32 _SignalsBefore = 0;
    private int32 _SamplesBefore = 0;

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

    private int32 Get_SignalCount()
    {
        return _HatchChanges.Num() + _HoverChanges.Num() + _DrumChanges.Num() + _HandModeChanges.Num() + _PressRefusals.Num()
            + _TumblerTakeOutRefusals.Num() + _TumblerAddedIds.Num();
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
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointed");
    }

    UFUNCTION()
    private void OnServerPointed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_PieceIds().Num() == 1);
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Tumbler.Get_Ledger();
        Assert_True(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Open, "the server's hatch is Open");
        Assert_True(_Tumbler.Get_Drum() == EMars_Tumbler_Drum::Home, "the server's drum is Home");
        Assert_True(_Tumbler.Get_HandMode() == EMars_Tumbler_HandMode::Free, "the server's hand is Free");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 1, "the server holds one piece");
        Assert_True(Ledger.PressRefusalSerial == 0 && Ledger.TakeOutRefusalSerial == 0, f"both refusal serials of the server's ledger are 0 ({Describe_TumblerLedger()})");
        End_HeatServer(f"{Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        _LedgerBefore = _Tumbler.Get_Ledger();
        _MotionBefore = _Tumbler.Get_MotionLedger();
        _SignalsBefore = Get_SignalCount();
        _SamplesBefore = _MoverSamples.Num();
        const auto Copy = Get_FollowedCopy(0);
        const auto Id = _LedgerBefore.Pieces.Num() > 0 ? _LedgerBefore.Pieces[0].Id : FMars_CookingFeed_PieceId();
        Assert_True(Get_IsLive(Copy), "the client has its copy of the slab");

        for (int32 Index = 0; Index < k_LookCount; ++Index)
        { _Tumbler.Request_Look(FMars_Request_Tumbler_Look(FVector(3.0, 0.0, 0.0))); }

        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        _Tumbler.Request_Release(FMars_Request_Tumbler_Release());
        _Tumbler.Request_Cancel(FMars_Request_Tumbler_Cancel());
        _Tumbler.Request_Reset(FMars_Request_Tumbler_Reset());
        _Tumbler.Request_Readopt(FMars_Request_Tumbler_Readopt(Id, Copy));
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
        const auto Ledger = _Tumbler.Get_Ledger();
        const auto Motion = _Tumbler.Get_MotionLedger();
        const auto Inbox = _Station.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Num();
        const auto Copy = Get_FollowedCopy(0);
        FString MovedAt = "";
        const auto IsStill = Get_AreMoversStill(_SamplesBefore, k_StillAlpha, MovedAt);
        const auto Rotation = Motion.HandRotationLocal;
        const auto RotationBefore = _MotionBefore.HandRotationLocal;
        const auto IsSameMotion = Motion.DrumAlpha == _MotionBefore.DrumAlpha && Motion.HandLocal == _MotionBefore.HandLocal
            && Rotation.X == RotationBefore.X && Rotation.Y == RotationBefore.Y && Rotation.Z == RotationBefore.Z && Rotation.W == RotationBefore.W;
        Assert_True(utils_tumbler::Get_IsSameLedger(Ledger, _LedgerBefore), f"the client's kernel ledger is unchanged ({Describe_TumblerLedger()})");
        Assert_True(IsSameMotion, f"the client's motion ledger is unchanged ({Describe_TumblerLedger()})");
        Assert_Equals_Int(Get_SignalCount(), _SignalsBefore, f"the client raised nothing since it asked ({Describe_TumblerRecord()})");
        Assert_False(_Station.Has_Fragment(FMars_Fragment_Tumbler_Requests), "the client's station holds no tumbler request");
        Assert_Equals_Int(Inbox, 0, "the client's inbox is empty");
        Assert_False(_Station.Has_Fragment(FMars_Fragment_StationTakeOut_Requests), "the client's station has no take-out queue");
        Assert_True(IsStill, f"the client's hinge and axle Movers did not move ({MovedAt})");
        Assert_True(Get_IsLive(Copy), "the client's copy of the slab is still there");
        End_HeatClient(f"inbox={Inbox} still={IsStill} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
