// A lever manipulation begun by the player's ManipulateControl task at the grip engages at the threshold: pulling past
// EngageAlpha ends the CkInteraction Succeeded and the Interactable's Engage chain toggles the Control on. Regression
// for the task forwarding an invalid interaction to the Control (the pending slot was cleared before it was passed on):
// the handle still followed the pull, but the threshold found no interaction to end, so nothing engaged. The lever's
// Interactable is focused so its HFSM can reach Interacting and run the Engage.
class UMars_AutoTest_Control_GripBegunManipulationEngagesAtThreshold : UMars_AutoTestRig_LeverThroughPlayer
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 5.0f);
        Add_Step("focus the lever", n"Step_FocusLever");
        Add_Step_WaitUntil("the lever's interact target is Focused", n"Check_TargetFocused", 0, 5.0f);
        Add_Step("add the lever to the resolver and open Use", n"Step_UseLever");
        Add_Step_WaitUntil("the gloves grip and the lever is manipulated", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull until the manipulation ends", n"Check_PullUntilEnded", 0, 5.0f);
        Add_Step_WaitUntil("the lever engages", n"Check_Engaged", 0, 5.0f);
        Add_Step_WaitSeconds("let a second engage or finish land", 0.2f);
        Add_Step("the threshold ended the interaction Succeeded and toggled the lever on once", n"Step_AssertEngaged");
        Run_Steps(InHandle);
    }

    // Stands in for the player's InteractionFocus task: without focus the Interactable's HFSM never reaches Interacting.
    UFUNCTION()
    private void Step_FocusLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Player));
    }

    UFUNCTION()
    private void Check_TargetFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    private void Check_Engaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_EngagedCount >= 1);
    }

    UFUNCTION()
    private void Step_AssertEngaged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_EngagedCount, 1, "the threshold engaged the lever exactly once");
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the interaction finished once");
        if (_FinishedResults.Num() > 0)
        {
            Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Succeeded,
                f"the threshold ended the interaction Succeeded (got {_FinishedResults[0] :n})");
        }

        Assert_True(_Control.Get_IsActive(), "the toggle lever is on after the engage");
    }
}
