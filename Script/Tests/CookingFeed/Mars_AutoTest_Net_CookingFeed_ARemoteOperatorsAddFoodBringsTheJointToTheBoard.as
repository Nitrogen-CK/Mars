// The server spawns the real cutting station with the slow feed timing, docks the input platter with one slab frozen on
// it, seats the subject and applies one remote add-food press; once the board holds one and the feed is Idle it reports
// (step 1). On the server the feed made one transfer and admitted one. On the client the feed's spec carries the slow
// timing, the feed raised Reach first and Idle last, the joint rode the client's own hand node for at least ten sampled
// frames, and at the report the joint stands at its reported pose, the board holds one, the feed reads none available
// and one admitted, the hand is at rest and the label says "1 on the board".
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_ARemoteOperatorsAddFoodBringsTheJointToTheBoard
class UCk_AutoTest_Net_CookingFeed_ARemoteOperatorsAddFoodBringsTheJointToTheBoard : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 281000.0;
    private const int32 k_MinCarryFrames = 10;

    private FCk_Handle _Slab;

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
        Await_BoardOneAndIdleThen(n"OnServerFed");
    }

    UFUNCTION()
    private void OnServerFed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(1, _Slab.As_FoodPiece());
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_PhaseCount(EMars_CookingFeed_Phase::Reach), 1, f"the server's feed made one transfer ({Describe_Record()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the server's feed admitted one");
        End_FeedStationServer(f"{Describe_Timing(_Feed.Get_Spec().Timing)} {Describe_Feed()} {Describe_Record()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Report = Get_FeedStationReport();
        const auto Timing = _Feed.Get_Spec().Timing;
        const auto CarryFrames = Get_UnderHandFrames(Report.PieceId);
        const auto BoardFault = Get_BoardFault();
        const auto Label = Get_ShownLabel();
        const auto ReachIndex = _Phases.FindIndex(EMars_CookingFeed_Phase::Reach);
        const auto PressToReach = ReachIndex >= 0 ? _PhaseFrames[ReachIndex] - int64(Report.PressFrame) : int64(-1);

        Assert_True(Get_IsSlowTiming(Timing), f"the client's feed spec carries the slow timing ({Describe_Timing(Timing)})");
        Assert_True(Get_IsReachFirstAndIdleLast(), f"the client's feed raised Reach first and Idle last ({Describe_Record()})");
        Assert_True(CarryFrames >= k_MinCarryFrames, f"the joint rode the client's hand node for at least {k_MinCarryFrames} frames (got {CarryFrames})");
        Assert_True(Report.BoardIds.Contains(Report.PieceId), "the server's board holds the joint");
        Assert_True(BoardFault.IsEmpty(), f"the joint stands on the client's board at its reported pose ({BoardFault})");
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the client's board holds one");
        Assert_Equals_Int(_Feed.Get_Available(), 0, "the client's feed reads none available");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        Assert_True(Get_IsHandAtRest(), f"the client's hand is at rest ({Describe_HandRest()})");
        Assert_True(Label.Contains("1 on the board"), f"the client's label says 1 on the board ({Label})");

        const auto ShownLabel = Label.Replace("\n", " / ");
        End_FeedStationClient(f"{Describe_Timing(Timing)} carryFrames={CarryFrames} pressToReachFrames={PressToReach} board=[{BoardFault}] {Describe_Feed()} {Describe_HandRest()} label=[{ShownLabel}] {Describe_Record()}");
    }
}
