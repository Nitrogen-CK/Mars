// The server spawns the real searing station with the slow feed timing and docks the input platter with one slab frozen on
// it; nobody operates. It asks its feed for a transfer with an open gate; once the feed is Idle again, 1.5 s later, it
// reports (step 1) its feed's available and admitted and where the slab is (frozen on the platter, with the rides, or held
// by the station). On the client the feed raised Reach first and Idle last, its hand left its rest and returned, its slab
// was a child of its own hand node for at least five sampled frames, its available and admitted are the reported ones,
// and a slab reported on the platter rides the client's platter.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_TheHostsTransferAtAPanShowsOnTheClient
class UCk_AutoTest_Net_CookingFeed_TheHostsTransferAtAPanShowsOnTheClient : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 289000.0;
    private const int32 k_MinCarryFrames = 5;

    private FCk_Handle _Slab;

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
        Clear_FeedRecord();
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer(EMars_CookingFeed_StationGate::Open));
        WaitUntil(n"Is_ServerTransferDone", n"OnServerTransferDone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTransferDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_PhaseCount(EMars_CookingFeed_Phase::Reach) > 0 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void OnServerTransferDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_StepGapSeconds, n"OnServerReport");
    }

    UFUNCTION()
    private void OnServerReport(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_StepWithRides(1, _Slab.As_FoodPiece());
        const auto Where = Get_FeedStationReport().Where;
        FCk_Handle Holder = Get_IsLive(_Slab) ? _Slab.As_FoodPiece().TryGet_ReplicatedHolder() : FCk_Handle();
        End_FeedStationServer(f"slab={Where :n} holder=[{Holder.ToString()}] {Describe_Feed()} {Describe_Record()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Report = Get_FeedStationReport();
        const auto CarryFrames = Get_UnderHandFrames(Report.PieceId);
        const auto IsOnPlatter = Report.Where == EMars_TESTONLY_NetFeedStationWhere::OnPlatter;
        const auto PileFault = IsOnPlatter ? Get_PileFault() : "";
        Assert_True(Get_IsReachFirstAndIdleLast(), f"the client's feed raised Reach first and Idle last ({Describe_Record()})");
        Assert_True(_HandLeftRest, "the client's hand left its rest");
        Assert_True(Get_IsHandAtRest(), f"the client's hand returned to its rest ({Describe_HandRest()})");
        Assert_True(CarryFrames >= k_MinCarryFrames, f"the slab rode the client's hand node for at least {k_MinCarryFrames} frames (got {CarryFrames})");
        Assert_Equals_Int(_Feed.Get_Available(), Report.Available, "the client's available is the reported one");
        Assert_Equals_Int(_Feed.Get_Admitted(), Report.Admitted, "the client's admitted is the reported one");
        Assert_True(PileFault.IsEmpty(), f"the slab reported on the platter rides the client's platter ({PileFault})");
        End_FeedStationClient(f"slab={Report.Where :n} carryFrames={CarryFrames} pile=[{PileFault}] {Describe_HandRest()} {Describe_Feed()} {Describe_Record()}");
    }
}
