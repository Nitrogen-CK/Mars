// A WhileLive interaction cancelled from outside its work stops the work: the initiator's interaction on the work rig's
// target is cancelled while the work still runs, so it finishes Failed, Interacting is left with the work's task torn down
// before it decided anything, and the target rests again. Isolated origin (66400, -12000, -30000).
class UMars_AutoTest_Interactable_ACancelledInteractionStopsTheSubSm : UMars_AutoTestRig_WhileLiveWork
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(66400.0, -12000.0, -30000.0);

    private FCk_Handle _Initiator;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_WhileLiveWork(InHandle, k_Origin);
        _Initiator = Add_Initiator(InHandle);

        Add_Step_WaitUntil("the target's state machine rests in Idle", n"Check_TargetIdle", 0, 0);
        Add_Step("the initiator starts an interaction on the target", n"Step_Start");
        Add_Step_WaitUntil("the target enters Interacting and runs the work", n"Check_TargetInteracting", 0, 0);
        Add_Step("cancel the initiator's interaction while the work runs", n"Step_Cancel");
        Add_Step_WaitUntil("the interaction is gone and the target left Interacting", n"Check_GoneAndLeft", 0, 0);
        Add_Step("the interaction finished Failed once and the work stopped undecided", n"Step_AssertStopped");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Initiator, _Initiator));
    }

    UFUNCTION()
    private void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_Work().Exited, 0, "the work still runs");
        _Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Initiator));
    }

    UFUNCTION()
    private void Check_GoneAndLeft(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _Initiator))
            && Get_IsTargetIn(UMars_SmState_Interactable_Interacting) == false);
    }

    UFUNCTION()
    private void Step_AssertStopped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the interaction finished once");
        if (_FinishedResults.Num() == 1)
        { Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Failed, f"a cancelled interaction finishes Failed (got [{_FinishedResults[0] :n}])"); }

        Assert_Equals_Int(Get_Work().Entered, 1, "the work ran once");
        Assert_Equals_Int(Get_Work().Exited, 1, "the cancel tore the work's task down");
        Assert_True(Get_Work().Outcome == ECk_SmTaskResult::Running, "the work never decided an outcome");
    }
}
