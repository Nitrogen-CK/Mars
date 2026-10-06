// Letting go of a gripped lever before EngageAlpha settles the handle back to its rest pose and leaves the interaction
// running; nothing engages. Cancelling the interaction afterwards finishes it Failed.
class UMars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack : UMars_AutoTestRig_Lever
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, EMars_Control_Activation::Inactive);

        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 5.0f);
        Add_Step("grip the lever", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull a third of the way", n"Check_PullPartWay", 0, 5.0f);
        Add_Step("still gripped, nothing finished", n"Step_AssertPartWay");
        Add_Step("let go", n"Step_EndManipulation");
        Add_Step_WaitUntil("the handle settles back to rest", n"Check_SettledToRest", 0, 5.0f);
        Add_Step("released without engaging", n"Step_AssertReleased");
        Add_Step("cancel the still-live interaction", n"Step_CancelInteraction");
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 5.0f);
        Add_Step("a cancel finishes Failed", n"Step_AssertCancelled");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PullPartWay(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Control.Get_ManipulationAlpha() > 0.35f)
        {
            Res.Set(true);
            return;
        }

        _Control.Request_Nudge(FMars_Request_Control_Nudge(1.0f));
        Res.Set(false);
    }

    UFUNCTION()
    private void Step_AssertPartWay(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Control.Get_IsManipulating(), "still gripped a third of the way over");
        Assert_Equals_Int(_FinishedResults.Num(), 0, "the interaction has not finished");
    }

    UFUNCTION()
    private void Step_EndManipulation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Control.Request_EndManipulation();
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Control.Get_IsManipulating(), "let go");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "the target is still the rest pose");
        Assert_Equals_Float(_Control.Get_ManipulationProgress(), 0.0, 0.0001, "no progress once released");
    }

    UFUNCTION()
    private void Step_CancelInteraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _FinishedResults[0];
        Assert_True(Result == ECk_SucceededFailed::Failed, f"a cancel finishes the interaction Failed (got {Result :n})");
        Assert_False(_Control.Get_IsManipulating(), "a late cancel does not re-grip");
    }
}
