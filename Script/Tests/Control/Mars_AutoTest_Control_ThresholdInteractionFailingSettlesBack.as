// A threshold-ended interaction that finishes Failed settles the handle: the frame the pull crosses EngageAlpha (the
// Control ends the manipulation and requests EndInteraction Succeeded), a cancel races it. If the cancel wins, nothing
// engages and the handle eases back to rest; if the end wins, the handle stays at the threshold as in the plain pull.
// Either way nothing engages here (no focus, so no Engage chain).
class UMars_AutoTest_Control_ThresholdInteractionFailingSettlesBack : UCk_AutoTest_Base
{
    private FCk_Handle_Control _Control;
    private FCk_Handle_Mover _Mover;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_Interaction _Interaction;
    private FCk_Handle _Player;
    private int32 _EngagedCount = 0;
    private TArray<ECk_SucceededFailed> _FinishedResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, false);

        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 5.0f);
        Add_Step("grip the lever", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull until the manipulation ends, then cancel at once", n"Check_PullUntilEndedThenCancel", 0, 5.0f);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 5.0f);
        Add_Step_WaitUntil("a Failed finish settles the handle back to rest", n"Check_SettledIfFailed", 0, 5.0f);
        Add_Step("nothing engaged and the handle matches the race's winner", n"Step_AssertOutcome");
        Run_Steps(InHandle);
    }

    private void BuildLever(FCk_Handle InHandle, bool InStartActive)
    {
        _Player = InHandle;
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandleNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndRotation = FRotator(70.0, 0.0, 0.0);
        MoverSpec.Duration = 0.3f;
        MoverSpec.StartAtEnd = InStartActive;
        _Mover = utils_mover::Add(HandleNode, MoverSpec);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.StartActive = InStartActive;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        _Control = utils_control::Add(RootEntity, ControlSpec, _Mover);
        _Control.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnEngaged"));

        // No ProbeInfo: a transform-only child; the test drives the interaction without focus.
        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(_Control.Make_InteractTarget(FText::FromString("Pull")));
        _Interactable = utils_interactable::Create(Root, Spec);
        _Target = _Interactable.Get_AllInteractTargets()[0];
        _Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinished"));
    }

    UFUNCTION()
    private void OnEngaged(FCk_Handle_Control InControl)
    {
        _EngagedCount += 1;
    }

    UFUNCTION()
    private void OnNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        _Interaction = InInteraction;
    }

    UFUNCTION()
    private void OnFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }

    UFUNCTION()
    private void Step_StartInteraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));
    }

    UFUNCTION()
    private void Check_HasInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Interaction));
    }

    UFUNCTION()
    private void Step_BeginManipulation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(_Interaction, _Player));
    }

    UFUNCTION()
    private void Check_IsManipulating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating());
    }

    // The first evaluation that reads the manipulation ended is the frame the Control requested EndInteraction: the
    // cancel goes out in that same frame.
    UFUNCTION()
    private void Check_PullUntilEndedThenCancel(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Control.Get_IsManipulating())
        {
            _Control.Request_Nudge(FMars_Request_Control_Nudge(4.0f));
            Res.Set(false);
            return;
        }

        _Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
        Res.Set(true);
    }

    UFUNCTION()
    private void Check_InteractionFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FinishedResults.Num() >= 1);
    }

    UFUNCTION()
    private void Check_SettledIfFailed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_FinishedResults[0] == ECk_SucceededFailed::Succeeded)
        {
            Res.Set(true);
            return;
        }

        Res.Set(_Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    private void Step_AssertOutcome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the target finishes the interaction once");
        Assert_Equals_Int(_EngagedCount, 0, "no focus, so no Engage chain");
        Assert_False(_Control.Get_IsManipulating(), "the manipulation stays ended");
        Assert_False(_Mover.Get_AtEnd(), "the Control never moved the target itself");

        const auto Alpha = _Mover.Get_Alpha();
        if (_FinishedResults[0] == ECk_SucceededFailed::Succeeded)
        {
            ck::Trace(f"[ThresholdInteractionFailingSettlesBack] race outcome: Succeeded (the end won; alpha {Alpha})");
            Assert_True(Alpha >= 0.85f - 0.02f, f"the end won the race: the handle stays at the threshold (alpha {Alpha})");
            return;
        }

        ck::Trace(f"[ThresholdInteractionFailingSettlesBack] race outcome: Failed (the cancel won; alpha {Alpha})");
        Assert_True(Alpha < 0.01f, f"the cancel won the race: the handle settled back to rest (alpha {Alpha})");
    }
}
