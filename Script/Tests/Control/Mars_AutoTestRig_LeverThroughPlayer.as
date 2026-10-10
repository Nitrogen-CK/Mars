// Runs the player's real ManipulateControl, UseIntentToResolver and Hands sub-SM tasks on the test entity.
class UMars_AutoTestState_ManipulateControlRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_ManipulateControl);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

// The lever rig driven through the player's tasks: the test entity (the player) gets FPHands on a hand node of its own, a
// Use interaction resolver, InputIntents and a private Use key (UMars_AutoTestHelper_UseKey); the test adds
// UMars_AutoTestState_ManipulateControlRig to run the player's tasks and Add_Steps_UseRowLive before it presses Use. Use
// on the lever is the player's: the lever offered to the resolver (as the focus task would), Use pressed.
UCLASS(Abstract)
class UMars_AutoTestRig_LeverThroughPlayer : UMars_AutoTestRig_Lever
{
    protected FCk_Handle_FPHands _Hands;
    protected FCk_Handle_InteractionResolver _Resolver;
    // Added before the rig SM: ManipulateControl reads the Use row from it.
    protected FCk_Handle_InputIntents _Intents;
    protected UMars_AutoTestHelper_UseKey _UseKey;

    // InHandsSpec's HandNode is set here. The lever starts inactive.
    protected void BuildPlayerAndLever(FCk_Handle InHandle, FMars_FPHands_Spec InHandsSpec)
    {
        _Player = InHandle;
        auto HandRootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto HandRoot = utils_transform::Add(HandRootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(HandRoot, FTransform::Identity);

        auto HandsSpec = InHandsSpec;
        HandsSpec.HandNode = HandNode.As_Transform();
        _Hands = utils_fphands::Add(_Player, HandsSpec);
        _Resolver = utils_interaction_resolver::Add(_Player, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        _Intents = utils_input_intents::Add(_Player);

        _UseKey = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _UseKey.Build(InHandle, EKeys::F9);

        BuildLever(InHandle, EMars_Control_Activation::Inactive);
    }

    // Up to a Use row the player reads (the intent task follows the matcher swap, so the rig SM may already run).
    protected void Add_Steps_UseRowLive()
    {
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_UseKeyRecording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step("the player reads the Use key's matcher", n"Step_SetMatcher");
        Add_Step_WaitUntil("the player reads the matcher", n"Check_MatcherSet", 0, 0);
    }

    protected FCk_InteractionResolver_Spec Make_ResolverSpec() const
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

    // Offers the lever to the resolver and presses Use.
    protected void UseLever()
    {
        OfferLever();
        _UseKey.Press();
    }

    // What the focus task does for a lever under the view: offers it to the resolver.
    protected void OfferLever()
    {
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
    }

    protected bool Get_IsUseHeld()
    {
        return _Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Use);
    }

    UFUNCTION()
    protected void Check_HandsRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    protected void Step_UseLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        UseLever();
    }

    UFUNCTION()
    protected void Step_OfferLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        OfferLever();
    }

    UFUNCTION()
    protected void Step_PressUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Press();
    }

    UFUNCTION()
    protected void Step_ReleaseUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Release();
    }

    UFUNCTION()
    protected void Check_UseKeyRecording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsRecording());
    }

    UFUNCTION()
    protected void Step_SwapUseSet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Swapped = _UseKey.Request_SwapUseSet();
        if (Swapped.IsValid() == false)
        { FinishFailure(Swapped.Get_Error()); }
    }

    UFUNCTION()
    protected void Check_UseSetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsUseSetActive());
    }

    UFUNCTION()
    protected void Step_SetMatcher(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_UseKey.Get_Matcher()));
    }

    UFUNCTION()
    protected void Check_MatcherSet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_Matcher() == _UseKey.Get_Matcher());
    }

    UFUNCTION()
    protected void Check_UseHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsUseHeld());
    }

    UFUNCTION()
    protected void Check_UseReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsUseHeld() == false);
    }
}
