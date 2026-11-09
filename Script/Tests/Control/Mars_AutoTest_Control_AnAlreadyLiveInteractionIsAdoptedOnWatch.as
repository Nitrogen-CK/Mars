// An interaction already live on a ManuallyCompleted lever from the player when the player's ManipulateControl task starts
// watching it (as one the Primary intent started on the shared key would be) is adopted: the gloves reach and grip, the
// manipulation begins, and a pull past the threshold ends the interaction Succeeded. The interaction is started on the
// lever's target before the resolver is offered it; then the lever is offered and Use pressed (the Use task joins the live
// interaction instead of starting one).
class UMars_AutoTest_Control_AnAlreadyLiveInteractionIsAdoptedOnWatch : UMars_AutoTestRig_LeverThroughPlayer
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 0);
        Add_Steps_UseRowLive();
        Add_Step("start the lever's interaction before the task watches it", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction is live", n"Check_HasInteraction", 0, 0);
        Add_Step("not manipulated yet; offer the lever and press Use", n"Step_AssertUnwatchedAndUseLever");
        Add_Step_WaitUntil("the gloves grip and the lever is manipulated", n"Check_IsManipulating", k_SlowPolls, 0);
        Add_Step("the adopted interaction is the one manipulated", n"Step_AssertAdopted");
        Add_Step_WaitUntil("pull until the threshold ends the manipulation", n"Check_PullUntilEnded", 0, 0);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 0);
        Add_Step("the threshold ended it Succeeded", n"Step_AssertSucceeded");
        Add_Step("release Use", n"Step_ReleaseUse");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertUnwatchedAndUseLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_NewInteractionCount, 1, "one interaction started, before any watch");
        Assert_False(_Control.Get_IsManipulating(), "nothing manipulates the lever before the task watches it");
        UseLever();
    }

    UFUNCTION()
    private void Step_AssertAdopted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_NewInteractionCount, 1, "the Use press joined the live interaction instead of starting another");
        Assert_True(_Hands.Get_IsGrippingTarget(_Target), "the gloves grip the lever");
        Assert_True(_Control.Get_Fragment(FMars_Fragment_Control).Manipulation.GetValue().Interaction == _Interaction,
            "the manipulation carries the adopted interaction (the threshold ends it)");
    }

    UFUNCTION()
    private void Step_AssertSucceeded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _FinishedResults[0];
        Assert_True(Result == ECk_SucceededFailed::Succeeded, f"the threshold ends the adopted interaction Succeeded (got {Result :n})");
    }
}
