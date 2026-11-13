// The real fry station, nobody operating. In one frame the server resets its kernel, drives the skimmer, admits a battered
// slab (rejected: a release in a drain that also reset) and looks 5 degrees right; a second later it admits the slab again
// and, once it is in play, reports its target (step 1). The client's kernel reads Driven, its target is the reported one
// (0.1 cm), it raised OnPieceAdded exactly once and it holds one row.
// Surface: Ck.Fry.Net.AS_Fry_AResetADriveAndAReleaseInOneFrame
class UCk_AutoTest_Net_Fry_AResetADriveAndAReleaseInOneFrame : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 366000.0;
    private const float32 k_RetrySeconds = 1.0f;
    private const float64 k_LookDegrees = 5.0;
    private const float64 k_TargetToleranceCm = 0.1;

    private FMars_CookingFeed_PieceId _FirstId;
    private FMars_CookingFeed_PieceId _Id;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
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
        TArray<FCk_Handle_FoodPiece> Battered;
        Battered.Add(_Foods[0].As_FoodPiece());
        Batter_Then(Battered, n"OnServerBattered");
    }

    UFUNCTION()
    private void OnServerBattered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Fry.Request_Reset(FMars_Request_Fry_Reset());
        _Fry.Request_SetDrive(FMars_Request_Fry_SetDrive(EMars_Implement_Drive::Driven));
        _FirstId = Admit(_Foods[0].As_FoodPiece());
        _Fry.Request_Look(FMars_Request_Fry_Look(FVector(k_LookDegrees, 0.0, 0.0)));
        WaitSeconds(k_RetrySeconds, n"OnServerRetry");
    }

    UFUNCTION()
    private void OnServerRetry(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Fry.Get_HasPiece(_FirstId), "the server rejected the release that shared a drain with the reset");
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerInPlay", n"OnServerInPlay", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerInPlay(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_HasPiece(_Id));
    }

    UFUNCTION()
    private void OnServerInPlay(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        const auto Target = _Fry.Get_SkimmerTarget();
        _ReportTarget = FVector(Target.X, Target.Y, 0.0);
        Report_HeatStep(1);
        Assert_True(_Fry.Get_Drive() == EMars_Implement_Drive::Driven, "the server's skimmer is driven");
        Assert_Equals_Int(_FryAddedIds.Num(), 1, f"the server raised OnPieceAdded once ({Describe_FryRecord()})");
        End_HeatServer(f"{Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Report = Get_HeatStationReport();
        const auto Target = _Fry.Get_SkimmerTarget();
        const auto TargetError = (Target - FVector2D(Report.Target.X, Report.Target.Y)).Size();
        Assert_True(_Fry.Get_Drive() == EMars_Implement_Drive::Driven, f"the client's kernel reads Driven ({Describe_Fry()} {Describe_FryLedger()})");
        Assert_True(TargetError <= k_TargetToleranceCm, f"the client's target is the server's (client {Target}, server {Report.Target})");
        Assert_Equals_Int(_FryAddedIds.Num(), 1, f"the client raised OnPieceAdded exactly once ({Describe_FryRecord()})");
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 1, f"the client's kernel holds one row ({Describe_FryLedger()})");
        End_HeatClient(f"targetError={TargetError} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }
}
