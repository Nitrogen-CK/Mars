// An empty tray docked on the Output dock and one bare piece in the bowl; the server reports (step 1) and watches 5 s. At
// step 1 the client reads its ledger, then asks its own copy for a dip, a lift, a reset, a readopt of its copy, a station
// take-out onto its tray and an admission of its copy: 1.5 s later its ledger is unchanged, it raised nothing since, its
// station holds no bowl request, an empty inbox and no take-out queue, and its copy hangs under its bowl at rest. At the end
// the server's bowl is Resting with one piece at coat 0, its ledger's serials are 0 and its tray is empty.
// Surface: Ck.Batter.Net.AS_Batter_TheClientWroteNothing
class UCk_AutoTest_Net_Batter_TheClientWroteNothing : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 307000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    private FMars_CookingFeed_PieceId _Id;
    // Client: what it read when it asked.
    private FMars_Fragment_Batter_Net _LedgerBefore;
    private int32 _SignalsBefore = 0;

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
        return _BowlChanges.Num() + _AddedIds.Num() + _AdmissionRefusals.Num() + _TakeOutRefusals.Num() + _TakenOutIds.Num();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Spawn_FoodsThen(mars_items::Food_Mushroom(), 1, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Dock_TrayThen(n"OnServerTrayDocked");
    }

    UFUNCTION()
    private void OnServerTrayDocked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_HasPiece(_Id));
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
        const auto Ledger = _Batter.Get_Ledger();
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting, "the server's bowl is Resting");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 1, "the server's bowl holds one piece");
        Assert_True(_Batter.Get_HasPiece(_Id) && _Batter.Get_PieceCoat(_Id) == 0.0f, "the server's piece is at coat 0");
        Assert_True(Ledger.BowlSerial == 0 && Ledger.AdmissionRefusalSerial == 0 && Ledger.TakeOutRefusalSerial == 0,
            f"the server's ledger's serials are 0 ({Describe_BatterLedger()})");
        Assert_Equals_Int(_Tray.Get_HeldCount(), 0, "the server's tray is empty");
        End_HeatServer(f"tray={_Tray.Get_HeldCount()} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        _LedgerBefore = _Batter.Get_Ledger();
        _SignalsBefore = Get_SignalCount();
        const auto Copy = Get_FollowedCopy(0);
        const auto Id = _LedgerBefore.Pieces.Num() > 0 ? _LedgerBefore.Pieces[0].Id : FMars_CookingFeed_PieceId();
        Assert_True(Try_FindTray(), "the client finds its tray");

        _Batter.Request_Dip(FMars_Request_Batter_Dip());
        _Batter.Request_Lift(FMars_Request_Batter_Lift());
        _Batter.Request_Reset(FMars_Request_Batter_Reset());
        _Batter.Request_Readopt(FMars_Request_Batter_Readopt(Id, Copy));
        auto Station = _Station;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(4, _Tray));
        auto Release = FMars_CookingFeed_Release(FMars_CookingFeed_PieceId(constants_heat_station_net_autotest::k_RigGeneration, 50),
            utils_transform::Get_EntityCurrentTransform(_Feed.Get_ReleaseNode()), FVector::ZeroVector);
        Release.Piece = Copy;
        utils_cooking_feed::Request_Admit(Station, Release);
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Batter.Get_Ledger();
        const auto Ids = _Batter.Get_PieceIds();
        const auto RestErrorCm = Ids.Num() == 1 ? Get_SlotErrorCm(Get_FollowedCopy(0), Get_SlotOf(Ids[0]), 0.0f) : -1.0;
        const auto Inbox = _Station.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Num();
        Assert_True(Get_IsLedgerEqual(Ledger, _LedgerBefore), f"the client's ledger is unchanged ({Describe_BatterLedger()})");
        Assert_Equals_Int(Get_SignalCount(), _SignalsBefore, f"the client raised nothing since it asked ({Describe_BatterRecord()})");
        Assert_False(_Station.Has_Fragment(FMars_Fragment_Batter_Requests), "the client's station holds no bowl request");
        Assert_Equals_Int(Inbox, 0, "the client's inbox is empty");
        Assert_False(_Station.Has_Fragment(FMars_Fragment_StationTakeOut_Requests), "the client's station has no take-out queue");
        Assert_True(RestErrorCm >= 0.0 && RestErrorCm <= constants_heat_station_net_autotest::k_OffsetToleranceCm,
            f"the client's copy hangs under its bowl at rest (off by {RestErrorCm} cm)");
        End_HeatClient(f"restErrorCm={RestErrorCm} inbox={Inbox} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    private bool Get_IsLedgerEqual(FMars_Fragment_Batter_Net InA, FMars_Fragment_Batter_Net InB)
    {
        if (InA.Bowl != InB.Bowl || InA.BowlSerial != InB.BowlSerial || InA.Pieces.Num() != InB.Pieces.Num()
            || InA.AdmissionRefusalSerial != InB.AdmissionRefusalSerial || InA.LastAdmissionRefusal != InB.LastAdmissionRefusal
            || InA.TakeOutRefusalSerial != InB.TakeOutRefusalSerial || InA.LastTakeOutRefusal != InB.LastTakeOutRefusal)
        { return false; }

        for (int32 Index = 0; Index < InA.Pieces.Num(); ++Index)
        {
            const auto& A = InA.Pieces[Index];
            const auto& B = InB.Pieces[Index];
            if (A.Id.Get_IsSame(B.Id) == false || A.Piece != B.Piece || A.Slot != B.Slot || A.Coat != B.Coat)
            { return false; }
        }

        return true;
    }
}
