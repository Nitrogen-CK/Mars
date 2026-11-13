// The real searing station, nobody operating. In one frame the server resets its kernel, heats the pan and admits the slab
// (rejected: a release in a drain that also reset); a second later it admits the slab again and, once it is on the books,
// reports (step 1). The client's pan is hot, it raised OnHeatChanged Hot once and OnPieceAdded exactly once, and its kernel
// has one row.
// Surface: Ck.Searing.Net.AS_Searing_AResetAHeatAndAReleaseInOneFrame
class UCk_AutoTest_Net_Searing_AResetAHeatAndAReleaseInOneFrame : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 326000.0;
    private const float32 k_RetrySeconds = 1.0f;

    private FMars_CookingFeed_PieceId _FirstId;
    private FMars_CookingFeed_PieceId _Id;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Searing;
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
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Searing.Request_Reset(FMars_Request_Searing_Reset());
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
        _FirstId = Admit(_Foods[0].As_FoodPiece());
        WaitSeconds(k_RetrySeconds, n"OnServerRetry");
    }

    UFUNCTION()
    private void OnServerRetry(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Searing.Get_HasPiece(_FirstId), "the server rejected the release that shared a drain with the reset");
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerOnBooks", n"OnServerOnBooks", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOnBooks(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_HasPiece(_Id));
    }

    UFUNCTION()
    private void OnServerOnBooks(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        Assert_True(_Searing.Get_IsHot(), "the server's pan is hot");
        Assert_Equals_Int(_PanAddedIds.Num(), 1, f"the server raised OnPieceAdded once ({Describe_SearingRecord()})");
        End_HeatServer(f"{Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        Assert_True(_Searing.Get_IsHot(), "the client's pan is hot");
        Assert_True(Get_HeatChangeCount(EMars_Searing_Heat::Hot) == 1 && _HeatChanges.Num() == 1, f"the client raised OnHeatChanged Hot once ({Describe_SearingRecord()})");
        Assert_Equals_Int(_PanAddedIds.Num(), 1, f"the client raised OnPieceAdded exactly once ({Describe_SearingRecord()})");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, f"the client's kernel has one row ({Describe_SearingLedger()})");
        End_HeatClient(f"{Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
