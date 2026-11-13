// A remote operator at the real fry station with a raw platter of one unbattered slab docked on its Input dock. The server
// freezes the slab on the platter, docks it and, once the feed draws from it, seats the subject and reports (step 1); it
// applies a remote add-food press and a second later publishes the platter's rides (step 2): its feed refused the press
// once, StationGate, and its add-food row reads "not battered: batter it first". At step 1 the client's platter counts no
// battered piece and its add-food row reads "not battered: batter it first"; at step 2 its feed raised OnTransferRefused
// once, StationGate, its label said "not battered: batter it first", its fryer has no row and its slab rides its platter.
// Surface: Ck.Fry.Net.AS_Fry_AnUnbatteredPlatterIsSaidOnBothMachines
class UCk_AutoTest_Net_Fry_AnUnbatteredPlatterIsSaidOnBothMachines : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 370000.0;
    private const float32 k_RefusedSeconds = 1.0f;

    private FCk_Handle _Slab;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
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

    private bool Get_IsStationGateOnce()
    {
        return _Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::StationGate;
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
        WaitSeconds(k_RefusedSeconds, n"OnServerRefused");
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        const auto Row = Get_AddFoodRowText();
        Report_HeatStepWithRidesOf(2, _Platter);
        Assert_True(Get_IsStationGateOnce(), f"the server's feed refused the press once, StationGate ({Describe_Record()})");
        Assert_True(Row == "not battered: batter it first", f"the server's add-food row reads not battered (got {Row})");
        End_HeatServer(f"row='{Row}' battered={_Platter.Get_BatteredCount()} {Describe_Feed()} {Describe_Fry()} {Describe_Record()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        if (InStep == 1)
        {
            const auto Row = Get_AddFoodRowText();
            Assert_Equals_Int(_Platter.Get_BatteredCount(), 0, "the client's platter counts no battered piece");
            Assert_True(Row == "not battered: batter it first", f"at step 1 the client's add-food row reads not battered (got {Row})");
            Await_Step(2);
            return;
        }

        const auto Copy = Get_FollowedCopy(0);
        const auto Report = Get_PlatterReport();
        const auto RideFault = Report.Count == 1 ? Get_RideFaultOn(_Platter, Copy, Get_Slot(Report, 0)) : "no ride";
        Assert_True(Get_IsStationGateOnce(), f"the client's feed raised OnTransferRefused once, StationGate ({Describe_Record()})");
        Assert_True(Get_SawLabelAtAnyStep("not battered: batter it first"), f"the client's label said not battered ({Describe_Seen(_LabelsSeen)})");
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 0, f"the client's fryer has no row ({Describe_FryLedger()})");
        Assert_True(RideFault.IsEmpty(), f"the client's slab rides its platter ({RideFault})");
        End_HeatClient(f"ride=[{RideFault}] rows=[{Describe_Seen(_RowsSeen)}] {Describe_Feed()} {Describe_Fry()} {Describe_Record()}");
    }
}
