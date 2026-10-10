// Pulling a gripped ManuallyCompleted lever past EngageAlpha ends the manipulation and the CkInteraction (Succeeded),
// with the handle resting at the threshold. The Control never moves the Mover's target itself: at the finish the target
// is still the rest pose. The Succeeded finish then runs the Interactable's Engage chain without any focus, which engages
// the lever once and flips the target.
class UMars_AutoTest_Control_PullPastEngageAlphaEndsTheInteraction : UMars_AutoTestRig_Lever
{
    private TOptional<float32> _AlphaAtFinish;
    private TOptional<EMars_Mover_Pose> _TargetAtFinish;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Inactive);
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinishedRecordHandle"));

        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 0);
        Add_Step("grip the lever", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 0);
        Add_Step_WaitUntil("pull until the manipulation ends", n"Check_PullUntilEnded", 0, 0);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 0);
        Add_Step("the interaction succeeded with the handle at the threshold and the target untouched", n"Step_AssertEnded");
        Add_Step_WaitUntil("the Succeeded finish runs the Engage chain", n"Check_Engaged", 0, 0);
        Add_Step_WaitSeconds("let anything that would restart the grip or engage again run", 0.3f);
        Add_Step("the lever engaged once and the manipulation stays ended", n"Step_AssertEngagedOnceAndStaysEnded");
        Run_Steps(InHandle);
    }

    // The handle as the finish leaves it, before the Engage chain can move the target.
    UFUNCTION()
    private void OnFinishedRecordHandle(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _AlphaAtFinish = TOptional<float32>(_Mover.Get_Alpha());
        _TargetAtFinish = TOptional<EMars_Mover_Pose>(_Mover.Get_Target());
    }

    UFUNCTION()
    private void Step_AssertEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _FinishedResults[0];
        Assert_True(Result == ECk_SucceededFailed::Succeeded, f"the threshold ends the interaction Succeeded (got {Result :n})");

        if (_AlphaAtFinish.IsSet() == false || _TargetAtFinish.IsSet() == false)
        {
            FinishFailure("the finish recorded no handle state");
            return;
        }

        // Two-sided: the spring overshoots the threshold by one frame's travel, a snap to the far stop is 0.15 off.
        Assert_Equals_Float(_AlphaAtFinish.GetValue(), 0.85, 0.05, "the handle is at the threshold when the interaction ends");
        Assert_True(_TargetAtFinish.GetValue() == EMars_Mover_Pose::Start, "the Control never moved the target itself");
    }

    UFUNCTION()
    private void Check_Engaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_EngagedCount >= 1);
    }

    UFUNCTION()
    private void Step_AssertEngagedOnceAndStaysEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_EngagedCount, 1, "the Succeeded finish engaged the lever once");
        Assert_True(_Control.Get_IsActive(), "the engaged lever is active");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::End, "the Engage chain flipped the target to the end pose");
        Assert_Equals_Float(_Control.Get_ManipulationProgress(), 0.0, 0.0001, "no progress once ended");
        Assert_False(_Control.Get_IsManipulating(), "the manipulation stays ended");
    }
}
