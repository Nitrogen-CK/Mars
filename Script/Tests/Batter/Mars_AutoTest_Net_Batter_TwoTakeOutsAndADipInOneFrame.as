// An empty tray docked on the Output dock and one bare piece in the bowl. In one frame the server asks the station for two
// take-outs onto the tray and dips the bowl; one second later it reports (step 1). The server refused both take-outs
// CoatIncomplete and its bowl is Dipped. The client raised OnTakeOutRefused exactly twice and OnBowlChanged Dipped once, its
// ledger counts two take-out refusals and its bowl has one row.
// Surface: Ck.Batter.Net.AS_Batter_TwoTakeOutsAndADipInOneFrame
class UCk_AutoTest_Net_Batter_TwoTakeOutsAndADipInOneFrame : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 304000.0;
    private const float32 k_AnswerSeconds = 1.0f;

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
        Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Batter.Get_PieceCount() == 1);
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_TakeOutToTray();
        Request_TakeOutToTray();
        _Batter.Request_Dip(FMars_Request_Batter_Dip());
        WaitSeconds(k_AnswerSeconds, n"OnServerAnswered");
    }

    UFUNCTION()
    private void OnServerAnswered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        const auto IsIncomplete = _TakeOutRefusals.Num() == 2 && _TakeOutRefusals[0] == EMars_Batter_TakeOutRefusal::CoatIncomplete
            && _TakeOutRefusals[1] == EMars_Batter_TakeOutRefusal::CoatIncomplete;
        Assert_True(IsIncomplete, f"the server refused both take-outs CoatIncomplete ({Describe_BatterRecord()})");
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Dipped, "the server's bowl is Dipped");
        End_HeatServer(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        Assert_Equals_Int(_TakeOutRefusals.Num(), 2, f"the client raised OnTakeOutRefused exactly twice ({Describe_BatterRecord()})");
        Assert_Equals_Int(_Batter.Get_Ledger().TakeOutRefusalSerial, 2, "the client's ledger counts two take-out refusals");
        Assert_True(_BowlChanges.Num() == 1 && _BowlChanges[0] == EMars_Batter_Bowl::Dipped,
            f"the client raised OnBowlChanged Dipped once ({Describe_BatterRecord()})");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 1, "the client's bowl has one row");
        End_HeatClient(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
