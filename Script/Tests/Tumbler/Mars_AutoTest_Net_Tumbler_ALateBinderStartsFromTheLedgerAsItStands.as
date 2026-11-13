// A slab first, then the station. In the continuation in which the server first finds its station ready it looks its
// cursor away from the shut hatch's tab (where it starts) and, once nothing is hovered, presses (refused); it points at the
// hatch and presses, and once the hatch is Open admits the slab. It holds 4 s, points at the open hatch, presses (closing)
// and once the hatch is Closed reports (step 1). The client starts counting only once its ledger reads one press refusal,
// the hatch Open and one row and its copy announced that row (a listener that arrives after them): OnPieceAdded was raised
// for the row once in all, and once its hinge Mover rests at its open pose its alpha is within 0.02 of 1. After the report
// it raised OnHatchChanged Closed once since it started counting, and no OnPressRefused and no OnPieceAdded.
// Surface: Ck.Tumbler.Net.AS_Tumbler_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Tumbler_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 387000.0;
    private const float32 k_HoldSeconds = 4.0f;
    private const float32 k_HingeTolerance = 0.02f;

    // Client: what it saw when its ledger first stood as the server left it, and its rested hinge.
    private int32 _AddedBeforeClear = -1;
    private int64 _FoundFrame = -1;
    private int64 _ClearFrame = -1;
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
        Assert_True(_PressRefusals.Num() == 1 && _PressRefusals[0] == EMars_Tumbler_Refusal::NoTarget,
            f"the server refused the first press once, NoTarget ({Describe_TumblerRecord()})");
        Assert_Equals_Int(_Tumbler.Get_PieceCount(), 1, "the server holds the slab");
        End_HeatServer(f"{Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
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

        const auto Ledger = _Tumbler.Get_Ledger();
        Result.Set(Ledger.PressRefusalSerial == 1 && Ledger.Hatch == EMars_Tumbler_Hatch::Open && Ledger.Pieces.Num() == 1
            && Get_TumblerAnnouncedRows().Num() == 1);
    }

    // The listener arrives now: what its copy raised before is not its to count.
    UFUNCTION()
    private void OnClientLedgerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClearFrame = utils_time::Get_FrameCounter();
        const auto Id = _Tumbler.Get_Ledger().Pieces[0].Id;
        _AddedBeforeClear = Get_TumblerAddedCount(Id);
        Clear_TumblerRecord();
        Assert_Equals_Int(_AddedBeforeClear, 1, "the client raised OnPieceAdded for the row once before it started counting");
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

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        Assert_Equals_Int(Get_HatchChangeCount(EMars_Tumbler_Hatch::Closed), 1, f"since it started counting the client raised OnHatchChanged Closed once ({Describe_TumblerRecord()})");
        Assert_Equals_Int(_PressRefusals.Num(), 0, "the client raised no earlier press refusal again");
        Assert_Equals_Int(_TumblerAddedIds.Num(), 0, "the client raised no OnPieceAdded again");
        End_HeatClient(f"addedBeforeClear={_AddedBeforeClear} foundFrame={_FoundFrame} clearFrame={_ClearFrame} restedHinge={_RestedHinge} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
