// After a pull let go before its threshold (Use released: the interaction cancelled), the focus moving to a second
// ManuallyCompleted control with Use up starts nothing there: no interaction, no grip, for a second; a fresh press then
// starts one. Through the player's real ManipulateControl, UseIntentToResolver and Hands tasks: lever A is the rig's,
// lever B is a second ManuallyCompleted control 300 cm off; the focus is the resolver's offered targets (A withdrawn, B
// offered, as the focus task does when the view turns). Guards the run-12b press-less grip on the Use path (PROGRESS,
// Phase K Part 2c).
class UMars_AutoTest_Control_ACancelledPullStartsNothingOnTheNextFocus : UMars_AutoTestRig_LeverThroughPlayer
{
    default _TimeoutSeconds = 20.0f;

    private FCk_Handle_Control _ControlB;
    private FCk_Handle_InteractTarget _TargetB;
    private int32 _InteractionsOnB = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildPlayerAndLever(InHandle, FMars_FPHands_Spec());
        Build_LeverB(InHandle);
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 0);
        Add_Steps_UseRowLive();
        Add_Step("offer lever A and press Use", n"Step_UseLever");
        Add_Step_WaitUntil("the gloves grip lever A and it is manipulated", n"Check_IsManipulating", k_SlowPolls, 0);
        Add_Step("let go of Use before the threshold", n"Step_ReleaseUse");
        Add_Step_WaitUntil("lever A's interaction finishes", n"Check_InteractionFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves are back at rest", n"Check_HandsRest", k_SlowPolls, 0);
        Add_Step("the focus moves: withdraw lever A, offer lever B, Use up", n"Step_MoveFocus");
        Add_Step_WaitSeconds("a press-less start would land in this window", 1.0f);
        Add_Step("nothing started on lever B", n"Step_AssertNothingOnB");
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitUntil("the fresh press starts lever B's interaction", n"Check_InteractionOnB", k_SlowPolls, 0);
        Add_Step("release Use", n"Step_ReleaseUse");
        Run_Steps(InHandle);
    }

    // A second ManuallyCompleted control, without a Mover, its target transform-only like lever A's.
    private void Build_LeverB(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 300.0, 0.0)), ECk_Replication::DoesNotReplicate);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        _ControlB = utils_control::Add(RootEntity, ControlSpec);

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(_ControlB.Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Pull B"))));
        auto Interactable = utils_interactable::Create(Root, Spec);
        _TargetB = Interactable.Get_AllInteractTargets()[0];
        _TargetB.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteractionB"));
    }

    UFUNCTION()
    private void OnNewInteractionB(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        ++_InteractionsOnB;
    }

    UFUNCTION()
    private void Step_MoveFocus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_FinishedResults.Num() == 1 && _FinishedResults[0] == ECk_SucceededFailed::Failed, "lever A's let-go pull finished Failed");
        Assert_False(Get_IsUseHeld(), "Use is up");
        _Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(_Target));
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_TargetB));
    }

    UFUNCTION()
    private void Step_AssertNothingOnB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_InteractionsOnB, 0, "no interaction started on lever B with Use up");
        Assert_False(ck::IsValid(utils_interact_target::TryGet_Interaction(_TargetB, _Player)), "lever B has no live interaction");
        Assert_False(_ControlB.Get_IsManipulating(), "lever B is not gripped");
        Assert_False(_Hands.Get_IsReachTarget(_TargetB), "the gloves never reached for lever B");
    }

    UFUNCTION()
    private void Check_InteractionOnB(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_InteractionsOnB >= 1);
    }
}
