// A timed target that becomes the resolver's best while the gloves are busy (here: pushing) is not lost: when the gloves
// come back to Rest they re-read the resolver and, the target's interaction from this player still being live, reach
// for it and hold. Beside the hands rig: a resolver on the test entity, and a Timed lever (a long hold, so the
// interaction stays live) with a transform-only interactable. The best-target change lands while the phase is Push.
class UMars_AutoTest_FPHands_RestResyncsToLiveTimedInteraction : UMars_AutoTestRig_Hands
{
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InteractTarget _Target;
    // The gloves' phase when the lever first became the resolver's best; unset until it does.
    private TOptional<EMars_FPHands_Phase> _PhaseAtBestChange;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.2f;
        Spec.Reach.Grab.GripSeconds = 0.2f;
        Spec.Reach.Grab.BackSeconds = 0.2f;
        Spec.Reach.Hold.ReleaseSeconds = 0.4f;
        // A push long enough that the target is added well inside it.
        Spec.Push.OutSeconds = 0.2f;
        Spec.Push.BackSeconds = 0.4f;
        Add_Hands(InHandle, Spec);
        _Resolver = utils_interaction_resolver::Add(_Player, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        _Resolver.BindTo_OnBestTargetsChanged(FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
        BuildLever(InHandle);
        Add_HandsSm();

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a push", n"Check_RestListeningForPush", 0, 5.0f);
        Add_Step("request a push", n"Step_RequestPush");
        Add_Step_WaitUntil("the gloves are busy pushing", n"Check_IsPush", 0, 5.0f);
        Add_Step("while pushing: add the lever to the resolver, open Use, start the interaction", n"Step_TargetWhileBusy");
        Add_Step_WaitUntil("the interaction from the player is live", n"Check_HasInteraction", 0, 5.0f);
        Add_Step_WaitUntil("the gloves hold", n"Check_IsHold", 0, 5.0f);
        Add_Step("the gloves hold the lever, timed, and the target became best during the push", n"Step_AssertHoldsTarget");
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
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::Timed;
        ControlSpec.HoldSeconds = 5.0f;
        auto Control = utils_control::Add(RootEntity, ControlSpec, Mover);

        // No ProbeInfo: a transform-only child; the reach resolves as a point grip at the owner.
        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(Control.Make_InteractTarget(FText::FromString("Turn")));
        auto Interactable = utils_interactable::Create(Root, Spec);
        _Target = Interactable.Get_AllInteractTargets()[0];
    }

    UFUNCTION()
    private void OnBestTargetsChanged(FCk_Handle_InteractionResolver InResolver, FGameplayTag InIntent,
                                      const TArray<FCk_Handle_InteractTarget>&in InPreviousTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InNewTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InRemovedTargets)
    {
        if (InIntent != GameplayTags::InteractionIntent_Mars_Use || _PhaseAtBestChange.IsSet())
        { return; }

        for (auto Target : InNewTargets)
        {
            if (Target == _Target)
            { _PhaseAtBestChange = TOptional<EMars_FPHands_Phase>(_Hands.Get_Phase()); }
        }
    }

    UFUNCTION()
    private void Step_RequestPush(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartPush(FMars_Request_FPHands_StartPush(FMars_FPHands_Hold(), EMars_LaunchKind::Drop));
    }

    UFUNCTION()
    private void Check_IsPush(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Push);
    }

    UFUNCTION()
    private void Step_TargetWhileBusy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Use));
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));
    }

    UFUNCTION()
    private void Check_HasInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Player)));
    }

    UFUNCTION()
    private void Step_AssertHoldsTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PhaseAtBestChange.IsSet(), "the resolver picked the lever");
        if (_PhaseAtBestChange.IsSet())
        {
            const auto PhaseAtBestChange = _PhaseAtBestChange.GetValue();
            Assert_True(PhaseAtBestChange == EMars_FPHands_Phase::Push,
                f"the lever became best while the gloves were pushing (got {PhaseAtBestChange :n})");
        }

        Assert_True(_Hands.Get_IsReachTarget(_Target), "the gloves hold the lever's interact target");
        Assert_True(_Hands.Get_CompletionPolicy() == ECk_Interaction_CompletionPolicy::Timed, "the hold is timed");
    }
}
