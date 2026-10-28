class UMars_AutoTest_GroundNavBuildOutcome_StaleAndRetry : UMars_AutoTestRig_GroundNavBuildOutcome
{
    default _Origin = FVector(180000.0, 130000.0, 600.0);
    private int64 _BaselineEpoch;
    private FCk_Handle_JoltBody _Remote;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Arrange(InHandle);
        Add_Step_WaitUntil("actual floor added", n"Check_FloorReady", k_SlowPolls, 0);
        Add_Step("request initial field", n"Step_Initial");
        Add_Step_WaitUntil("initial bake is actually sliced without publication", n"Check_InitialInFlight");
        Add_Step_WaitUntil("known baseline published", n"Check_Baseline", k_SlowPolls, 0);
        Add_Step("request replacement against baseline", n"Step_Replacement");
        Add_Step_WaitUntil("replacement has begun", n"Check_ReplacementInFlight");
        Add_Step("change actual remote Static geometry during slicing", n"Step_Invalidate");
        Add_Step_WaitUntil("one stale completion queues one successful retry", n"Check_Retried", k_SlowPolls, 0);
        Add_Step("correlated outcomes and real provider path", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Initial(FCk_Handle InHandle, FInstancedStruct InPayload)
    { RequestBuild(100); }

    UFUNCTION()
    private void Check_InitialInFlight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Building = utils_ground_nav_volume::Get_IsBuilding(_Volume);
        if (Building)
        {
            Assert_False(utils_ground_nav_volume::Get_IsBuilt(_Volume), "initial in-flight bake has no false publication");
            Assert_Equals_Int(_Outcomes.Num(), 0, "BudgetExhausted does not resolve a request");
        }
        Result.Set(Building);
    }

    UFUNCTION()
    private void Check_Baseline(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(CountOutcome(100) == 1); }

    UFUNCTION()
    private void Step_Replacement(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(FindOutcome(100).Get_OperationResult() == ECk_Request_OperationResult::Succeeded, "baseline succeeded");
        Assert_True(utils_ground_nav_volume::Get_WalkableCellCount(_Volume) > 0, "baseline has real floor cells");
        _BaselineEpoch = utils_ground_nav_volume::Get_BuildEpoch(_Volume);
        RequestBuild(101);
    }

    UFUNCTION()
    private void Check_ReplacementInFlight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(utils_ground_nav_volume::Get_IsBuilding(_Volume) && CountOutcome(101) == 0); }

    UFUNCTION()
    private void Step_Invalidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Remote = SpawnStaticBox(InHandle, _Origin + FVector(5000.0, 0.0, 0.0), FVector(10.0, 10.0, 10.0));
        Track_ForCleanup(_Remote.H());
    }

    protected void HandleOutcome(FCk_Handle_GroundNavVolume InVolume, const FCk_GroundNavVolume_BuildOutcome& InOutcome) override
    {
        if (InOutcome.Get_RequestSequence() != 101)
        { return; }
        Assert_True(InOutcome.Get_Admission() == ECk_GroundNav_BuildAdmission::Accepted
            && InOutcome.Get_OperationResult() == ECk_Request_OperationResult::Failed
            && InOutcome.Get_HasBakeStatus() && InOutcome.Get_BakeStatus() == ECk_GroundNav_BakeStatus::StaleGeometry,
            "actual mid-slice revision has a typed stale cause");
        Assert_True(utils_ground_nav_volume::Get_BuildEpoch(_Volume) == _BaselineEpoch
            && utils_ground_nav_volume::Get_IsBuilt(_Volume), "stale replacement preserves known published baseline");
        Assert_True(utils_nav_surface::Try_ProjectPoint(FCk_NavSurface_ProjectionQuery(_Origin)).Get_Status()
            == ECk_NavSurface_QueryStatus::Success, "baseline remains queryable on stale completion");
        RequestBuild(102);
    }

    UFUNCTION()
    private void Check_Retried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(CountOutcome(102) == 1); }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_jolt_body::Get_IsBodyAdded(_Remote), "the invalidating body actually joined Jolt");
        Assert_Equals_Int(_Outcomes.Num(), 3, "only initial, stale replacement and one callback-issued retry");
        const auto Initial = FindOutcome(100);
        const auto Stale = FindOutcome(101);
        const auto Retry = FindOutcome(102);
        Assert_True(Initial.Get_AttemptSequence() > 0 && Stale.Get_AttemptSequence() > Initial.Get_AttemptSequence()
            && Retry.Get_AttemptSequence() > Stale.Get_AttemptSequence(), "native attempt identities advance");
        Assert_True(Retry.Get_Admission() == ECk_GroundNav_BuildAdmission::Accepted
            && Retry.Get_OperationResult() == ECk_Request_OperationResult::Succeeded
            && Retry.Get_HasBakeStatus() && Retry.Get_BakeStatus() == ECk_GroundNav_BakeStatus::Completed,
            "retry delivers its own successful bake cause");
        Assert_True(utils_ground_nav_volume::Get_IsBuildCurrent(_Volume)
            && utils_ground_nav_volume::Get_BuildEpoch(_Volume) > _BaselineEpoch, "retry publishes a current newer field");
        auto Query = FCk_NavSurface_PathQuery(_Origin - FVector(200.0, 0.0, 0.0), _Origin + FVector(200.0, 0.0, 0.0));
        Query.Set_AgentRadiusUu(40.0f);
        Assert_True(utils_nav_surface::Try_FindPathSync(Query).Get_Status() == ECk_NavSurface_QueryStatus::Success,
            "actual radius40 provider path succeeds");
    }

}

// The runner actor owns expected engine-log diagnostics; the entity script owns assertions and sequencing.
class AMars_AutoTest_GroundNavBuildOutcome_StaleAndRetry_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_GroundNavBuildOutcome_StaleAndRetry;
    default _TimeoutSeconds = 45.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    { TArray<FString> Errors; Errors.Add("failed to build: [Stale Geometry]"); return Errors; }
}
