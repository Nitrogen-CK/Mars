class UMars_AutoTest_GroundNavBuildOutcome_DuplicateRestartAndTeardown : UMars_AutoTestRig_GroundNavBuildOutcome
{
    default _Origin = FVector(184000.0, 134000.0, 600.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Arrange(InHandle);
        Add_Step_WaitUntil("actual floor added", n"Check_FloorReady", k_SlowPolls, 0);
        Add_Step("request original build", n"Step_Original");
        Add_Step_WaitUntil("original build in flight", n"Check_OriginalBuilding");
        Add_Step("same-selector duplicate then forced replacement", n"Step_Replace");
        Add_Step_WaitUntil("duplicate and predecessor each resolve", n"Check_Replaced");
        Add_Step("assert no-op and cancellation; destroy replacement owner", n"Step_DestroyActive");
        Add_Step_WaitUntil("active request cancelled and volume gone", n"Check_ActiveGone");
        Add_Step("enqueue then destroy before admission", n"Step_DestroyQueued");
        Add_Step_WaitUntil("queued request cancelled and volume gone", n"Check_QueuedGone");
        Add_Step("complete another build whose generic callback destroys its owner", n"Step_GenericDestroysOwner");
        Add_Step_WaitUntil("typed success retained and owner actually gone", n"Check_GenericDestroyedOwner", k_SlowPolls, 0);
        Add_Step("all five requests resolved once with honest identities", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Original(FCk_Handle InHandle, FInstancedStruct InPayload)
    { RequestBuild(1); }

    UFUNCTION()
    private void Check_OriginalBuilding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(utils_ground_nav_volume::Get_IsBuilding(_Volume) && CountOutcome(1) == 0); }

    UFUNCTION()
    private void Step_Replace(FCk_Handle InHandle, FInstancedStruct InPayload)
    { RequestBuild(2); RequestBuild(3, true); }

    UFUNCTION()
    private void Check_Replaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(CountOutcome(1) == 1 && CountOutcome(2) == 1); }

    UFUNCTION()
    private void Step_DestroyActive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Original = FindOutcome(1);
        const auto Duplicate = FindOutcome(2);
        Assert_True(Original.Get_Admission() == ECk_GroundNav_BuildAdmission::Accepted
            && Original.Get_AttemptSequence() > 0
            && Original.Get_OperationResult() == ECk_Request_OperationResult::Failed_Cancelled
            && Original.Get_HasBakeStatus() == false, "replacement cancels the original admitted request without a stale cause");
        Assert_True(Duplicate.Get_Admission() == ECk_GroundNav_BuildAdmission::AlreadyInProgress
            && Duplicate.Get_AttemptSequence() == 0
            && Duplicate.Get_OperationResult() == ECk_Request_OperationResult::Succeeded
            && Duplicate.Get_HasBakeStatus() == false, "duplicate succeeds immediately as a no-op, not a completed bake");
        Assert_True(utils_ground_nav_volume::Get_IsBuilding(_Volume) && CountOutcome(3) == 0,
            "replacement still owns its distinct outstanding attempt");
        _DestroyOnGeneric = true;
        utils_entity_lifetime::Request_DestroyEntity(_VolumeOwner);
    }

    UFUNCTION()
    private void Check_ActiveGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(CountOutcome(3) == 1 && ck::Is_NOT_Valid(_Volume)); }

    UFUNCTION()
    private void Step_DestroyQueued(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        ComposeVolume(InHandle);
        RequestBuild(4);
        utils_entity_lifetime::Request_DestroyEntity(_VolumeOwner);
    }

    UFUNCTION()
    private void Check_QueuedGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(CountOutcome(4) == 1 && ck::Is_NOT_Valid(_Volume)); }

    UFUNCTION()
    private void Step_GenericDestroysOwner(FCk_Handle InHandle, FInstancedStruct InPayload)
    { ComposeVolume(InHandle); RequestBuild(5); }

    UFUNCTION()
    private void Check_GenericDestroyedOwner(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(CountOutcome(5) == 1 && ck::Is_NOT_Valid(_Volume)); }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Outcomes.Num(), 5, "one typed result per request including successful callback destruction");
        Assert_Equals_Int(_GenericResults.Num(), 5, "one legacy generic result per request despite callback owner cancellation");
        for (int64 Sequence = 1; Sequence <= 5; ++Sequence)
        { Assert_Equals_Int(CountOutcome(Sequence), 1, "request token resolves once"); }
        const auto Active = FindOutcome(3);
        const auto Queued = FindOutcome(4);
        Assert_True(Active.Get_Admission() == ECk_GroundNav_BuildAdmission::Accepted
            && Active.Get_AttemptSequence() > FindOutcome(1).Get_AttemptSequence()
            && Active.Get_OperationResult() == ECk_Request_OperationResult::Failed_Cancelled
            && Active.Get_HasBakeStatus() == false, "active teardown preserves its own admission identity without bake status");
        Assert_True(Queued.Get_Admission() == ECk_GroundNav_BuildAdmission::NotEvaluated
            && Queued.Get_AttemptSequence() == 0
            && Queued.Get_OperationResult() == ECk_Request_OperationResult::Failed_Cancelled
            && Queued.Get_HasBakeStatus() == false, "queued teardown is not an admitted attempt");
        const auto DestroyedAfterSuccess = FindOutcome(5);
        Assert_True(DestroyedAfterSuccess.Get_Admission() == ECk_GroundNav_BuildAdmission::Accepted
            && DestroyedAfterSuccess.Get_OperationResult() == ECk_Request_OperationResult::Succeeded
            && DestroyedAfterSuccess.Get_HasBakeStatus()
            && DestroyedAfterSuccess.Get_BakeStatus() == ECk_GroundNav_BakeStatus::Completed,
            "generic callback destruction cannot replace the copied successful typed cause with cancellation");
        Assert_True(utils_nav_surface::Try_ProjectPoint(FCk_NavSurface_ProjectionQuery(_Origin)).Get_Status()
            != ECk_NavSurface_QueryStatus::Success, "destroyed owned fields leave no registered floor surface");
    }
}
