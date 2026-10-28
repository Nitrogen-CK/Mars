class UMars_AutoTest_GroundNavBuildOutcome_NonStaleFailure : UMars_AutoTestRig_GroundNavBuildOutcome
{
    default _Origin = FVector(188000.0, 138000.0, 600.0);
    private FCk_Request_GroundNavVolume_Build _ReusableRequest;
    private int32 _ReboundGenericCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto InvalidProfile = FCk_GroundNav_AgentProfile(
            utils_shapes::Make_Capsule(FCk_ShapeCapsule_Dimensions(40.0f, 40.0f)));
        InvalidProfile.Set_StepHeightUu(-1.0f);
        _ProfileVariants.Add(FCk_GroundNav_ProfileVariant(
            utils_gameplay_tag::ResolveGameplayTag(n"CkTests.GroundNav.Profile.Crawler"), InvalidProfile));
        Arrange(InHandle);
        Add_Step_WaitUntil("actual floor added", n"Check_FloorReady", k_SlowPolls, 0);
        Add_Step("request bake with an invalid variant step height", n"Step_Request");
        Add_Step_WaitUntil("real bake failure resolved", n"Check_Failed");
        Add_Step("reuse one template for two invalid calls then a valid volume", n"Step_Invalid");
        Add_Step_WaitUntil("reused template completes its valid submission", n"Check_Reused", k_SlowPolls, 0);
        Add_Step("each submission has independent terminal state and delegate binding", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Request(FCk_Handle InHandle, FInstancedStruct InPayload)
    { RequestBuild(10); }

    UFUNCTION()
    private void Check_Failed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(CountOutcome(10) == 1); }

    UFUNCTION()
    private void Step_Invalid(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Failed = FindOutcome(10);
        Assert_True(Failed.Get_Admission() == ECk_GroundNav_BuildAdmission::Accepted
            && Failed.Get_AttemptSequence() > 0
            && Failed.Get_OperationResult() == ECk_Request_OperationResult::Failed
            && Failed.Get_HasBakeStatus() && Failed.Get_BakeStatus() == ECk_GroundNav_BakeStatus::InvalidInput,
            "pure BeginBuild's invalid variant profile remains distinguishable from StaleGeometry");
        Assert_False(utils_ground_nav_volume::Get_IsBuilt(_Volume), "failed initial build publishes nothing");
        Assert_False(utils_ground_nav_volume::Get_IsBuilding(_Volume), "framework does not retry an invalid profile");
        auto Invalid = FCk_Handle_GroundNavVolume();
        _ReusableRequest.Set_RequestSequence(11);
        _ReusableRequest.Set_OnBuildResolved(FCk_Delegate_GroundNavVolume_OnBuildResolved(this, n"OnResolved"));
        utils_ground_nav_volume::Request_Build(Invalid, _ReusableRequest,
            FCk_Delegate_Request_OnCompleted(this, n"OnGeneric"));
        utils_ground_nav_volume::Request_Build(Invalid, _ReusableRequest,
            FCk_Delegate_Request_OnCompleted(this, n"OnReboundGeneric"));
        Assert_Equals_Int(_ReboundGenericCount, 1, "second invalid call uses its rebound generic delegate");
        Assert_Equals_Int(CountOutcome(11), 2, "both invalid submissions resolve independently from the same template");

        utils_entity_lifetime::Request_DestroyEntity(_VolumeOwner);
        _ProfileVariants.Empty();
        ComposeVolume(InHandle);
        utils_ground_nav_volume::Request_Build(_Volume, _ReusableRequest,
            FCk_Delegate_Request_OnCompleted(this, n"OnReboundGeneric"));
    }

    UFUNCTION()
    private void OnReboundGeneric(FCk_Handle InOwner, ECk_Request_OperationResult InResult)
    { ++_ReboundGenericCount; OnGeneric(InOwner, InResult); }

    UFUNCTION()
    private void Check_Reused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(CountOutcome(11) == 3); }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Outcomes.Num(), 4, "one profile failure, two explicit invalid calls, one explicit valid call");
        Assert_Equals_Int(_ReboundGenericCount, 2, "second invalid and valid calls each use their supplied generic delegate");
        for (int32 Index = 1; Index <= 2; ++Index)
        {
            const auto Rejected = _Outcomes[Index];
            Assert_True(Rejected.Get_RequestSequence() == 11
                && Rejected.Get_Admission() == ECk_GroundNav_BuildAdmission::Rejected
                && Rejected.Get_AttemptSequence() == 0
                && Rejected.Get_OperationResult() == ECk_Request_OperationResult::Failed_NotEnqueued
                && Rejected.Get_HasBakeStatus() == false, "invalid submission has independent rejection without a borrowed bake cause");
        }
        const auto Reused = _Outcomes[3];
        Assert_True(Reused.Get_RequestSequence() == 11
            && Reused.Get_Admission() == ECk_GroundNav_BuildAdmission::Accepted
            && Reused.Get_AttemptSequence() > 0
            && Reused.Get_OperationResult() == ECk_Request_OperationResult::Succeeded
            && Reused.Get_HasBakeStatus() && Reused.Get_BakeStatus() == ECk_GroundNav_BakeStatus::Completed,
            "correcting the target volume can reuse the unchanged template and typed callback");
        Assert_True(utils_ground_nav_volume::Get_IsBuilt(_Volume)
            && utils_ground_nav_volume::Get_WalkableCellCount(_Volume) > 0, "valid reuse actually publishes a nonlimited field");
    }

}

// Keep expected native refusal diagnostics on the runner, leaving unrelated errors visible.
class AMars_AutoTest_GroundNavBuildOutcome_NonStaleFailure_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_GroundNavBuildOutcome_NonStaleFailure;
    default _TimeoutSeconds = 45.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Errors;
        Errors.Add("could not begin a build: [Invalid Input]");
        Errors.Add("Invalid GroundNav Volume Handle");
        // Each deliberate invalid Request_Build also reaches its existing callstack recorder before validation.
        // Pin that helper's source; do not suppress arbitrary invalid-handle or assertion diagnostics.
        Errors.Add("CkDebugCallstack_Utils.inl.h] [Line:");
        return Errors;
    }
}
