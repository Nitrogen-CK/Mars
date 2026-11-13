// The input platter with two whole foods frozen on it is docked on the Input dock and the subject seated. The server applies
// a remote add-food press; once the bowl holds one and the feed is Idle it reports (step 1). Before step 1 the client's
// add-food row read "add food - 2 left" and its copy of the carried food was a child of its own feed hand node for at
// least five sampled frames; at step 1 the copy hangs under its bowl, its add-food row reads "add food - 1 left" and its
// label says one is in.
// Surface: Ck.Batter.Net.AS_Batter_ARemoteOperatorsAddFoodFillsTheBowl
class UCk_AutoTest_Net_Batter_ARemoteOperatorsAddFoodFillsTheBowl : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 309000.0;
    private const int32 k_MinUnderHandFrames = 5;

    private int32 _Loads = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_HeatStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Load_Next();
    }

    private void Load_Next()
    {
        ++_Loads;
        Load_WhenReady(Spawn_BesideFood(mars_items::Food_Mushroom(), -1.0), _Loads);
    }

    protected void On_ServerFrozen() override
    {
        if (_Loads < 2)
        {
            Load_Next();
            return;
        }

        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Await_SourcedThen(2, n"OnServerSourced");
    }

    UFUNCTION()
    private void OnServerSourced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("press");
        Press_Remote(GameplayTags::Mars_Intent_StationAddFood);
        WaitUntil(n"Is_ServerOneInAndIdle", n"OnServerOneInAndIdle", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOneInAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_PieceCount() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void OnServerOneInAndIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        _Followed.Add(_Batter.Get_PieceHandle(_Batter.Get_PieceIds()[0]));
        Report_HeatStep(1);
        End_HeatServer(f"{Describe_Feed()} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Report = Get_HeatStationReport();
        const auto Copy = Get_FollowedCopy(0);
        const auto UnderHand = Report.PieceGuids.Num() > 0 ? Get_UnderHandFrames(Report.PieceGuids[0]) : 0;
        const auto Row = Get_AddFoodRowText();
        const auto Label = Get_ShownLabel();
        Assert_True(Get_SawRow("add food - 2 left", 0), f"before step 1 the client's add-food row read add food - 2 left ({Describe_Seen(_RowsSeen)})");
        Assert_True(UnderHand >= k_MinUnderHandFrames, f"the client's copy rode its own feed hand node ({UnderHand} frames)");
        Assert_True(Get_IsUnderBowl(Copy), "the client's copy hangs under its bowl");
        Assert_True(Row == "add food - 1 left", f"the client's add-food row reads add food - 1 left ('{Row}')");
        Assert_True(Label.Contains("1 in"), f"the client's label says one is in ('{Label}')");
        End_HeatClient(f"underHandFrames={UnderHand} row='{Row}' label='{Label}' {Describe_Feed()} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
