// An active lever is gripped where its handle stands (the far stop) and pulls back toward the start: pushing further
// into the stop does nothing, and pulling past EngageAlpha toward the start ends the interaction Succeeded. The Mover's
// target stays the end pose; the Engage chain, not the Control, would flip it.
class UMars_AutoTest_Control_PullFromActiveTowardStartEngagesOff : UCk_AutoTest_Base
{
    private FCk_Handle_Control _Control;
    private FCk_Handle_Mover _Mover;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_Interaction _Interaction;
    private FCk_Handle _Player;
    private int32 _EngagedCount = 0;
    private TArray<ECk_SucceededFailed> _FinishedResults;
    private int32 _PushesIntoStop = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle, true);

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
    private void Step_AssertStartsActive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mover.Get_Alpha() > 0.999f, f"the handle starts at the far stop (alpha {_Mover.Get_Alpha()})");
        Assert_True(_Control.Get_IsActive(), "the control starts active");
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

    UFUNCTION()
    private void Step_AssertClamped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Control.Get_ManipulationAlpha();
        Assert_True(Alpha >= 0.999f, f"the end stop clamps (manipulation alpha {Alpha})");
        Assert_True(_Control.Get_IsManipulating(), "pushing into the stop does not end the grip");
    }

    UFUNCTION()
    private void Check_PullBackUntilEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Control.Request_Nudge(FMars_Request_Control_Nudge(-4.0f));

        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Check_InteractionFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FinishedResults.Num() == 1);
    }

    UFUNCTION()
    private void Step_AssertEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Succeeded, "pulling past EngageAlpha toward the start ends the interaction Succeeded");
        Assert_Equals_Int(_EngagedCount, 0, "no focus, so no Engage chain");

        const auto Alpha = _Mover.Get_Alpha();
        Assert_True(Alpha <= 0.15f + 0.02f, f"the handle is at the threshold when the interaction ends (alpha {Alpha})");
        Assert_True(_Mover.Get_AtEnd(), "the Control never moved the target itself");
    }
}
