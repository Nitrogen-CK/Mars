// With the slow feed timing the server docks the input platter, seats the subject and applies one remote add-food press;
// in the first frame its feed reads Reach it releases the subject, and the operator's leaving cancels the transfer. Once
// the feed is Idle and the pile has frozen it publishes the rides and reports (step 1). On the server the transfer settled
// once, Cancelled, and the board holds none. On the client the station is free, the feed is Idle, the joint rides the
// input platter at the reported offset and was never a child of the client's hand node, the board holds none and the feed
// reads one available.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_AnOperatorWhoLeavesMidReachGivesTheJointBack
class UCk_AutoTest_Net_CookingFeed_AnOperatorWhoLeavesMidReachGivesTheJointBack : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 284000.0;

    private FCk_Handle _Slab;
    private int64 _ReleaseFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

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
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Clear_FeedRecord();
        Press_RemoteAddFood(1);
        WaitUntil(n"Is_ReachThenRelease", n"OnServerReleased", k_SlowPolls);
    }

    // The release goes out on the first polled frame the feed reads Reach.
    UFUNCTION()
    private void Is_ReachThenRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReach = _Feed.Get_Phase() == EMars_CookingFeed_Phase::Reach;
        if (IsReach)
        {
            _ReleaseFrame = utils_time::Get_FrameCounter();
            Release_Subject();
        }

        auto Result = OutResult;
        Result.Set(IsReach);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerGivenBack", n"OnServerGivenBack", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGivenBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle && _Platter.Get_HeldCount() == 1
            && _Feed.Get_IsSettling() == false && _Station.As_Station().Get_IsOperated() == false);
    }

    UFUNCTION()
    private void OnServerGivenBack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_StepWithRides(1, _Slab.As_FoodPiece());
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Settles.Num(), 1, f"the transfer settled once on the server ({Describe_Record()})");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Cancelled), 1, "the server's settle is Cancelled");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the server's board holds none");
        End_FeedStationServer(f"releaseFrame={_ReleaseFrame} {Describe_Feed()} {Describe_Record()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Report = Get_FeedStationReport();
        const auto PileFault = Get_PileFault();
        const auto UnderHand = Get_UnderHandFrames(Report.PieceId);
        Assert_False(_Station.As_Station().Get_IsOperated(), "the client's station is free");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the client's feed is Idle ({Describe_Feed()})");
        Assert_Equals_Int(Get_PlatterReport().Count, 1, "the server reported the joint on its platter");
        Assert_True(PileFault.IsEmpty(), f"the joint rides the client's input platter at the report ({PileFault})");
        Assert_Equals_Int(UnderHand, 0, "the joint was never a child of the client's hand node");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the client's board holds none");
        Assert_Equals_Int(_Feed.Get_Available(), 1, "the client's feed reads one available");
        End_FeedStationClient(f"pile=[{PileFault}] underHandFrames={UnderHand} {Describe_Feed()} {Describe_Record()}");
    }
}
