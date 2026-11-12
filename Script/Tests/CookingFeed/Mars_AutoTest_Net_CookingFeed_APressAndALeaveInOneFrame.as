// The server docks the input platter, seats the subject and, in one frame, applies a remote add-food press and releases the
// subject; 3 s later it publishes the rides and reports (step 1) where the joint is: frozen on the platter (the leave came
// first, or cancelled the reach) or admitted to the board (the transfer was past its grasp). On the server the feed is Idle
// and the joint is in one of those two places. On the client the feed is Idle and the station free, the joint is where
// the server's is (riding the client's platter at the reported offset, or standing on its board at the reported pose),
// and the feed's and the board's counts equal the server's.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_APressAndALeaveInOneFrame
class UCk_AutoTest_Net_CookingFeed_APressAndALeaveInOneFrame : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 285000.0;
    private const float32 k_OutcomeSeconds = 3.0f;

    private FCk_Handle _Slab;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

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
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Clear_FeedRecord();
        Press_RemoteAddFood(1);
        Release_Subject();
        WaitSeconds(k_OutcomeSeconds, n"OnServerOutcome");
    }

    UFUNCTION()
    private void OnServerOutcome(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_StepWithRides(1, _Slab.As_FoodPiece());
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Where = Get_FeedStationReport().Where;
        const auto IsPlaced = Where == EMars_TESTONLY_NetFeedStationWhere::OnPlatter || Where == EMars_TESTONLY_NetFeedStationWhere::OnBoard;
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the server's feed is Idle ({Describe_Feed()})");
        Assert_True(IsPlaced, f"the joint is frozen on the platter or on the board (got {Where :n})");
        End_FeedStationServer(f"outcome={Where :n} {Describe_Feed()} {Describe_Record()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Report = Get_FeedStationReport();
        auto Fault = f"unexpected outcome {Report.Where :n}";
        if (Report.Where == EMars_TESTONLY_NetFeedStationWhere::OnPlatter)
        { Fault = Get_PileFault(); }
        else if (Report.Where == EMars_TESTONLY_NetFeedStationWhere::OnBoard)
        { Fault = Get_BoardFault(); }

        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the client's feed is Idle ({Describe_Feed()})");
        Assert_False(_Station.As_Station().Get_IsOperated(), "the client's station is free");
        Assert_True(Fault.IsEmpty(), f"the joint is where the server's is ({Report.Where :n}: {Fault})");
        Assert_Equals_Int(_Feed.Get_Available(), Report.Available, "the client's available equals the server's");
        Assert_Equals_Int(_Feed.Get_Admitted(), Report.Admitted, "the client's admitted equals the server's");
        Assert_Equals_Int(_Board.Get_HeldCount(), Report.BoardIds.Num(), "the client's board count equals the server's");
        End_FeedStationClient(f"outcome={Report.Where :n} fault=[{Fault}] {Describe_Feed()} {Describe_Record()}");
    }
}
