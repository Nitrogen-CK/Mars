// A slab first, then the born tumbler, whose authority, as it composes, asks a take-out naming no tray and presses: its
// spawn-frame drain refuses the take-out NoRoom and the press NoTarget (nothing is hovered yet). A copy is born into
// that tumbler. Once the server's station is ready it looks its cursor away from the shut hatch's tab and, once nothing
// is hovered, presses (refused); it points at the hatch and presses, and once the hatch is Open admits the slab. It
// holds 4 s, points at the open hatch, presses (closing) and once the hatch is Closed reports (step 1). The client's
// watch finds its copy before the first application of its ledger, which carries the born refusals; once its ledger
// reads two press refusals, the hatch Open and one row and its copy announced the row, its hinge Mover rests at its
// open pose (alpha within 0.02 of 1). A settled second after step 1 its copy has raised only what came after:
// OnPressRefused once (after that application), no OnTakeOutRefused, OnHatchChanged Closed once and OnPieceAdded once,
// and nothing but levels in that application's frame.
// Surface: Ck.Tumbler.Net.AS_Tumbler_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Tumbler_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 387000.0;
    private const float32 k_HoldSeconds = 4.0f;
    private const float32 k_HingeTolerance = 0.02f;

    // Client: its rested hinge.
    private float32 _RestedHinge = -1.0f;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Tumbler;
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
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Mark_Time("found");
        Log_HeatStation(f"ready: {Describe_TumblerLedger()} {Describe_Born()}");
        Point_AwayThen(EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerAway");
    }

    UFUNCTION()
    private void OnServerAway(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointedShut");
    }

    UFUNCTION()
    private void OnServerPointedShut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        Mark_Time("admit");
        _Followed.Add(_Foods[0].As_FoodPiece());
        Admit(_Foods[0].As_FoodPiece());
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointedOpen");
    }

    UFUNCTION()
    private void OnServerPointedOpen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("close");
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        WaitUntil(n"Is_ServerClosed", n"OnServerClosed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Closed);
    }

    UFUNCTION()
    private void OnServerClosed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        const auto Ledger = _Tumbler.Get_Ledger();
        Assert_Equals_Int(Ledger.PressRefusalSerial, 2, f"the server refused two presses ({Describe_TumblerLedger()})");
        Assert_Equals_Int(Ledger.TakeOutRefusalSerial, 1, f"the server refused one take-out ({Describe_TumblerLedger()})");
        Assert_Equals_Int(Ledger.Pieces.Num(), 1, "the server holds the slab");
        End_HeatServer(f"{Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_Born()}");
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

        const auto Ledger = _Tumbler.Get_Ledger();
        Result.Set(Ledger.PressRefusalSerial == 2 && Ledger.Hatch == EMars_Tumbler_Hatch::Open && Ledger.Pieces.Num() == 1
            && Get_TumblerAnnouncedRows().Num() == 1);
    }

    UFUNCTION()
    private void OnClientLedgerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientHingeRested", n"OnClientHingeRested", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHingeRested(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Hinge = Get_HingeMover();
        Result.Set(Hinge.Get_IsResting() && Hinge.Get_Target() == EMars_Mover_Pose::End);
    }

    UFUNCTION()
    private void OnClientHingeRested(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _RestedHinge = Get_HingeMover().Get_Alpha();
        Assert_True(Math::Abs(_RestedHinge - 1.0f) <= k_HingeTolerance, f"the client's hinge Mover rests open (alpha {_RestedHinge})");
        Await_Step(1);
    }

    // A settled second after step 1.
    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Line = f"restedHinge={_RestedHinge} {Describe_Born()} {Describe_TumblerLedger()}";
        const auto First = Get_BornFirstTumblerLedger();
        const auto FirstFrame = Get_BornFirstNotifyFrame();
        const auto Ledger = _Tumbler.Get_Ledger();

        Assert_True(Get_HasBornFirstNotify(), f"the client recorded the ledger's first application ({Line})");
        Assert_True(_BornInitialAtFind == EMars_Net_InitialState::Awaited, f"the client watched its copy before it took its state ({Line})");
        Assert_True(Get_BornInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(First.PressRefusalSerial == 1 && First.TakeOutRefusalSerial == 1,
            f"the first application carried the born tumbler: one refused press and one refused take-out ({Line})");

        const auto Presses = Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::PressRefused);
        Assert_Equals_Int(Presses.Num(), Ledger.PressRefusalSerial - First.PressRefusalSerial,
            f"OnPressRefused only for what came after ({Line})");
        Assert_True(Presses.Num() == 0 || Presses[0].Frame > FirstFrame, f"no press refusal in the first application's frame ({Line})");
        Assert_Equals_Int(Get_BornEventCount(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused),
            Ledger.TakeOutRefusalSerial - First.TakeOutRefusalSerial, f"OnTakeOutRefused only for what came after ({Line})");

        auto Closed = 0;
        for (const auto& Event : Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind::HatchChanged))
        {
            if (Event.Value == int32(EMars_Tumbler_Hatch::Closed))
            { ++Closed; }
        }

        Assert_Equals_Int(Closed, 1, f"OnHatchChanged Closed once ({Line})");
        Assert_True(_BornAddedIds.Num() == 1 && Ledger.Pieces.Num() == 1 && _BornAddedIds[0].Get_IsSame(Ledger.Pieces[0].Id),
            f"OnPieceAdded once, for the row ({Line})");
        const auto ActsInFirstFrame = Get_BornEventCountInFrame(EMars_TESTONLY_NetHeatBornEventKind::PressRefused, FirstFrame)
            + Get_BornEventCountInFrame(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused, FirstFrame);
        Assert_Equals_Int(ActsInFirstFrame, 0, f"nothing but levels in the first application's frame ({Line})");
        End_HeatClient(Line);
    }
}
