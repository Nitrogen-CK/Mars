// An active lever is gripped where its handle stands (the far stop) and pulls back toward the start: pushing further
// into the stop does nothing, and pulling past EngageAlpha toward the start ends the interaction Succeeded. The Mover's
// target stays the end pose; the Engage chain, not the Control, would flip it.
class UMars_AutoTest_Control_PullFromActiveTowardStartEngagesOff : UMars_AutoTestRig_Lever
{
    private int32 _PushesIntoStop = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Active);

        Add_Step("the lever starts pulled over", n"Step_AssertStartsActive");
        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 5.0f);
        Add_Step("grip the lever", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 5.0f);
        Add_Step("the grip is seeded from the Mover", n"Step_AssertSeeded");
        Add_Step_WaitUntil("push three times into the far stop", n"Check_PushIntoStop", 0, 5.0f);
        Add_Step_WaitSeconds("let the pushes drain", 0.1f);
        Add_Step("the end stop clamps", n"Step_AssertClamped");
        Add_Step_WaitUntil("pull toward the start until the manipulation ends", n"Check_PullBackUntilEnded", 0, 5.0f);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 5.0f);
        Add_Step("the interaction succeeded with the handle at the threshold", n"Step_AssertEnded");
        Run_Steps(InHandle);
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
        Assert_Equals_Int(_EngagedCount, 0, "no focus, so no Engage chain");

        // Two-sided: the spring overshoots the threshold by one frame's travel, a snap to the start stop is 0.15 off.
        Assert_Equals_Float(_Mover.Get_Alpha(), 0.15, 0.05, "the handle is at the threshold when the interaction ends");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::End, "the Control never moved the target itself");
    }
}
