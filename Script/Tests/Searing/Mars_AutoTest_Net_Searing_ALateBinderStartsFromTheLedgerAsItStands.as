// The slab first, seared all round; then the station. In the continuation in which the server first finds its station
// ready it heats the pan, admits the slab (it arrives Ready) and asks for a take-out naming no tray (refused NoRoom); it
// holds 4 s, chills the pan and reports (step 1). The client starts counting only once its ledger reads one take-out
// refusal, one row and Hot and its copy announced that row (a listener that arrives after them): OnPieceAdded was raised
// for the row once in all, and its pan implement is Followed and Driven. From the clear to step 1 it raised OnHeatChanged
// Cold once and no OnTakeOutRefused, no OnFaceSeared and no OnPieceAdded.
// Surface: Ck.Searing.Net.AS_Searing_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Searing_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 327000.0;
    private const float32 k_HoldSeconds = 4.0f;
    private const float32 k_PanSettleSeconds = 0.5f;

    // Client: what it saw when its ledger first stood as the server left it.
    private int32 _AddedBeforeClear = -1;
    private int64 _FoundFrame = -1;
    private int64 _ClearFrame = -1;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Searing;
    }

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
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
        Admit(_Foods[0].As_FoodPiece());
        Request_TakeOutWithoutTray();
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Cold));
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_True(_PanTakeOutRefusals.Num() == 1 && _PanTakeOutRefusals[0] == EMars_CookingFeed_TakeOutRefusal::NoRoom,
            f"the server refused the take-out once, NoRoom ({Describe_SearingRecord()})");
        End_HeatServer(f"{Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientLedgerStands(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Try_FindHeatStation() == false || Get_IsLive(_Station) == false)
        {
            Result.Set(false);
            return;
        }

        if (_FoundFrame < 0)
        { _FoundFrame = utils_time::Get_FrameCounter(); }

        const auto Ledger = _Searing.Get_Ledger();
        Result.Set(Ledger.TakeOutRefusalSerial == 1 && Ledger.Pieces.Num() == 1 && Ledger.Heat == EMars_Searing_Heat::Hot
            && Get_PanAnnouncedRows().Num() == 1);
    }

    // The listener arrives now: what its copy raised before is not its to count.
    UFUNCTION()
    private void OnClientLedgerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClearFrame = utils_time::Get_FrameCounter();
        const auto Id = _Searing.Get_Ledger().Pieces[0].Id;
        _AddedBeforeClear = Get_PanAddedCount(Id);
        Log_HeatStation(f"before the clear: {Describe_SearingRecord()} foundFrame={_FoundFrame} clearFrame={_ClearFrame} {Describe_SearingLedger()}");
        Clear_SearingRecord();
        Assert_Equals_Int(_AddedBeforeClear, 1, "the client raised OnPieceAdded for the row once before it started counting");
        WaitSeconds(k_PanSettleSeconds, n"OnClientPanSettled");
    }

    UFUNCTION()
    private void OnClientPanSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Pan = _Searing.Get_Pan();
        Assert_True(Pan.Get_Steering() == EMars_Implement_Steering::Followed, f"the client's pan implement is Followed ({Describe_Pan()})");
        Assert_True(Pan.Get_IsDriven(), f"the client's pan implement is Driven ({Describe_Pan()} {Describe_SearingLedger()})");
        Await_Step(1);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        Assert_True(Get_HeatChangeCount(EMars_Searing_Heat::Cold) == 1 && _HeatChanges.Num() == 1,
            f"since it started counting the client raised OnHeatChanged Cold once ({Describe_SearingRecord()})");
        Assert_Equals_Int(_PanTakeOutRefusals.Num(), 0, "the client raised no earlier take-out refusal again");
        Assert_Equals_Int(_SearedIds.Num(), 0, "the client raised no seared burst for a face already seared");
        Assert_Equals_Int(_PanAddedIds.Num(), 0, "the client raised no OnPieceAdded again");
        End_HeatClient(f"addedBeforeClear={_AddedBeforeClear} foundFrame={_FoundFrame} clearFrame={_ClearFrame} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
