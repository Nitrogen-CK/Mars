// The real searing station. The server docks the input platter with one slab frozen on it, seats the subject and reports
// (step 1); a moment later it applies one remote add-food press, and once its pan holds one piece and its feed is Idle it
// reports step 2. At step 1 the client's add-food row read "add food - 1 left". Before step 2 the client's copy of the slab
// was a child of its own feed hand node for at least five sampled frames. At step 2 the client's pan holds one piece, it
// raised OnPieceAdded once, its add-food row reads "platter empty" and its label says "0/1 ready".
// Surface: Ck.Searing.Net.AS_Searing_ARemoteOperatorsAddFoodLandsOnThePan
class UCk_AutoTest_Net_Searing_ARemoteOperatorsAddFoodLandsOnThePan : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 344000.0;

    private FCk_Handle _Slab;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Searing;
    }

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
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        Load_WhenReady(_Slab, 1);
    }

    protected void On_ServerFrozen() override
    {
        _Followed.Add(_Slab.As_FoodPiece());
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Await_SourcedThen(1, n"OnServerSourced");
    }

    UFUNCTION()
    private void OnServerSourced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("press");
        Press_Remote(GameplayTags::Mars_Intent_StationAddFood);
        WaitUntil(n"Is_ServerOneOnAndIdle", n"OnServerOneOnAndIdle", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOneOnAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_PieceIds().Num() == 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void OnServerOneOnAndIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStep(2);
        End_HeatServer(f"row=[{Get_AddFoodRowText()}] {Describe_Feed()} {Describe_Record()} {Describe_Pan()} {Describe_SearingLedger()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Report = Get_HeatStationReport();
        const auto UnderHand = Report.PieceGuids.Num() > 0 ? Get_UnderHandFrames(Report.PieceGuids[0]) : 0;
        const auto Row = Get_AddFoodRowText();
        const auto Label = Get_ShownLabel();
        Assert_True(Get_SawRow("add food - 1 left", 1), f"at step 1 the client's add-food row read add food - 1 left ({Describe_Seen(_RowsSeen)})");
        Assert_True(UnderHand >= 5, f"the client's slab rode its own feed hand node for at least five frames (got {UnderHand})");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, f"the client's pan holds one piece ({Describe_SearingLedger()})");
        Assert_Equals_Int(_PanAddedIds.Num(), 1, f"the client raised OnPieceAdded once ({Describe_SearingRecord()})");
        Assert_True(Row == "platter empty", f"the client's add-food row reads platter empty (got {Row})");
        Assert_True(Label.Contains("0/1 ready"), f"the client's label says 0/1 ready (got {Label})");
        const auto ShownLabel = Label.Replace("\n", " / ");
        End_HeatClient(f"underHand={UnderHand} row=[{Row}] label=[{ShownLabel}] rows=[{Describe_Seen(_RowsSeen)}] {Describe_Feed()} {Describe_Pan()} {Describe_SearingRecord()}");
    }
}
