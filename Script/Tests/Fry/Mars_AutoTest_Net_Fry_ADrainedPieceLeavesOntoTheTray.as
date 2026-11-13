// The real fry station at half a second's drain, nobody operating. The server docks a tray on the Output dock, batters a
// slab and admits it; once it is in the oil it puts it on the basket floor, and once its kernel raises OnPieceDrained it
// reports (step 1). It asks the station for a take-out onto the tray and, once the tray has frozen the piece, publishes the
// tray's rides (step 2). At step 1 the client reads the piece Drained, its take-out readout counts one and its summary one
// drained. At step 2 its kernel has no rows, its summary counts one taken out, its copy rides its tray at the published ride
// and its copy's oil coat is the spec's drained coat (0.01).
// Surface: Ck.Fry.Net.AS_Fry_ADrainedPieceLeavesOntoTheTray
class UCk_AutoTest_Net_Fry_ADrainedPieceLeavesOntoTheTray : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 365000.0;
    private const float32 k_DrainSeconds = 0.5f;
    private const float32 k_CoatTolerance = 0.01f;

    private FMars_CookingFeed_PieceId _Id;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
    }

    protected FMars_Fry_Spec Make_FrySpec() const override
    {
        auto Spec = FMars_Fry_Spec();
        Spec.Receiver.DrainSeconds = k_DrainSeconds;
        return Spec;
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
        Spawn_FoodsThen(mars_items::Food_MeatSlab(), 1, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TArray<FCk_Handle_FoodPiece> Battered;
        Battered.Add(_Foods[0].As_FoodPiece());
        Batter_Then(Battered, n"OnServerBattered");
    }

    UFUNCTION()
    private void OnServerBattered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Dock_TrayThen(n"OnServerTrayDocked");
    }

    UFUNCTION()
    private void OnServerTrayDocked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerInOil", n"OnServerInOil", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerInOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsInOil(_Id));
    }

    UFUNCTION()
    private void OnServerInOil(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("basket");
        Put_IntoBasket(_Id);
        WaitUntil(n"Is_ServerDrained", n"OnServerDrained", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_DrainedIds.Num() > 0);
    }

    UFUNCTION()
    private void OnServerDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_TakeOutToTray();
        WaitUntil(n"Is_ServerTrayFrozen", n"OnServerTrayFrozen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTrayFrozen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tray.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void OnServerTrayFrozen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        Report_HeatStepWithRidesOf(2, _Tray);
        End_HeatServer(f"tray={_Tray.Get_HeldCount()} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            const auto Report = Get_HeatStationReport();
            _Id = Report.BowlIds.Num() > 0 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();
            const auto HasPiece = _Fry.Get_HasPiece(_Id);
            Assert_True(HasPiece && _Fry.Get_PieceDrain(_Id) == EMars_Fry_Drain::Drained, f"the client reads the piece Drained ({Describe_FryLedger()})");
            Assert_Equals_Int(_Fry.Get_TakeableCount(), 1, f"the client's take-out readout counts one ({Describe_Fry()})");
            Assert_Equals_Int(_Fry.Get_Summary().Drained, 1, f"the client's summary counts one drained ({Describe_Fry()})");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Copy = Get_FollowedCopy(0);
        const auto Report = Get_PlatterReport();
        const auto RideFault = Try_FindTray() && Report.Count == 1 ? Get_RideFaultOn(_Tray, Copy, Get_Slot(Report, 0)) : "no tray or no ride";
        const auto Coat = Get_IsLive(Copy) ? Copy.Get_CookState().OilCoat : -1.0f;
        const auto Drained = _Fry.Get_Spec().Receiver.DrainedOilCoat;
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 0, f"the client's kernel has no rows ({Describe_FryLedger()})");
        Assert_Equals_Int(_Fry.Get_Summary().TakenOut, 1, f"the client's summary counts one taken out ({Describe_Fry()})");
        Assert_True(RideFault.IsEmpty(), f"the client's copy rides its tray ({RideFault})");
        Assert_True(Math::Abs(Coat - Drained) <= k_CoatTolerance, f"the client's copy carries the drained oil coat (got {Coat}, spec {Drained})");
        End_HeatClient(f"ride=[{RideFault}] coat={Coat} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }
}
