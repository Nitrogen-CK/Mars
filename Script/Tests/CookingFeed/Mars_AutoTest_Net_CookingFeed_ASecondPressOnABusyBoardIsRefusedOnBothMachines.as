// As the remote operator's first add-food to the report (step 1); 1.5 s later a second remote add-food press, which the
// cutting station's gate refuses while the board holds the joint; 1 s later step 2. On the server the feed raised one
// OnTransferRefused, StationGate, and its label said "board busy". On the client, from step 1 to step 2, the feed raised
// OnTransferRefused exactly once, StationGate, never left Idle, its label said "board busy" in some sampled frame and its
// board still holds one.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_ASecondPressOnABusyBoardIsRefusedOnBothMachines
class UCk_AutoTest_Net_CookingFeed_ASecondPressOnABusyBoardIsRefusedOnBothMachines : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 282000.0;

    private FCk_Handle _Slab;
    private FString _StepOneText;

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
        Press_RemoteAddFood(1);
        Await_BoardOneAndIdleThen(n"OnServerFed");
    }

    UFUNCTION()
    private void OnServerFed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(1, _Slab.As_FoodPiece());
        WaitSeconds(k_StepGapSeconds, n"OnServerSecondPress");
    }

    UFUNCTION()
    private void OnServerSecondPress(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Clear_FeedRecord();
        Press_RemoteAddFood(1);
        WaitSeconds(k_ClientSettleSeconds, n"OnServerRefused");
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(2, _Slab.As_FoodPiece());
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto SawBusy = Get_SawLabel("board busy", 1);
        Assert_Equals_Int(Get_FeedSignalCount(EMars_TESTONLY_NetFeedStationSignal::TransferRefused), 1, f"the server's feed raised one refusal ({Describe_Record()})");
        Assert_Equals_Int(Get_RefusalCount(EMars_CookingFeed_Refusal::StationGate), 1, "the server's refusal is StationGate");
        Assert_True(SawBusy, f"the server's label said board busy ({Describe_Seen(_LabelsSeen)})");
        End_FeedStationServer(f"sawBusy={SawBusy} {Describe_Feed()} {Describe_Record()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Assert_Equals_Int(_Board.Get_HeldCount(), 1, "step 1: the client's board holds one");
            _StepOneText = f"step1 {Describe_Feed()} {Describe_Record()}";
            Clear_FeedRecord();
            Await_Step(2);
            return;
        }

        const auto SawBusy = Get_SawLabel("board busy", 1) || Get_SawLabel("board busy", 2);
        Assert_Equals_Int(Get_FeedSignalCount(EMars_TESTONLY_NetFeedStationSignal::TransferRefused), 1, f"the client's feed raised one refusal ({Describe_Record()})");
        Assert_Equals_Int(Get_RefusalCount(EMars_CookingFeed_Refusal::StationGate), 1, "the client's refusal is StationGate");
        Assert_True(SawBusy, f"the client's label said board busy ({Describe_Seen(_LabelsSeen)})");
        Assert_Equals_Int(_Phases.Num(), 0, f"the client's feed never left Idle ({Describe_Record()})");
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the client's board holds one");
        End_FeedStationClient(f"{_StepOneText} step2 sawBusy={SawBusy} {Describe_Feed()} {Describe_Record()}");
    }
}
