// The platter first; then a whole food lies loose; then the born bowl, whose authority, as it composes, releases the
// food twice into its inbox, asks a take-out naming no tray and dips: its spawn-frame drain refuses the take-out,
// adopts the food, refuses the second release Duplicate and dips. A copy is born into that bowl. Once its ledger reads
// it, the server holds 4 s, asks a take-out naming no tray and a lift together, and once its ledger reads Resting and
// two refused take-outs reports (step 1). The client's watch finds its copy before the first application of its ledger,
// which carries the born bowl; a settled second after step 1 its copy has raised only what came after:
// OnAdmissionRefused never, OnTakeOutRefused once (after that application), OnBowlChanged Dipped (in that frame) then
// Resting, OnPieceAdded once for the row; and every frame its piece sat under the bowl while the ledger read Dipped it
// sat at the dipped offset (0.5 cm).
// Surface: Ck.Batter.Net.AS_Batter_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Batter_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 306000.0;
    private const float32 k_DipHoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _ServerActsOnFirstFind = true;
        _HeatStationBirth = EMars_TESTONLY_HeatStationBirth::Born;
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
        WaitUntil(n"Is_ServerBorn", n"OnServerBorn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerBorn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ledger = _Batter.Get_Ledger();
        auto Result = OutResult;
        Result.Set(Ledger.Pieces.Num() == 1 && Ledger.Bowl == EMars_Batter_Bowl::Dipped && Ledger.AdmissionRefusalSerial == 1
            && Ledger.LastAdmissionRefusal == EMars_Batter_AdmissionRefusal::Duplicate && Ledger.TakeOutRefusalSerial == 1);
    }

    UFUNCTION()
    private void OnServerBorn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_HeatStation(f"born: {Describe_BatterLedger()} {Describe_Born()}");
        WaitSeconds(k_DipHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_TakeOutWithoutTray();
        _Batter.Request_Lift(FMars_Request_Batter_Lift());
        WaitUntil(n"Is_ServerLifted", n"OnServerLifted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLifted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ledger = _Batter.Get_Ledger();
        auto Result = OutResult;
        Result.Set(Ledger.Bowl == EMars_Batter_Bowl::Resting && Ledger.TakeOutRefusalSerial == 2);
    }

    UFUNCTION()
    private void OnServerLifted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        const auto Ledger = _Batter.Get_Ledger();
        Assert_Equals_Int(Ledger.Pieces.Num(), 1, f"the server's bowl holds one row ({Describe_BatterLedger()})");
        Assert_Equals_Int(Ledger.BowlSerial, 2, "the server's bowl changed twice (dipped, then lifted)");
        Assert_True(Ledger.AdmissionRefusalSerial == 1 && Ledger.LastAdmissionRefusal == EMars_Batter_AdmissionRefusal::Duplicate,
            f"the server refused one admission, Duplicate ({Describe_BatterLedger()})");
        Assert_Equals_Int(Ledger.TakeOutRefusalSerial, 2, "the server refused two take-outs");
        End_HeatServer(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_Born()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // A settled second after step 1.
    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Line = f"{Describe_Born()} {Describe_BatterLedger()}";
        const auto First = Get_BornFirstBatterLedger();
        const auto FirstFrame = Get_BornFirstNotifyFrame();
        const auto Ledger = _Batter.Get_Ledger();

        Assert_True(Get_HasBornFirstNotify(), f"the client recorded the ledger's first application ({Line})");
        Assert_True(_BornInitialAtFind == EMars_Net_InitialState::Awaited, f"the client watched its copy before it took its state ({Line})");
        Assert_True(Get_BornInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(First.Bowl == EMars_Batter_Bowl::Dipped && First.BowlSerial == 1 && First.Pieces.Num() == 1
            && First.AdmissionRefusalSerial == 1 && First.TakeOutRefusalSerial == 1,
            f"the first application carried the born bowl: dipped, one row, one refused admission and take-out ({Line})");

        Assert_Equals_Int(Get_BornEventCount(EMars_TESTONLY_NetHeatBornEventKind::AdmissionRefused),
            Ledger.AdmissionRefusalSerial - First.AdmissionRefusalSerial, f"OnAdmissionRefused only for what came after ({Line})");
        const auto TakeOuts = Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused);
        Assert_Equals_Int(TakeOuts.Num(), Ledger.TakeOutRefusalSerial - First.TakeOutRefusalSerial,
            f"OnTakeOutRefused only for what came after ({Line})");
        Assert_True(TakeOuts.Num() == 0 || TakeOuts[0].Frame > FirstFrame, f"no take-out refusal in the first application's frame ({Line})");

        const auto Bowls = Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::BowlChanged);
        Assert_True(Bowls.Num() == 2 && Bowls[0].Value == int32(EMars_Batter_Bowl::Dipped) && Bowls[0].Frame == FirstFrame
            && Bowls[1].Value == int32(EMars_Batter_Bowl::Resting),
            f"OnBowlChanged Dipped in the first application's frame, then Resting ({Line})");

        Assert_True(_BornAddedIds.Num() == 1 && Ledger.Pieces.Num() == 1 && _BornAddedIds[0].Get_IsSame(Ledger.Pieces[0].Id),
            f"OnPieceAdded once, for the row ({Line})");
        Assert_True(Get_BornDippedSampleCount() > 0, f"the piece sat under the bowl while the ledger read Dipped ({Line})");
        Assert_True(Get_BornWorstDippedCm() >= 0.0 && Get_BornWorstDippedCm() <= constants_heat_station_net_autotest::k_OffsetToleranceCm,
            f"from the first frame it sat under the bowl it sat at the dipped offset ({Line})");
        Assert_True(Ledger.Pieces.Num() == 1 && Ledger.Bowl == EMars_Batter_Bowl::Resting && Ledger.BowlSerial == 2,
            f"the client's ledger reads one row, Resting, serial 2 ({Line})");
        End_HeatClient(Line);
    }
}
