// The server admits one whole food and dips the bowl; one second later, in one frame, it lifts and dips again (the drain
// ends the old dip before the new one, so the bowl never left Dipped); one second later it reports the coat and the
// bowl's serial (step 1). The client's bowl is Dipped, its copy hangs under its bowl at the dipped offset (0.5 cm), the last
// OnBowlChanged it raised is Dipped and its ledger's bowl serial is the server's.
// Surface: Ck.Batter.Net.AS_Batter_ALiftAndADipThatArriveTogether
class UCk_AutoTest_Net_Batter_ALiftAndADipThatArriveTogether : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 305000.0;
    private const float32 k_HoldSeconds = 1.0f;

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
        _Batter.Request_Dip(FMars_Request_Batter_Dip());
        WaitSeconds(k_HoldSeconds, n"OnServerDipped");
    }

    UFUNCTION()
    private void OnServerDipped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Batter.Request_Lift(FMars_Request_Batter_Lift());
        _Batter.Request_Dip(FMars_Request_Batter_Dip());
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Dipped, "the server's bowl is Dipped");
        End_HeatServer(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Report = Get_HeatStationReport();
        const auto Ids = _Batter.Get_PieceIds();
        const auto ErrorCm = Ids.Num() == 1 ? Get_SlotErrorCm(Get_FollowedCopy(0), Get_SlotOf(Ids[0]), 1.0f) : -1.0;
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Dipped, f"the client's bowl is Dipped ({Describe_BatterLedger()})");
        Assert_True(ErrorCm >= 0.0 && ErrorCm <= constants_heat_station_net_autotest::k_OffsetToleranceCm,
            f"the client's copy hangs under its bowl at the dipped offset (off by {ErrorCm} cm)");
        Assert_True(_BowlChanges.Num() > 0 && _BowlChanges.Last() == EMars_Batter_Bowl::Dipped,
            f"the last OnBowlChanged the client raised is Dipped ({Describe_BatterRecord()})");
        Assert_Equals_Int(_Batter.Get_Ledger().BowlSerial, Report.BowlSerial, "the client's bowl serial is the server's");
        End_HeatClient(f"errorCm={ErrorCm} reportedCoat={Report.Coat} serverBowlSerial={Report.BowlSerial} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
