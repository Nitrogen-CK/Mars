// Letting go of a gripped lever before EngageAlpha settles the handle back to its rest pose and leaves the interaction
// running; nothing engages. Cancelling the interaction afterwards finishes it Failed.
class UMars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack : UCk_AutoTest_Base
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
    private void Check_SettledToRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Control.Get_IsManipulating(), "let go");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged");
        Assert_False(_Mover.Get_AtEnd(), "the target is still the rest pose");
        Assert_Equals_Float(_Control.Get_ManipulationProgress(), 0.0, 0.0001, "no progress once released");
    }

    UFUNCTION()
    private void Step_CancelInteraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
    }

    UFUNCTION()
    private void Check_InteractionFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FinishedResults.Num() == 1);
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Failed, "a cancel finishes the interaction Failed");
        Assert_False(_Control.Get_IsManipulating(), "a late cancel does not re-grip");
    }
}
