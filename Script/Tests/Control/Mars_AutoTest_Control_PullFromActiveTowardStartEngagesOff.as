// An active lever is gripped where its handle stands (the far stop) and pulls back toward the start: pushing further
// into the stop does nothing, and pulling past EngageAlpha toward the start ends the interaction Succeeded. At the finish
// the Mover's target is still the end pose; the Succeeded finish then runs the Engage chain without any focus, which
// engages the lever off once and flips the target to the start pose.
class UMars_AutoTest_Control_PullFromActiveTowardStartEngagesOff : UMars_AutoTestRig_Lever
{
    private int32 _PushesIntoStop = 0;
    private TOptional<float32> _AlphaAtFinish;
    private TOptional<EMars_Mover_Pose> _TargetAtFinish;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Active);
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinishedRecordHandle"));

        Add_Step("the lever starts pulled over", n"Step_AssertStartsActive");
        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 0);
        Add_Step("grip the lever", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 0);
        Add_Step("the grip is seeded from the Mover", n"Step_AssertSeeded");
        Add_Step_WaitUntil("push three times into the far stop", n"Check_PushIntoStop", 0, 0);
        Add_Step_WaitSeconds("let the pushes drain", 0.1f);
        Add_Step("the end stop clamps", n"Step_AssertClamped");
        Add_Step_WaitUntil("pull toward the start until the manipulation ends", n"Check_PullBackUntilEnded", 0, 0);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 0);
        Add_Step("the interaction succeeded with the handle at the threshold and the target untouched", n"Step_AssertEnded");
        Add_Step_WaitUntil("the Succeeded finish runs the Engage chain", n"Check_Engaged", 0, 0);
        Add_Step("the lever engaged off once", n"Step_AssertEngagedOff");
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
    private void Step_AssertStartsActive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mover.Get_Alpha() > 0.999f, f"the handle starts at the far stop (alpha {_Mover.Get_Alpha()})");
        Assert_True(_Control.Get_IsActive(), "the control starts active");
    }

    UFUNCTION()
    private void Step_AssertSeeded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Control.Get_ManipulationAlpha();
        Assert_True(Alpha > 0.999f, f"seeded from the Mover (manipulation alpha {Alpha})");
    }

    UFUNCTION()
    private void Check_PushIntoStop(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_PushesIntoStop >= 3)
        {
            Res.Set(true);
            return;
        }

        _Control.Request_Nudge(FMars_Request_Control_Nudge(4.0f));
        _PushesIntoStop += 1;
        Res.Set(false);
    }

    // The pull, not the alpha: the spring clamps Alpha at the stop on its own, so only Pull shows the nudges were clamped.
    UFUNCTION()
    private void Step_AssertClamped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Control.Get_IsManipulating(), "pushing into the stop does not end the grip");
        if (_Control.Get_IsManipulating())
        {
            const auto Pull = _Control.Get_Fragment(FMars_Fragment_Control).Manipulation.GetValue().Pull;
            Assert_Equals_Float(Pull, 1.0, 0.0001, "three pushes into the far stop leave the pull clamped at 1");
        }
    }

    UFUNCTION()
    private void Check_PullBackUntilEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Control.Request_Nudge(FMars_Request_Control_Nudge(-4.0f));

        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Step_AssertEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _FinishedResults[0];
        Assert_True(Result == ECk_SucceededFailed::Succeeded,
            f"pulling past EngageAlpha toward the start ends the interaction Succeeded (got {Result :n})");

        if (_AlphaAtFinish.IsSet() == false || _TargetAtFinish.IsSet() == false)
        {
            FinishFailure("the finish recorded no handle state");
            return;
        }

        // Two-sided: the spring overshoots the threshold by one frame's travel, a snap to the start stop is 0.15 off.
        Assert_Equals_Float(_AlphaAtFinish.GetValue(), 0.15, 0.05, "the handle is at the threshold when the interaction ends");
        Assert_True(_TargetAtFinish.GetValue() == EMars_Mover_Pose::End, "the Control never moved the target itself");
    }

    UFUNCTION()
    private void Check_Engaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_EngagedCount >= 1);
    }

    UFUNCTION()
    private void Step_AssertEngagedOff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_EngagedCount, 1, "the Succeeded finish engaged the lever once");
        Assert_False(_Control.Get_IsActive(), "engaging the active toggle lever turns it off");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "the Engage chain flipped the target to the start pose");
    }
}
