// The server docks the input platter with two slabs frozen on it, seats the subject and applies one remote sample whose
// add-food serial is two more than the seed's: the two presses reach the feed on consecutive frames, the first begins a
// transfer and the second is refused Busy. Once the board holds one and the feed is Idle it reports (step 1). On the server
// the feed made one transfer and raised one refusal, Busy. On the client the feed raised Reach once and OnTransferRefused
// once, Busy; its board holds one, and its feed reads one available and one admitted.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_TwoAddFoodPressesThatArriveTogether
class UCk_AutoTest_Net_CookingFeed_TwoAddFoodPressesThatArriveTogether : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 283000.0;
    private const FVector k_SecondSlabOffset = FVector(80.0, -150.0, 5.0);

    private FCk_Handle _FirstSlab;
    private FCk_Handle _SecondSlab;

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
        _FirstSlab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        _SecondSlab = Spawn_ServerFood(mars_items::Food_MeatSlab(), _FloorTop + k_SecondSlabOffset);
        Load_WhenReady(_FirstSlab, 1);
    }

    protected void On_ServerFrozen() override
    {
        if (_Platter.Get_HeldCount() < 2)
        {
            Load_WhenReady(_SecondSlab, 2);
            return;
        }

        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Await_SourcedThen(2, n"OnServerSourced");
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
        Press_RemoteAddFood(2);
        Await_BoardOneAndIdleThen(n"OnServerFed");
    }

    UFUNCTION()
    private void OnServerFed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(1, FCk_Handle_FoodPiece());
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_PhaseCount(EMars_CookingFeed_Phase::Reach), 1, f"the server's feed made one transfer ({Describe_Record()})");
        Assert_Equals_Int(_Refusals.Num(), 1, "the server's feed raised one refusal");
        Assert_Equals_Int(Get_RefusalCount(EMars_CookingFeed_Refusal::Busy), 1, "the server's refusal is Busy");
        End_FeedStationServer(f"{Describe_Feed()} {Describe_Record()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Assert_Equals_Int(Get_PhaseCount(EMars_CookingFeed_Phase::Reach), 1, f"the client's feed raised Reach once ({Describe_Record()})");
        Assert_Equals_Int(Get_FeedSignalCount(EMars_TESTONLY_NetFeedStationSignal::TransferRefused), 1, "the client's feed raised one refusal");
        Assert_Equals_Int(Get_RefusalCount(EMars_CookingFeed_Refusal::Busy), 1, "the client's refusal is Busy");
        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the client's board holds one");
        Assert_Equals_Int(_Feed.Get_Available(), 1, "the client's feed reads one available");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        End_FeedStationClient(f"{Describe_Feed()} {Describe_Record()}");
    }
}
