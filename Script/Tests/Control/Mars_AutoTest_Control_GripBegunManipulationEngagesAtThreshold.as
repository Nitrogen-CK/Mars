// A lever manipulation begun by the player's ManipulateControl task at the grip engages at the threshold: pulling past
// EngageAlpha ends the CkInteraction Succeeded and the Interactable's Engage chain toggles the Control on. Regression
// for the task forwarding an invalid interaction to the Control (the pending slot was cleared before it was passed on):
// the handle still followed the pull, but the threshold found no interaction to end, so nothing engaged. The lever's
// Interactable is focused so its HFSM can reach Interacting and run the Engage.
class UMars_AutoTest_Control_GripBegunManipulationEngagesAtThreshold : UCk_AutoTest_Base
{
    private FCk_Handle_Control _Control;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle _Player;
    private int32 _EngagedCount = 0;
    private TArray<ECk_SucceededFailed> _FinishedResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Player = InHandle;
        auto HandRootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto HandRoot = utils_transform::Add(HandRootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(HandRoot, FTransform::Identity);

        auto HandsSpec = FMars_FPHands_Spec();
        HandsSpec.HandNode = HandNode.As_Transform();
        _Hands = utils_fphands::Add(_Player, HandsSpec);
        _Resolver = utils_interaction_resolver::Add(_Player, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        BuildLever(InHandle);
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 5.0f);
        Add_Step("focus the lever", n"Step_FocusLever");
        Add_Step_WaitUntil("the lever's interact target is Focused", n"Check_TargetFocused", 0, 5.0f);
        Add_Step("add the lever to the resolver and open Use", n"Step_UseLever");
        Add_Step_WaitUntil("the gloves grip and the lever is manipulated", n"Check_IsManipulating", 0, 5.0f);
        Add_Step_WaitUntil("pull until the manipulation ends", n"Check_PullUntilEnded", 0, 5.0f);
        Add_Step_WaitUntil("the lever engages", n"Check_Engaged", 0, 5.0f);
        Add_Step_WaitSeconds("let a second engage or finish land", 0.2f);
        Add_Step("the threshold ended the interaction Succeeded and toggled the lever on once", n"Step_AssertEngaged");
        Run_Steps(InHandle);
    }

    private FCk_InteractionResolver_Spec Make_ResolverSpec()
    {
        auto Channels = TArray<FGameplayTag>();
        Channels.Add(GameplayTags::InteractionChannel_Mars_Use);

        // The test entity has no transform: no distance sort.
        auto Mapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, Channels);
        Mapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(Mapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    private void BuildLever(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandleNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndRotation = FRotator(70.0, 0.0, 0.0);
        MoverSpec.Duration = 0.3f;
        auto Mover = utils_mover::Add(HandleNode, MoverSpec);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        _Control = utils_control::Add(RootEntity, ControlSpec, Mover);
        _Control.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnEngaged"));

        // No ProbeInfo: a transform-only child; the reach resolves as a point grip at the owner.
        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(_Control.Make_InteractTarget(FText::FromString("Pull")));
        _Interactable = utils_interactable::Create(Root, Spec);
        _Target = _Interactable.Get_AllInteractTargets()[0];
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinished"));
    }

    UFUNCTION()
    private void OnEngaged(FCk_Handle_Control InControl)
    {
        _EngagedCount += 1;
    }

    UFUNCTION()
    private void OnFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }

    UFUNCTION()
    private void Check_HandsRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    // Stands in for the player's InteractionFocus task: without focus the Interactable's HFSM never reaches Interacting.
    UFUNCTION()
    private void Step_FocusLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Player));
    }

    UFUNCTION()
    private void Check_TargetFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    private void Step_UseLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Use));
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
        _Control.Request_Nudge(FMars_Request_Control_Nudge(4.0f));

        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Check_Engaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_EngagedCount >= 1);
    }

    UFUNCTION()
    private void Step_AssertEngaged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_EngagedCount, 1, "the threshold engaged the lever exactly once");
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the interaction finished once");
        if (_FinishedResults.Num() > 0)
        {
            Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Succeeded,
                f"the threshold ended the interaction Succeeded (got {_FinishedResults[0] :n})");
        }

        Assert_True(_Control.Get_IsActive(), "the toggle lever is on after the engage");
    }
}
