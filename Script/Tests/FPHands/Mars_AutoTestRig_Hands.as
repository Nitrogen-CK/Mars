// A Timed lever the FPHands tests reach for: its root entity (the reach subject's owner; destroying it destroys the lever),
// its transform-only interactable and that interactable's one target.
struct FMars_AutoTestRig_Hands_Lever
{
    FCk_Handle Root;
    FCk_Handle_Interactable Interactable;
    FCk_Handle_InteractTarget Target;
}

// The FPHands tests' rig: FPHands on the test entity (the player) with its hand node on a transform root of its own at
// the origin, the Hands state machine, and a log of the phases the gloves run.
UCLASS(Abstract)
class UMars_AutoTestRig_Hands : UCk_AutoTest_Base
{
    // The gloves' motion (a grab, a release, a push, a lean) outruns the default poll budget at lane frame rate.
    protected const int32 k_SlowPolls = 900;

    protected FCk_Handle_FPHands _Hands;
    protected FCk_Handle_StateMachine _Sm;
    protected FCk_Handle _Player;
    protected TArray<EMars_FPHands_Phase> _Phases;

    // FPHands on InPlayer with InSpec, the hand node on a fresh root at the origin; returns that root.
    protected FCk_Handle_Transform Add_Hands(FCk_Handle InPlayer, FMars_FPHands_Spec InSpec)
    {
        _Player = InPlayer;
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InPlayer);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto Spec = InSpec;
        Spec.HandNode = HandNode.As_Transform();
        _Hands = utils_fphands::Add(_Player, Spec);
        return Root;
    }

    // A plain interactable (no probe, no targets) on a root of its own at InLocation, a child of InOwner; OutOwner is that
    // root (the focus request's owner). A point grip: one glove, on the side it lies.
    protected FCk_Handle_Interactable Add_PlainInteractable(FCk_Handle InOwner, FVector InLocation, FCk_Handle& OutOwner)
    {
        auto Parent = InOwner;
        OutOwner = utils_entity_lifetime::Request_CreateEntity(Parent);
        auto Root = utils_transform::Add(OutOwner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
        return utils_interactable::Create(Root, FMars_Interactable_Spec());
    }

    // A Timed lever (an interaction that completes after InHoldSeconds) with a transform-only interactable at InLocation, a
    // child of InOwner; a reach for it resolves as a point grip at its root.
    protected FMars_AutoTestRig_Hands_Lever Add_TimedLever(FCk_Handle InOwner, FVector InLocation, float32 InHoldSeconds)
    {
        auto Parent = InOwner;
        auto Lever = FMars_AutoTestRig_Hands_Lever();
        Lever.Root = utils_entity_lifetime::Request_CreateEntity(Parent);
        auto Root = utils_transform::Add(Lever.Root, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::Timed;
        ControlSpec.HoldSeconds = InHoldSeconds;
        auto Control = utils_control::Add(Lever.Root, ControlSpec);

        auto InteractableSpec = FMars_Interactable_Spec();
        InteractableSpec.Targets.Add(Control.Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Turn"))));
        Lever.Interactable = utils_interactable::Create(Root, InteractableSpec);
        Lever.Target = Lever.Interactable.Get_AllInteractTargets()[0];
        return Lever;
    }

    // The Hands SM is in Rest, the gloves at None, and Rest's reach and push conditions are listening.
    protected bool Get_IsRestListening() const
    {
        return utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest
            && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound()
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPushRequested._Inner.IsBound();
    }

    // A one-slot world item holder (a child of InOwner) seeded with one InDefinition item; it holds it a drain later.
    protected FCk_Handle_Inventory_DataOnly Add_SeededHolder(FCk_Handle InOwner, UCk_InventoryItem_Definition InDefinition)
    {
        auto Parent = InOwner;
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(Parent);
        auto HolderParams = utils_inventory_data_only::Make_Params_Bounded(GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(), FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, HolderParams, ECk_Replication::DoesNotReplicate);
        auto AddRequest = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        AddRequest.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(AddRequest, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }

    // A static BlockAll Jolt box centred at InCentre (world), a child of InOwner.
    protected FCk_Handle Add_StaticBox(FCk_Handle InOwner, FVector InCentre, FVector InHalfExtents)
    {
        auto Parent = InOwner;
        auto Box = utils_entity_lifetime::Request_CreateEntity(Parent);
        utils_transform::Add(Box, FTransform(FRotator::ZeroRotator, InCentre), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Box, BoxSpec);
        return Box;
    }

    // The lean or reach InHand plays this frame: the alpha the anim instance blends its reach grip by (Get_HandTargets
    // with no arm swing).
    protected float32 Get_AppliedLean(EMars_Hand InHand) const
    {
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_Hands.Get_HandNode());
        auto Targets = FMars_FPHands_HandTargets();
        _Hands.Get_HandTargets(FMars_FPHands_TargetFrame(HandWorld, FVector::ZeroVector, FVector::ZeroVector), Targets);
        return InHand == EMars_Hand::Right ? Targets.Right.ReachAlpha : Targets.Left.ReachAlpha;
    }

    protected void Add_HandsSm()
    {
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));
    }

    // Appends every phase change from here on to _Phases.
    protected void Log_Phases()
    {
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));
    }

    UFUNCTION()
    protected void OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        _Phases.Add(InNew);
    }

    UFUNCTION()
    protected void Check_RestListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    protected void Check_RestListeningForPush(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPushRequested._Inner.IsBound());
    }

    UFUNCTION()
    protected void Step_RequestTimedReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(ECk_Interaction_CompletionPolicy::Timed));
    }

    UFUNCTION()
    protected void Step_RequestRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_Release(FMars_Request_FPHands_Release());
    }

    UFUNCTION()
    protected void Check_IsHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold);
    }

    UFUNCTION()
    protected void Check_IsRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Release);
    }
}
