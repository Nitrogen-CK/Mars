// Pulling a gripped ManuallyCompleted lever past EngageAlpha ends the manipulation and the CkInteraction (Succeeded),
// with the handle resting at the threshold. The Control never moves the Mover's target itself: the Interactable's
// Engage chain does that, and it needs focus, which this headless test does not request.
class UMars_AutoTest_Control_PullPastEngageAlphaEndsTheInteraction : UMars_AutoTestRig_Lever
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Inactive);

        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 5.0f);
        Add_Step("grip the lever", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull until the manipulation ends", n"Check_PullUntilEnded", 0, 5.0f);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 5.0f);
        Add_Step("the interaction succeeded with the handle at the threshold", n"Step_AssertEnded");
        Add_Step_WaitSeconds("let anything that would restart the grip run", 0.3f);
        Add_Step("the manipulation stays ended", n"Step_AssertStaysEnded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _FinishedResults[0];
        Assert_True(Result == ECk_SucceededFailed::Succeeded, f"the threshold ends the interaction Succeeded (got {Result :n})");
        Assert_Equals_Int(_EngagedCount, 0, "no focus, so no Engage chain");

        // Two-sided: the spring overshoots the threshold by one frame's travel, a snap to the far stop is 0.15 off.
        Assert_Equals_Float(_Mover.Get_Alpha(), 0.85, 0.05, "the handle is at the threshold when the interaction ends");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "the Control never moved the target itself");
    }

    UFUNCTION()
    private void Step_AssertStaysEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Control.Get_ManipulationProgress(), 0.0, 0.0001, "no progress once ended");
        Assert_False(_Control.Get_IsManipulating(), "the manipulation stays ended");
    }
}
