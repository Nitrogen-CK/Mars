// With the slow feed timing the server seats the subject with no platter docked and reports (step 1); it docks the input
// platter with one slab frozen on it and reports (step 2); 1.5 s later it applies one remote add-food press and, once the
// board holds one and the feed is Idle, reports (step 3). The server reads its own add-food row at each step and while the
// hand is busy. The client's row reads "no platter" at step 1, "add food - 1 left" at step 2, "adding food... - 0 left" in
// some sampled frame between step 2 and step 3, and "board busy" at step 3.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_TheAddFoodRowReadsTheSameOnBothMachines
class UCk_AutoTest_Net_CookingFeed_TheAddFoodRowReadsTheSameOnBothMachines : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 286000.0;

    private FCk_Handle _Slab;
    private FString _ServerRows;
    private FString _ClientRows;

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
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnServerStepOne");
    }

    UFUNCTION()
    private void OnServerStepOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_ServerRow("no platter", "step 1");
        Report_Step(1, _Slab.As_FoodPiece());
        WaitSeconds(k_StepGapSeconds, n"OnServerDock");
    }

    UFUNCTION()
    private void OnServerDock(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        WaitSeconds(k_ClientSettleSeconds, n"OnServerStepTwo");
    }

    UFUNCTION()
    private void OnServerStepTwo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_ServerRow("add food - 1 left", "step 2");
        Report_Step(2, _Slab.As_FoodPiece());
        WaitSeconds(k_StepGapSeconds, n"OnServerPress");
    }

    UFUNCTION()
    private void OnServerPress(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Press_RemoteAddFood(1);
        Await_BoardOneAndIdleThen(n"OnServerFed");
    }

    UFUNCTION()
    private void OnServerFed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnServerStepThree");
    }

    UFUNCTION()
    private void OnServerStepThree(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto SawBusy = Get_SawRow("adding food... - 0 left", 2);
        Assert_True(SawBusy, f"the server's row read adding food while the hand was busy ({Describe_Seen(_RowsSeen)})");
        Check_ServerRow("board busy", "step 3");
        Report_Step(3, _Slab.As_FoodPiece());
        End_FeedStationServer(f"rows=[{_ServerRows}] sawBusy={SawBusy} seen=[{Describe_Seen(_RowsSeen)}] {Describe_Feed()}");
    }

    private void Check_ServerRow(FString InExpected, FString InStep)
    {
        const auto Row = Get_AddFoodRowText();
        _ServerRows += f"{InStep}:'{Row}' ";
        Assert_True(Row == InExpected, f"{InStep}: the server's row reads {InExpected} (got {Row})");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Row = Get_AddFoodRowText();
        _ClientRows += f"step{InStep}:'{Row}' ";
        if (InStep == 1)
        {
            Assert_True(Row == "no platter", f"step 1: the client's row reads no platter (got {Row})");
            Await_Step(2);
            return;
        }

        if (InStep == 2)
        {
            Assert_True(Row == "add food - 1 left", f"step 2: the client's row reads add food - 1 left (got {Row})");
            Await_Step(3);
            return;
        }

        const auto SawBusy = Get_SawRow("adding food... - 0 left", 2);
        Assert_True(SawBusy, f"between step 2 and step 3 the client's row read adding food... - 0 left ({Describe_Seen(_RowsSeen)})");
        Assert_True(Row == "board busy", f"step 3: the client's row reads board busy (got {Row})");
        End_FeedStationClient(f"rows=[{_ClientRows}] sawBusy={SawBusy} seen=[{Describe_Seen(_RowsSeen)}] {Describe_Feed()}");
    }
}
