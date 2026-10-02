// The player's ManipulateControl task begins a lever's manipulation only once the gloves grip it: Use on a
// ManuallyCompleted lever starts the interaction at once, but the Control is not manipulated while the gloves are still
// reaching. Rig: the ManuallyCompleted lever of Mars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack
// (transform-only interactable: the reach resolves as a point grip at the lever root), hands + resolver on the test
// entity, and an SM on the test entity whose root state runs the player's ManipulateControl, InteractionResolverBinds
// and Hands sub-SM tasks.
class UMars_AutoTestState_ManipulateControlRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_ManipulateControl);
        AddTask(InHandle, UMars_SmTask_InteractionResolverBinds);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

class UMars_AutoTest_Control_ManipulationWaitsForTheGrip : UCk_AutoTest_Base
{
    private FCk_Handle_Control _Control;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle _Player;
    private bool _SawManipulationBeforeGrip = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Player = InHandle;
        auto HandRootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto HandRoot = utils_transform::Add(HandRootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(HandRoot, FTransform::Identity);

        _Hands = utils_fphands::Add(_Player, FMars_FPHands_Spec(), HandNode.As_Transform());
        _Resolver = utils_interaction_resolver::Add(_Player, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        BuildLever(InHandle);
        utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_AutoTestState_ManipulateControlRig));

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_HandsRest", 0, 5.0f);
        Add_Step("add the lever to the resolver and open Use", n"Step_UseLever");
        Add_Step_WaitUntil("the lever is manipulated", n"Check_IsManipulating", 0, 5.0f);
        Add_Step("the manipulation began only once the gloves gripped the lever", n"Step_AssertGripFirst");
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

        // No ProbeInfo: a transform-only child; the reach resolves as a point grip at the owner.
        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(_Control.Make_InteractTarget(FText::FromString("Pull")));
        auto Interactable = utils_interactable::Create(Root, Spec);
        _Target = Interactable.Get_AllInteractTargets()[0];
    }

    UFUNCTION()
    private void Check_HandsRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_UseLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Use));
    }

    // Every evaluation also records a manipulation seen while the gloves were not yet on the lever.
    UFUNCTION()
    private void Check_IsManipulating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsManipulating = _Control.Get_IsManipulating();
        if (IsManipulating && _Hands.Get_IsGrippingTarget(_Target) == false)
        { _SawManipulationBeforeGrip = true; }

        auto Res = OutResult;
        Res.Set(IsManipulating);
    }

    UFUNCTION()
    private void Step_AssertGripFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_SawManipulationBeforeGrip,
            f"the lever was manipulated while the gloves were not gripping it (phase {_Hands.Get_Phase() :n}, alpha {_Hands.Get_ReachAlpha()})");
        Assert_True(_Hands.Get_IsGrippingTarget(_Target), "the gloves grip the lever while it is manipulated");
        Assert_True(ck::IsValid(_Control.Get_Fragment(FMars_Fragment_Control).Manipulation.Interaction),
            "the manipulation carries the started interaction (the threshold ends it)");
    }
}
