// A threshold-ended interaction that finishes Failed settles the handle back to rest: the crossing frame's own
// Succeeded end loses to a Failed end of the same interaction already queued in that frame (a cancel landing as the pull
// crosses EngageAlpha). Nothing engages (no focus, so no Engage chain).
//
// The Failed end is requested from the Control's OnManipulationChanged(Released), which the tick broadcasts in the crossing
// frame just before it requests its own Succeeded end, so the interaction drains Failed first. A cancel sent from a test
// step cannot hit that frame: the spring crosses EngageAlpha frames after the last nudge, and an interaction that
// finished in an earlier frame is gone before the tick binds to it.
class UMars_AutoTest_Control_ThresholdInteractionFailingSettlesBack : UMars_AutoTestRig_Lever
{
    private int32 _FailedEndsRequested = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Inactive);
        _Control.BindTo_OnManipulationChanged(FMars_Delegate_Control_OnManipulationChanged(this, n"OnManipulationChanged"));

        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 5.0f);
        Add_Step("grip the lever", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull until the threshold ends the manipulation (the interaction is ended Failed in that frame)", n"Check_NudgeWhileGripped", 0, 5.0f);
        Add_Step_WaitUntil("the interaction finishes", n"Check_AnyInteractionFinished", 0, 5.0f);
        Add_Step("the interaction finished Failed, once, and nothing engaged", n"Step_AssertFailed");
        Add_Step_WaitUntil("the Failed finish settles the handle back to rest", n"Check_SettledToRest", 0, 5.0f);
        Add_Step("the handle rests at the start pose", n"Step_AssertSettled");
        Run_Steps(InHandle);
    }

    // Broadcast from inside the tick's crossing branch, before the tick requests EndInteraction Succeeded: this Failed
    // end is queued on the interaction first, so it is the outcome the drain broadcasts first.
    UFUNCTION()
    private void OnManipulationChanged(FCk_Handle_Control InControl, EMars_Control_Grip InGrip)
    {
        if (InGrip == EMars_Control_Grip::Gripped)
        { return; }

        _FailedEndsRequested += 1;
        utils_interaction::Request_EndInteraction(_Interaction, FCk_Request_Interaction_EndInteraction(ECk_SucceededFailed::Failed));
    }

    // Nudges only while gripped: no nudge lands after the crossing frame.
    UFUNCTION()
    private void Check_NudgeWhileGripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Control.Get_IsManipulating())
        {
            _Control.Request_Nudge(FMars_Request_Control_Nudge(4.0f));
            Res.Set(false);
            return;
        }

        Res.Set(true);
    }

    UFUNCTION()
    private void Check_AnyInteractionFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FinishedResults.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertFailed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FailedEndsRequested, 1, "the crossing frame broadcast the manipulation's end once");
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the target finishes the interaction once");

        const auto Result = _FinishedResults[0];
        Assert_True(Result == ECk_SucceededFailed::Failed,
            f"the Failed end queued in the crossing frame wins over the threshold's Succeeded (got {Result :n})");
        Assert_Equals_Int(_EngagedCount, 0, "no focus, so no Engage chain");
        Assert_False(_Control.Get_IsManipulating(), "the manipulation stays ended");
    }

    UFUNCTION()
    private void Step_AssertSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "the Control never moved the target itself");
        Assert_False(_Control.Get_IsActive(), "a Failed threshold finish leaves the lever off");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged while the handle settled");
    }
}
