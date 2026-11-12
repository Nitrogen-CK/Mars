// The server spawns the real searing station with the slow feed timing, docks the input platter with one slab frozen on
// it, seats the subject and reports with the rides (step 1), then watches 5 s. At step 1, once its copy reads the subject
// operating, the client's add-food row reads "add food - host only"; the client applies to its own copy of the subject's
// InputIntents a seed and then a remote sample carrying one add-food press, and for 2 s every sampled frame its feed has no
// request fragment, its ledger is unchanged and its hand is at rest; then its slab rides its platter. On the server the
// feed never left Idle, raised no refusal and admitted none, and the slab is still frozen on the platter.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_AClientAtAPanIsToldTheKeyIsTheHosts
class UCk_AutoTest_Net_CookingFeed_AClientAtAPanIsToldTheKeyIsTheHosts : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 288000.0;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 2.0f;

    private FCk_Handle _Slab;
    // Client: while set, every sampled frame is checked against the ledger it read when the watch began.
    private bool _IsWatching = false;
    private FString _WatchedLedger;
    private int32 _WatchedFrames = 0;
    private int32 _RequestFrames = 0;
    private int32 _LedgerChangedFrames = 0;
    private int32 _HandMovedFrames = 0;
    private FString _Row;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _FeedStationKind = EMars_TESTONLY_RealFeedStationKind::Searing;
        _FeedTiming = EMars_TESTONLY_NetFeedStationTiming::Slow;
        Begin_FeedStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    protected void On_FeedStationSample() override
    {
        if (_IsWatching == false)
        { return; }

        ++_WatchedFrames;
        FCk_Handle FeedEntity = _Feed;
        if (FeedEntity.Has_Fragment(FMars_Fragment_CookingFeed_Requests))
        { ++_RequestFrames; }

        if (Describe_FeedLedger() != _WatchedLedger)
        { ++_LedgerChangedFrames; }

        if (Get_IsHandAtRest() == false)
        { ++_HandMovedFrames; }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Spawn_FeedStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Await_SourcedThen(1, n"OnServerSourced");
    }

    UFUNCTION()
    private void OnServerSourced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Clear_FeedRecord();
        Report_StepWithRides(1, _Slab.As_FoodPiece());
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Phases.Num(), 0, f"the server's feed never left Idle ({Describe_Record()})");
        Assert_Equals_Int(_Refusals.Num(), 0, "the server's feed raised no refusal");
        Assert_Equals_Int(_Feed.Get_Admitted(), 0, "the server's feed admitted none");
        Assert_True(_Platter.Get_Held().Contains(_Slab.As_FoodPiece()), "the slab is still frozen on the server's platter");
        End_FeedStationServer(f"row=[{Get_AddFoodRowText()}] {Describe_Feed()} {Describe_Record()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        WaitUntil(n"Is_ClientSeesOperator", n"OnClientSeesOperator", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientSeesOperator(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSubjectOperating());
    }

    UFUNCTION()
    private void OnClientSeesOperator(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Row = Get_AddFoodRowText();
        Assert_True(_Row == "add food - host only", f"the client's add-food row reads add food - host only (got {_Row})");
        Seed_RemoteThen(n"OnClientSeeded");
    }

    UFUNCTION()
    private void OnClientSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _WatchedLedger = Describe_FeedLedger();
        _IsWatching = true;
        Press_RemoteAddFood(1);
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _IsWatching = false;
        const auto PileFault = Get_PileFault();
        Assert_True(_WatchedFrames > 0, "the client sampled its feed while it watched");
        Assert_Equals_Int(_RequestFrames, 0, "the client's feed had no request fragment on any watched frame");
        Assert_Equals_Int(_LedgerChangedFrames, 0, f"the client's ledger never changed ({_WatchedLedger} -> {Describe_FeedLedger()})");
        Assert_Equals_Int(_HandMovedFrames, 0, f"the client's hand stayed at rest ({Describe_HandRest()})");
        Assert_Equals_Int(Get_PlatterReport().Count, 1, "the server reported the slab on its platter");
        Assert_True(PileFault.IsEmpty(), f"the client's slab rides its platter ({PileFault})");
        End_FeedStationClient(f"row=[{_Row}] watched={_WatchedFrames} requestFrames={_RequestFrames} ledgerChanged={_LedgerChangedFrames} handMoved={_HandMovedFrames} pile=[{PileFault}] {Describe_Feed()} {Describe_Record()}");
    }
}
