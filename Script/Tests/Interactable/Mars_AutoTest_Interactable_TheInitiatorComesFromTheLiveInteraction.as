// A WhileLive interaction's work runs for whoever started it, read from the live interaction (no record of the latest
// start): with the work rig's target focused by one initiator, a second one starts an interaction and the work's sub-SM
// root names the second; once that work is done, the focuser's own interaction runs a work that names the focuser.
// Isolated origin (68000, -12000, -30000).
class UMars_AutoTest_Interactable_TheInitiatorComesFromTheLiveInteraction : UMars_AutoTestRig_WhileLiveWork
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(68000.0, -12000.0, -30000.0);

    private FCk_Handle _Focuser;
    private FCk_Handle _Other;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_WhileLiveWork(InHandle, k_Origin);
        _Focuser = Add_Initiator(InHandle);
        _Other = Add_Initiator(InHandle);

        Add_Step_WaitUntil("the target's state machine rests in Idle", n"Check_TargetIdle", 0, 0);
        Add_Step("the focuser focuses the target; the other initiator starts an interaction on it", n"Step_FocusAndOtherStarts");
        Add_Step_WaitUntil("the target runs the other initiator's work", n"Check_FirstWorkRuns", 0, 0);
        Add_Step("the work names the other initiator; it succeeds", n"Step_AssertOtherAndSucceed");
        Add_Step_WaitUntil("the other initiator's interaction is gone", n"Check_OtherDone", 0, 0);
        Add_Step("the focuser starts an interaction of its own", n"Step_FocuserStarts");
        Add_Step_WaitUntil("the target runs the focuser's work", n"Check_SecondWorkRuns", 0, 0);
        Add_Step("the work names the focuser; it succeeds", n"Step_AssertFocuserAndSucceed");
        Add_Step_WaitUntil("the focuser's interaction is gone", n"Check_FocuserDone", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_FocusAndOtherStarts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Focuser));
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Other, _Other));
    }

    UFUNCTION()
    private void Check_FirstWorkRuns(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTargetIn(UMars_SmState_Interactable_Interacting) && Get_Work().Entered == 1);
    }

    UFUNCTION()
    private void Step_AssertOtherAndSucceed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Interactable.Get_CurrentFocuser() == _Focuser, "the focuser focuses the target");
        Assert_True(Get_Work().LastInitiator == _Other, "the work runs for the initiator of the live interaction, not the focuser");
        Set_WorkOutcome(ECk_SmTaskResult::Succeeded);
    }

    UFUNCTION()
    private void Check_OtherDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _Other))
            && Get_IsTargetIn(UMars_SmState_Interactable_Interacting) == false);
    }

    UFUNCTION()
    private void Step_FocuserStarts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Set_WorkOutcome(ECk_SmTaskResult::Running);
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Focuser, _Focuser));
    }

    UFUNCTION()
    private void Check_SecondWorkRuns(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTargetIn(UMars_SmState_Interactable_Interacting) && Get_Work().Entered == 2);
    }

    UFUNCTION()
    private void Step_AssertFocuserAndSucceed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_Work().LastInitiator == _Focuser, "the second work runs for the focuser, who started it");
        Set_WorkOutcome(ECk_SmTaskResult::Succeeded);
    }

    UFUNCTION()
    private void Check_FocuserDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _Focuser))
            && _FinishedResults.Num() == 2);
    }
}
