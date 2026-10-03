// A threshold-ended interaction that finishes Failed settles the handle back to rest: the crossing frame's own
// Succeeded end loses to a Failed end of the same interaction already queued in that frame (a cancel landing as the pull
// crosses EngageAlpha). Nothing engages (no focus, so no Engage chain).
//
// The Failed end is requested from the Control's OnManipulationChanged(Released), which the tick broadcasts in the crossing
// frame just before it requests its own Succeeded end, so the interaction drains Failed first. A cancel sent from a test
// step cannot hit that frame: the spring crosses EngageAlpha frames after the last nudge, and an interaction that
// finished in an earlier frame is gone before the tick binds to it.
class UMars_AutoTest_Control_ThresholdInteractionFailingSettlesBack : UCk_AutoTest_Base
{
    private FCk_Handle_Control _Control;
    private FCk_Handle_Mover _Mover;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_Interaction _Interaction;
    private FCk_Handle _Player;
    private int32 _EngagedCount = 0;
    private int32 _FailedEndsRequested = 0;
    private TArray<ECk_SucceededFailed> _FinishedResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, false);

        Add_Step("start the interaction", n"Step_StartInteraction");
        Add_Step_WaitUntil("the interaction exists", n"Check_HasInteraction", 0, 5.0f);
        Add_Step("grip the lever", n"Step_BeginManipulation");
        Add_Step_WaitUntil("the lever is gripped", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull until the threshold ends the manipulation (the interaction is ended Failed in that frame)", n"Check_PullUntilEnded", 0, 5.0f);
        Add_Step_WaitUntil("the interaction finishes", n"Check_InteractionFinished", 0, 5.0f);
        Add_Step("the interaction finished Failed, once, and nothing engaged", n"Step_AssertFailed");
        Add_Step_WaitUntil("the Failed finish settles the handle back to rest", n"Check_SettledToRest", 0, 5.0f);
        Add_Step("the handle rests at the start pose", n"Step_AssertSettled");
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
        MoverSpec.StartPose = InStartActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start;
        _Mover = utils_mover::Add(HandleNode, MoverSpec);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.StartActive = InStartActive;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        _Control = utils_control::Add(RootEntity, ControlSpec, _Mover);
        _Control.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnEngaged"));
        _Control.BindTo_OnManipulationChanged(FMars_Delegate_Control_OnManipulationChanged(this, n"OnManipulationChanged"));

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

    UFUNCTION()
    private void Check_PullUntilEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
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
    private void Check_InteractionFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
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
    private void Check_SettledToRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    private void Step_AssertSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "the Control never moved the target itself");
        Assert_False(_Control.Get_IsActive(), "a Failed threshold finish leaves the lever off");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged while the handle settled");
    }
}
