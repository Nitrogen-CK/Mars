// A WhileLive target enters Interacting from Idle on a live interaction: nobody focuses the work rig's target when an
// initiator starts an interaction on it, and its state machine runs the work while the interaction stays live
// (ManuallyCompleted). The work succeeding ends the interaction Succeeded, once, and the target rests again.
// Isolated origin (64800, -12000, -30000).
class UMars_AutoTest_Interactable_InteractingEntersFromIdleOnALiveInteraction : UMars_AutoTestRig_WhileLiveWork
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(64800.0, -12000.0, -30000.0);

    private FCk_Handle _Initiator;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_WhileLiveWork(InHandle, k_Origin);
        _Initiator = Add_Initiator(InHandle);

        Add_Step_WaitUntil("the target's state machine rests in Idle", n"Check_TargetIdle", 0, 0);
        Add_Step("nobody focuses the target; the initiator starts an interaction on it", n"Step_AssertUnfocusedAndStart");
        Add_Step_WaitUntil("the target enters Interacting and runs the work", n"Check_TargetInteracting", 0, 0);
        Add_Step("the work runs from Idle while the interaction is live; it succeeds", n"Step_AssertWorkingAndSucceed");
        Add_Step_WaitUntil("the interaction is gone and the target rests in Idle", n"Check_DoneAndIdle", 0, 0);
        Add_Step("the work ended its interaction Succeeded, once", n"Step_AssertSucceeded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertUnfocusedAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Interactable.Get_IsFocused(), "nobody focuses the target");
        Assert_True(utils_interact_target::Get_InteractionCompletionPolicy(_Target) == ECk_Interaction_CompletionPolicy::ManuallyCompleted,
            "a WhileLive target is ManuallyCompleted");

        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Initiator, _Initiator));
    }

    UFUNCTION()
    private void Step_AssertWorkingAndSucceed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Interactable.Get_IsFocused(), "the target entered Interacting without a focus");
        Assert_Equals_Int(Get_Work().Entered, 1, "the work entered once");
        Assert_Valid(utils_interact_target::TryGet_Interaction(_Target, _Initiator), "the interaction is live while the work runs");
        Assert_Equals_Int(_FinishedResults.Num(), 0, "nothing finished the interaction before the work did");

        Set_WorkOutcome(ECk_SmTaskResult::Succeeded);
    }

    UFUNCTION()
    private void Check_DoneAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _Initiator))
            && Get_IsTargetIn(UMars_SmState_Interactable_Idle));
    }

    UFUNCTION()
    private void Step_AssertSucceeded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the interaction finished once");
        if (_FinishedResults.Num() == 1)
        { Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Succeeded, f"the work ended it Succeeded (got [{_FinishedResults[0] :n}])"); }

        Assert_Equals_Int(Get_Work().Entered, 1, "the work ran once");
        Assert_Equals_Int(Get_Work().Exited, 1, "the work's task exited");
    }
}
