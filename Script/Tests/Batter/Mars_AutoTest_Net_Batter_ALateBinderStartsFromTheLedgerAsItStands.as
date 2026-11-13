// The platter first; then a whole food and a cut half lie loose; then the station. In the continuation in which the server
// first finds its station it admits the food and the half (refused NotWhole) and dips the bowl, holds 4 s, lifts and
// reports (step 1). The client starts counting only once its ledger reads one admission refusal, one row and Dipped and its
// copy announced that row (a listener that arrives after them): OnPieceAdded was raised for the row once before that, and
// a second later its copy hangs under its bowl at the dipped offset (0.5 cm). From the clear to step 1 it raised
// OnBowlChanged Resting once, no OnAdmissionRefused and no OnPieceAdded.
// Surface: Ck.Batter.Net.AS_Batter_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Batter_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 306000.0;
    private const float32 k_DipHoldSeconds = 4.0f;
    private const float32 k_PoseSettleSeconds = 1.0f;

    // Client: what it saw when its ledger first stood as the server left it.
    private int32 _AddedBeforeClear = -1;
    private int32 _AddedBeforeBindAtClear = -1;
    private int64 _FoundFrame = -1;
    private int64 _ClearFrame = -1;
    private float64 _PoseErrorCm = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _ServerActsOnFirstFind = true;
        Begin_HeatStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientLedgerStands", n"OnClientLedgerStands", k_SlowPolls); }
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
        Spawn_CutHalfThen(n"OnServerHalf");
    }

    UFUNCTION()
    private void OnServerHalf(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        Admit(_Foods[0].As_FoodPiece());
        Admit(_CutHalf);
        _Batter.Request_Dip(FMars_Request_Batter_Dip());
        WaitSeconds(k_DipHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Batter.Request_Lift(FMars_Request_Batter_Lift());
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_True(_AdmissionRefusals.Num() == 1 && _AdmissionRefusals[0] == EMars_Batter_AdmissionRefusal::NotWhole,
            f"the server refused the half once, NotWhole ({Describe_BatterRecord()})");
        End_HeatServer(f"{Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientLedgerStands(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Try_FindHeatStation() == false)
        {
            Result.Set(false);
            return;
        }

        if (_FoundFrame < 0)
        { _FoundFrame = utils_time::Get_FrameCounter(); }

        const auto Ledger = _Batter.Get_Ledger();
        Result.Set(Ledger.AdmissionRefusalSerial == 1 && Ledger.Pieces.Num() == 1 && Ledger.Bowl == EMars_Batter_Bowl::Dipped
            && Get_IsAnnounced(Ledger.Pieces[0].Id));
    }

    // The listener arrives now: what its copy raised before is not its to count.
    UFUNCTION()
    private void OnClientLedgerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClearFrame = utils_time::Get_FrameCounter();
        const auto Id = _Batter.Get_Ledger().Pieces[0].Id;
        _AddedBeforeClear = Get_AddedCount(Id);
        _AddedBeforeBindAtClear = _AddedBeforeBind;
        Log_HeatStation(f"before the clear: {Describe_BatterRecord()} foundFrame={_FoundFrame} clearFrame={_ClearFrame}");
        Clear_BatterRecord();
        Assert_Equals_Int(_AddedBeforeClear, 1, "the client raised OnPieceAdded for the row once before it started counting");
        WaitSeconds(k_PoseSettleSeconds, n"OnClientPoseSettled");
    }

    UFUNCTION()
    private void OnClientPoseSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ids = _Batter.Get_PieceIds();
        _PoseErrorCm = Ids.Num() == 1 ? Get_SlotErrorCm(Get_BowlCopy(Ids[0]), Get_SlotOf(Ids[0]), 1.0f) : -1.0;
        Assert_True(_PoseErrorCm >= 0.0 && _PoseErrorCm <= constants_heat_station_net_autotest::k_OffsetToleranceCm,
            f"the client's copy hangs under its bowl at the dipped offset (off by {_PoseErrorCm} cm; {Describe_BatterLedger()})");
        Await_Step(1);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        Assert_True(_BowlChanges.Num() == 1 && _BowlChanges[0] == EMars_Batter_Bowl::Resting,
            f"since it started counting the client raised OnBowlChanged Resting once ({Describe_BatterRecord()})");
        Assert_Equals_Int(_AdmissionRefusals.Num(), 0, "the client raised no earlier refusal again");
        Assert_Equals_Int(_AddedIds.Num(), 0, "the client raised no OnPieceAdded again");
        End_HeatClient(f"addedBeforeClear={_AddedBeforeClear} addedBeforeBind={_AddedBeforeBindAtClear} foundFrame={_FoundFrame} clearFrame={_ClearFrame} poseErrorCm={_PoseErrorCm} {Describe_Bowl()} {Describe_BatterLedger()} {Describe_BatterRecord()}");
    }
}
