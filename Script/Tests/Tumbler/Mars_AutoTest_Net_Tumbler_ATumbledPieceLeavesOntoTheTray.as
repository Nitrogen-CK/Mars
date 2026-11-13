// The real tumbler station, nobody operating. The server docks a tray on the Output dock, crumbs a slab to 1, points at the
// shut hatch and opens it, admits the slab and, once it is in the drum, reports (step 1). It asks the station for a take-out
// onto the tray and, once the tray has frozen the slab, publishes the tray's rides (step 2). At step 1 the client's take-out
// count is 1. At step 2 it is 0, its kernel has no rows, its copy of the slab rides its tray at the published ride and its
// copy's crumb reads 1.
// Surface: Ck.Tumbler.Net.AS_Tumbler_ATumbledPieceLeavesOntoTheTray
class UCk_AutoTest_Net_Tumbler_ATumbledPieceLeavesOntoTheTray : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 384000.0;
    private const float32 k_FullCrumb = 1.0f;
    private const float32 k_Exact = 0.001f;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Tumbler;
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
        TArray<FCk_Handle_FoodPiece> Pieces;
        Pieces.Add(_Foods[0].As_FoodPiece());
        Crumb_Then(Pieces, k_FullCrumb, n"OnServerCrumbed");
    }

    UFUNCTION()
    private void OnServerCrumbed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointed");
    }

    UFUNCTION()
    private void OnServerPointed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        WaitUntil(n"Is_ServerOpen", n"OnServerOpen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Open);
    }

    UFUNCTION()
    private void OnServerOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_PieceIds().Num() == 1 && utils_cooking_feed::Get_TakeableCount(_Station) == 1);
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        End_HeatServer(f"tray={_Tray.Get_HeldCount()} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time(f"step{InStep}");
        const auto Takeable = utils_cooking_feed::Get_TakeableCount(_Station);
        if (InStep == 1)
        {
            Assert_Equals_Int(Takeable, 1, f"at step 1 the client's take-out count is 1 ({Describe_Tumbler()} {Describe_TumblerLedger()})");
            Await_Step(2);
            return;
        }

        const auto Copy = Get_FollowedCopy(0);
        const auto Report = Get_PlatterReport();
        const auto RideFault = Try_FindTray() && Report.Count == 1 ? Get_RideFaultOn(_Tray, Copy, Get_Slot(Report, 0)) : "no tray or no ride";
        const auto Crumb = Get_IsLive(Copy) ? Copy.Get_CookState().Crumb : -1.0f;
        Assert_Equals_Int(Takeable, 0, f"at step 2 the client's take-out count is 0 ({Describe_Tumbler()})");
        Assert_Equals_Int(_Tumbler.Get_PieceIds().Num(), 0, f"the client's kernel has no rows ({Describe_TumblerLedger()})");
        Assert_True(RideFault.IsEmpty(), f"the client's copy rides its tray ({RideFault})");
        Assert_True(Math::Abs(Crumb - k_FullCrumb) <= k_Exact, f"the client's copy's crumb reads 1 (got {Crumb})");
        End_HeatClient(f"ride=[{RideFault}] crumb={Crumb} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
