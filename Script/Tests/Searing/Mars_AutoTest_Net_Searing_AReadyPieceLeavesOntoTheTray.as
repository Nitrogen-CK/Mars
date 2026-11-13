// The real searing station, nobody operating. The server sears the slab all round, admits it (it arrives Ready) and, with
// no tray docked, asks the station for a take-out naming no tray (refused NoRoom); it reports (step 1), docks a tray on
// the Output dock, asks for a take-out onto it and, once the tray has frozen the piece, publishes the tray's rides (step 2).
// At step 1 the client raised OnTakeOutRefused once, NoRoom, its take-out readout counts one and its label said "no tray".
// At step 2 its kernel has no rows, its summary counts one taken out, its readout none, its copy rides its tray at the
// published ride and its copy's six sears read 1.
// Surface: Ck.Searing.Net.AS_Searing_AReadyPieceLeavesOntoTheTray
class UCk_AutoTest_Net_Searing_AReadyPieceLeavesOntoTheTray : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 324000.0;

    private FMars_CookingFeed_PieceId _Id;

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
        Spawn_FoodsThen(mars_items::Food_MeatSlab(), 1, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Sear_AllRoundThen(_Foods[0].As_FoodPiece(), n"OnServerSeared");
    }

    UFUNCTION()
    private void OnServerSeared(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_HasPiece(_Id) && _Searing.Get_PieceStatus(_Id) == EMars_Searing_PieceStatus::Ready
            && utils_cooking_feed::Get_TakeableCount(_Station) == 1);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_TakeOutWithoutTray();
        WaitUntil(n"Is_ServerRefused", n"OnServerRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_PanTakeOutRefusals.Num() > 0);
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Dock_TrayThen(n"OnServerTrayDocked");
    }

    UFUNCTION()
    private void OnServerTrayDocked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        Assert_True(_PanTakeOutRefusals.Num() == 1 && _PanTakeOutRefusals[0] == EMars_CookingFeed_TakeOutRefusal::NoRoom,
            f"the server refused the first take-out once, NoRoom ({Describe_SearingRecord()})");
        End_HeatServer(f"tray={_Tray.Get_HeldCount()} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            Assert_True(_PanTakeOutRefusals.Num() == 1 && _PanTakeOutRefusals[0] == EMars_CookingFeed_TakeOutRefusal::NoRoom,
                f"the client raised OnTakeOutRefused once, NoRoom ({Describe_SearingRecord()})");
            Assert_Equals_Int(utils_cooking_feed::Get_TakeableCount(_Station), 1, "the client's take-out readout counts one");
            Assert_True(Get_SawLabelAtAnyStep("no tray"), f"the client's label said no tray ({Describe_Seen(_LabelsSeen)})");
            Log_HeatStation(f"step 1: {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Copy = Get_FollowedCopy(0);
        const auto Report = Get_PlatterReport();
        const auto RideFault = Try_FindTray() && Report.Count == 1 ? Get_RideFaultOn(_Tray, Copy, Get_Slot(Report, 0)) : "no tray or no ride";
        const auto IsSeared = Get_IsLive(Copy) && Get_IsSearedAllRound(Copy.Get_CookState());
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, f"the client's kernel has no rows ({Describe_SearingLedger()})");
        Assert_Equals_Int(_Searing.Get_Summary().TakenOut, 1, "the client's summary counts one taken out");
        Assert_Equals_Int(utils_cooking_feed::Get_TakeableCount(_Station), 0, "the client's take-out readout counts none");
        Assert_True(RideFault.IsEmpty(), f"the client's copy rides its tray ({RideFault})");
        Assert_True(IsSeared, "the client's copy's six sears read 1");
        End_HeatClient(f"ride=[{RideFault}] seared={IsSeared} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
