// An empty tray docked on the Output dock. The server admits one whole food, dips the bowl until the piece is coated, lifts
// it and, once it rests, reports (step 1); a step gap later it asks the station for a take-out onto the tray and, once
// the tray has frozen the piece, publishes the tray's rides (step 2). At step 1 the client's bowl counts one coated piece
// and its station's take-out readout one. At step 2 its bowl has no rows, its copy rides its tray at the published ride
// and hangs under no bowl, its copy's cook state reads battered, it raised OnPieceTakenOut once and its readout counts
// none.
// Surface: Ck.Batter.Net.AS_Batter_ACoatedPieceLeavesOntoTheTrayOnTheClient
class UCk_AutoTest_Net_Batter_ACoatedPieceLeavesOntoTheTrayOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 302000.0;

    private FMars_CookingFeed_PieceId _Id;

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
        Spawn_FoodsThen(mars_items::Food_Mushroom(), 1, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_HasPiece(_Id));
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Batter.Request_Dip(FMars_Request_Batter_Dip());
        WaitUntil(n"Is_ServerCoated", n"OnServerCoated", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCoated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_PieceCoat(_Id) >= 1.0f);
    }

    UFUNCTION()
    private void OnServerCoated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Batter.Request_Lift(FMars_Request_Batter_Lift());
        WaitUntil(n"Is_ServerRests", n"OnServerRests", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRests(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_CoatedCount() == 1 && utils_cooking_feed::Get_TakeableCount(_Station) == 1);
    }

    UFUNCTION()
    private void OnServerRests(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        Assert_Equals_Int(_TakenOutIds.Num(), 1, "the server raised OnPieceTakenOut once");
        End_HeatServer(f"tray={_Tray.Get_HeldCount()} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            Assert_Equals_Int(_Batter.Get_CoatedCount(), 1, f"the client's bowl counts one coated piece ({Describe_BatterLedger()})");
            Assert_Equals_Int(utils_cooking_feed::Get_TakeableCount(_Station), 1, "the client's take-out readout counts one");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Copy = Get_FollowedCopy(0);
        const auto Report = Get_PlatterReport();
        const auto RideFault = Try_FindTray() && Report.Count == 1 ? Get_RideFaultOn(_Tray, Copy, Get_Slot(Report, 0)) : "no tray or no ride";
        const auto IsBattered = Get_IsLive(Copy) && utils_batter::Get_IsBattered(Copy.Get_CookState());
        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, f"the client's bowl has no rows ({Describe_BatterLedger()})");
        Assert_True(RideFault.IsEmpty(), f"the client's copy rides its tray ({RideFault})");
        Assert_False(Get_IsUnderBowl(Copy), "the client's copy hangs under no bowl");
        Assert_True(IsBattered, "the client's copy reads battered");
        Assert_Equals_Int(_TakenOutIds.Num(), 1, f"the client raised OnPieceTakenOut once ({Describe_BatterRecord()})");
        Assert_Equals_Int(utils_cooking_feed::Get_TakeableCount(_Station), 0, "the client's take-out readout counts none");
        End_HeatClient(f"ride=[{RideFault}] battered={IsBattered} shell={Get_WearsShell(Copy)} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
