// The slab first, seared all round; then the born pan, whose authority, as it composes, heats it and asks a take-out
// naming no tray: its spawn-frame drain lights the pan and refuses the take-out NoRoom. A copy is born into that pan.
// Once the server's station is ready it admits the slab (it arrives Ready) and asks a take-out naming no tray again; it
// holds 4 s, chills the pan and, once its ledger reads Cold, reports (step 1). The client's watch finds its copy before
// the first application of its ledger, which carries the born pan; once its ledger reads one row and two refused
// take-outs and its copy announced the row, a settled second after step 1 its copy has raised only what came after:
// OnTakeOutRefused once (after that application), OnHeatChanged Hot (in that frame) then Cold, no OnFaceSeared, and
// OnPieceAdded once; its pan implement is Followed.
// Surface: Ck.Searing.Net.AS_Searing_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Searing_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 327000.0;
    private const float32 k_HoldSeconds = 4.0f;

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
        _HeatStationBirth = EMars_TESTONLY_HeatStationBirth::Born;
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
        Log_HeatStation(f"ready: {Describe_SearingLedger()} {Describe_Born()}");
        _Followed.Add(_Foods[0].As_FoodPiece());
        Admit(_Foods[0].As_FoodPiece());
        Request_TakeOutWithoutTray();
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Cold));
        WaitUntil(n"Is_ServerCold", n"OnServerCold", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_Ledger().Heat == EMars_Searing_Heat::Cold);
    }

    UFUNCTION()
    private void OnServerCold(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        const auto Ledger = _Searing.Get_Ledger();
        Assert_Equals_Int(Ledger.Pieces.Num(), 1, f"the server's pan holds one row ({Describe_SearingLedger()})");
        Assert_Equals_Int(Ledger.TakeOutRefusalSerial, 2, f"the server refused two take-outs ({Describe_SearingLedger()})");
        End_HeatServer(f"{Describe_Pan()} {Describe_SearingLedger()} {Describe_Born()}");
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

        const auto Ledger = _Searing.Get_Ledger();
        Result.Set(Ledger.TakeOutRefusalSerial == 2 && Ledger.Pieces.Num() == 1 && Get_PanAnnouncedRows().Num() == 1);
    }

    UFUNCTION()
    private void OnClientLedgerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_Step(1);
    }

    // A settled second after step 1.
    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Line = f"{Describe_Born()} {Describe_SearingLedger()} {Describe_Pan()}";
        const auto First = Get_BornFirstSearingLedger();
        const auto FirstFrame = Get_BornFirstNotifyFrame();
        const auto Ledger = _Searing.Get_Ledger();

        Assert_True(Get_HasBornFirstNotify(), f"the client recorded the ledger's first application ({Line})");
        Assert_True(_BornInitialAtFind == EMars_Net_InitialState::Awaited, f"the client watched its copy before it took its state ({Line})");
        Assert_True(Get_BornInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(Get_BornPanInitialState() == EMars_Net_InitialState::Taken, f"the client's pan took the command it was born into ({Line})");
        Assert_True(First.Heat == EMars_Searing_Heat::Hot && First.TakeOutRefusalSerial == 1,
            f"the first application carried the born pan: hot, one refused take-out ({Line})");

        const auto TakeOuts = Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused);
        Assert_Equals_Int(TakeOuts.Num(), Ledger.TakeOutRefusalSerial - First.TakeOutRefusalSerial,
            f"OnTakeOutRefused only for what came after ({Line})");
        Assert_True(TakeOuts.Num() == 0 || TakeOuts[0].Frame > FirstFrame, f"no take-out refusal in the first application's frame ({Line})");

        const auto Heats = Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::HeatChanged);
        Assert_True(Heats.Num() == 2 && Heats[0].Value == int32(EMars_Searing_Heat::Hot) && Heats[0].Frame == FirstFrame
            && Heats[1].Value == int32(EMars_Searing_Heat::Cold),
            f"OnHeatChanged Hot in the first application's frame, then Cold ({Line})");
        Assert_Equals_Int(Get_BornEventCount(EMars_TESTONLY_NetHeatBornEventKind::FaceSeared), 0,
            f"no seared burst for a face already seared ({Line})");
        Assert_True(_BornAddedIds.Num() == 1 && Ledger.Pieces.Num() == 1 && _BornAddedIds[0].Get_IsSame(Ledger.Pieces[0].Id),
            f"OnPieceAdded once, for the row ({Line})");
        Assert_True(_Searing.Get_Pan().Get_Steering() == EMars_Implement_Steering::Followed, f"the client's pan implement is Followed ({Line})");
        End_HeatClient(Line);
    }
}
