// An empty tray docked on the Output dock, one bare piece in the bowl and the subject seated. The server holds Primary
// remotely until the piece is coated, lets it go and, once the piece rests, reports (step 1); a step gap later it applies a
// remote Secondary press and, once the tray has frozen the piece, publishes the tray's rides (step 2). On the client the
// take-out row reads "take out - 1 ready" at step 1 and "take out - 0 ready" at step 2, when its copy rides its tray.
// Surface: Ck.Batter.Net.AS_Batter_ARemoteOperatorsTakeOutIsCountedOnBothMachines
class UCk_AutoTest_Net_Batter_ARemoteOperatorsTakeOutIsCountedOnBothMachines : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 310000.0;

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
        Seat_OperatorThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("hold");
        Hold_Remote(GameplayTags::Mars_Intent_Interact_Primary);
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
        Mark_Time("letGo");
        LetGo_Remote(GameplayTags::Mars_Intent_Interact_Primary);
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
        Mark_Time("takeOut");
        Press_Remote(GameplayTags::Mars_Intent_Interact_Secondary);
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
        End_HeatServer(f"tray={_Tray.Get_HeldCount()} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Row = Get_TakeOutRowText();
        if (InStep == 1)
        {
            Mark_Time("step1");
            Assert_True(Row == "take out - 1 ready", f"the client's take-out row reads take out - 1 ready ('{Row}')");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Report = Get_PlatterReport();
        const auto RideFault = Try_FindTray() && Report.Count == 1 ? Get_RideFaultOn(_Tray, Get_FollowedCopy(0), Get_Slot(Report, 0)) : "no tray or no ride";
        Assert_True(Row == "take out - 0 ready", f"the client's take-out row reads take out - 0 ready ('{Row}')");
        Assert_True(RideFault.IsEmpty(), f"the client's copy rides its tray ({RideFault})");
        End_HeatClient(f"row='{Row}' ride=[{RideFault}] {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
