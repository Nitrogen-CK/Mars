// A WhileLive target takes one interaction at a time: its work is one initiator's until it ends. With the work rig's
// interaction live for a first initiator, a second initiator's start is refused (the framework answers
// TargetRejectedSecondInteraction): once that start has drained, the second has no interaction and the work still runs once,
// for the first. When the first's work is done, the second's start is taken and the work runs for it. Isolated origin
// (71600, -12000, -30000).
class UMars_AutoTest_Interactable_AWhileLiveTargetTakesOneInteractionAtATime : UMars_AutoTestRig_WhileLiveWork
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(71600.0, -12000.0, -30000.0);

    private FCk_Handle _First;
    private FCk_Handle _Second;
    private bool _SecondStartDrained = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_WhileLiveWork(InHandle, k_Origin);
        _First = Add_Initiator(InHandle);
        _Second = Add_Initiator(InHandle);

        Add_Step_WaitUntil("the target's state machine rests in Idle", n"Check_TargetIdle", 0, 0);
        Add_Step("the first initiator starts an interaction", n"Step_FirstStarts");
        Add_Step_WaitUntil("the target runs the first initiator's work", n"Check_FirstWorkRuns", 0, 0);
        Add_Step("the second initiator is refused up front; it starts anyway", n"Step_SecondStarts");
        Add_Step_WaitUntil("the second start has drained", n"Check_SecondStartDrained", 0, 0);
        Add_Step("the second has no interaction; the first's is live and its work ran once; it succeeds", n"Step_AssertRefusedAndFinishFirst");
        Add_Step_WaitUntil("the first initiator's interaction is gone and the target left Interacting", n"Check_FirstDone", 0, 0);
        Add_Step("the second initiator starts again", n"Step_SecondStartsAgain");
        Add_Step_WaitUntil("the target runs the second initiator's work", n"Check_SecondWorkRuns", 0, 0);
        Add_Step("the work names the second initiator; it succeeds", n"Step_AssertSecondAndFinish");
        Add_Step_WaitUntil("the second initiator's interaction is gone", n"Check_SecondDone", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_FirstStarts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_First, _First));
    }

    UFUNCTION()
    private void Check_FirstWorkRuns(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTargetIn(UMars_SmState_Interactable_Interacting) && Get_Work().Entered == 1);
    }

    UFUNCTION()
    private void Step_SecondStarts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto CanInteract = utils_interact_target::Get_CanInteractWith(_Target, _Second);
        Assert_True(CanInteract == ECk_CanInteractWithResult::TargetRejectedSecondInteraction,
            f"the target rejects a second interaction while the first is live (got {CanInteract :n})");

        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Second, _Second),
            FCk_Delegate_Request_OnCompleted(this, n"OnSecondStartDrained"));
    }

    UFUNCTION()
    private void OnSecondStartDrained(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        _SecondStartDrained = true;
    }

    UFUNCTION()
    private void Check_SecondStartDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SecondStartDrained);
    }

    UFUNCTION()
    private void Step_AssertRefusedAndFinishFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Second)), "the second initiator has no interaction");
        Assert_True(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _First)), "the first initiator's interaction is still live");
        Assert_Equals_Int(Get_Work().Entered, 1, "the work ran once");
        Assert_True(Get_Work().LastInitiator == _First, "the work runs for the first initiator");
        Set_WorkOutcome(ECk_SmTaskResult::Succeeded);
    }

    UFUNCTION()
    private void Check_FirstDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _First))
            && Get_IsTargetIn(UMars_SmState_Interactable_Interacting) == false);
    }

    UFUNCTION()
    private void Step_SecondStartsAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Set_WorkOutcome(ECk_SmTaskResult::Running);
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Second, _Second));
    }

    UFUNCTION()
    private void Check_SecondWorkRuns(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTargetIn(UMars_SmState_Interactable_Interacting) && Get_Work().Entered == 2);
    }

    UFUNCTION()
    private void Step_AssertSecondAndFinish(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_Work().LastInitiator == _Second, "the second work runs for the second initiator");
        Set_WorkOutcome(ECk_SmTaskResult::Succeeded);
    }

    UFUNCTION()
    private void Check_SecondDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _Second)) && _FinishedResults.Num() == 2);
    }
}
