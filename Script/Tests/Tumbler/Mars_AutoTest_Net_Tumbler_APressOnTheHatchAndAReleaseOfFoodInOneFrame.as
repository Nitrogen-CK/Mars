// The real tumbler station, nobody operating. The server points at the shut hatch and, in one frame, presses and admits a
// slab: the drain judges the release before the press, so the release is refused (the hatch is not open yet) and the press
// opens the hatch. Once the hatch is Open it admits the slab again, and once it is in the drum reports (step 1). The client
// reads Open, raised OnPieceAdded exactly once and holds one row.
// Surface: Ck.Tumbler.Net.AS_Tumbler_APressOnTheHatchAndAReleaseOfFoodInOneFrame
class UCk_AutoTest_Net_Tumbler_APressOnTheHatchAndAReleaseOfFoodInOneFrame : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 386000.0;

    // Server: the pieces its kernel held in the frame the hatch read Open.
    private int32 _PiecesAtOpen = -1;

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
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        Point_AtThen(EMars_Tumbler_Target::Hatch, EMars_TESTONLY_NetTumblerLook::Kernel, n"OnServerPointed");
    }

    UFUNCTION()
    private void OnServerPointed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("pressAndAdmit");
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
        Admit(_Foods[0].As_FoodPiece());
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
        _PiecesAtOpen = _Tumbler.Get_PieceCount();
        Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerIn", n"OnServerIn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_PieceIds().Num() == 1);
    }

    UFUNCTION()
    private void OnServerIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_Equals_Int(_PiecesAtOpen, 0, "the release that shared the press's frame was refused");
        Assert_Equals_Int(_TumblerAddedIds.Num(), 1, f"the server added the slab once ({Describe_TumblerRecord()})");
        End_HeatServer(f"piecesAtOpen={_PiecesAtOpen} {Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        Assert_True(_Tumbler.Get_Hatch() == EMars_Tumbler_Hatch::Open, f"the client reads the hatch Open ({Describe_Tumbler()} {Describe_TumblerLedger()})");
        Assert_Equals_Int(_TumblerAddedIds.Num(), 1, f"the client raised OnPieceAdded exactly once ({Describe_TumblerRecord()})");
        Assert_Equals_Int(_Tumbler.Get_PieceIds().Num(), 1, f"the client holds one row ({Describe_TumblerLedger()})");
        End_HeatClient(f"{Describe_Tumbler()} {Describe_TumblerLedger()} {Describe_TumblerRecord()}");
    }
}
