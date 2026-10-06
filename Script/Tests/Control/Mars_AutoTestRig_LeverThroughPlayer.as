// Runs the player's real ManipulateControl, InteractionResolverBinds and Hands sub-SM tasks on the test entity.
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

// The lever rig driven through the player's tasks: the test entity (the player) gets FPHands on a hand node of its own
// and a Use interaction resolver; the test adds UMars_AutoTestState_ManipulateControlRig to run the player's tasks.
UCLASS(Abstract)
class UMars_AutoTestRig_LeverThroughPlayer : UMars_AutoTestRig_Lever
{
    protected FCk_Handle_FPHands _Hands;
    protected FCk_Handle_InteractionResolver _Resolver;

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
        BuildLever(InHandle, EMars_Control_Activation::Inactive);
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

    // Adds the lever to the resolver and opens Use.
    protected void UseLever()
    {
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Use));
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
}
