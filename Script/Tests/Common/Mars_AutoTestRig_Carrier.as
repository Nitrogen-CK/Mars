// The player's tasks a carrier with gloves runs: the Use row -> resolver intent and its interaction, the held-item -> gloves
// link and the Hands sub-SM.
class UMars_AutoTestState_CarrierHands : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesHands);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

// The item-carrier tests' rig (Hotbar, Interactable, Backpack, WorldItem): a Hotbar on the test entity, one-slot holders
// seeded from item definitions, the pickup task's stow and the take into the hotbar, the carrier's body for the tests whose
// carrier holds or wears what it picks up, and its gloves for the tests that place what it holds. HeldItem follows the
// hotbar on its own (UMars_Processor_HeldItem_Sync).
UCLASS(Abstract)
class UMars_AutoTestRig_Carrier : UCk_AutoTest_Base
{
    protected FCk_Handle _Carrier;
    protected FCk_Handle_Transform _HandNode;
    protected FCk_Handle_Transform _BackNode;
    protected FCk_Handle_Hotbar _Hotbar;
    protected FCk_Handle_HeldItem _HeldItem;
    // Valid after Add_CarrierHands.
    protected FCk_Handle_FPHands _Hands;
    // Every phase the gloves entered since Add_CarrierHands, in order.
    protected TArray<EMars_FPHands_Phase> _HandPhases;
    // The interact targets Check_AwaitedFocus waits to see Focused (named by Await_FocusOf in the step that focuses them).
    protected TArray<FCk_Handle_InteractTarget> _AwaitedFocus;
    protected TArray<FCk_Handle_Inventory_DataOnly> _Holders;
    // The holders' items in holder order, recorded by Check_HoldersSeeded once every holder is seeded.
    protected TArray<FCk_Handle_Item> _Items;

    // The test entity is the carrier, rooted at InLocation, with a Hand node published as AttachPoint.Mars.Hand.
    protected void Add_CarrierBody(FCk_Handle InHandle, FVector InLocation)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        _HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        utils_attach_points::Add(_Carrier, AttachPointsSpec);
    }

    // Add_CarrierBody with a Back node as well, published as AttachPoint.Mars.Back.
    protected void Add_CarrierBodyWithBack(FCk_Handle InHandle, FVector InLocation)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        _HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        _BackNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(-30.0, 0.0, 20.0))).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, _BackNode));
        utils_attach_points::Add(_Carrier, AttachPointsSpec);
    }

    // The carrier's gloves on its Hand node, a Use resolver and InputIntents (no matcher: nothing presses), and the player's
    // tasks over them (UMars_AutoTestState_CarrierHands): the Use intent task, the held-item -> gloves link and the Hands
    // sub-SM, whose resolver binds listen as the player's do. A test starts its interactions on the targets itself; the
    // interactions' own tasks ask the gloves for their reaches. After Add_CarrierBody*.
    protected void Add_CarrierHands()
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.HandNode = _HandNode;
        _Hands = utils_fphands::Add(_Carrier, Spec);
        utils_interaction_resolver::Add(_Carrier, Make_CarrierResolverSpec(), ECk_Replication::DoesNotReplicate);
        utils_input_intents::Add(_Carrier);
        utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_CarrierHands));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnCarrierHandsPhaseChanged"));
    }

    // The Use intent over the Use channel; the carrier's targets are offered one at a time, so no distance sort.
    private FCk_InteractionResolver_Spec Make_CarrierResolverSpec() const
    {
        auto Channels = TArray<FGameplayTag>();
        Channels.Add(GameplayTags::InteractionChannel_Mars_Use);

        auto Mapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, Channels);
        Mapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(Mapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    // Check_AwaitedFocus waits for every target of InInteractable (focused by the calling step) to enter Focused.
    protected void Await_FocusOf(FCk_Handle_Interactable InInteractable)
    {
        for (auto Target : InInteractable.Get_AllInteractTargets())
        { _AwaitedFocus.Add(Target); }
    }

    // Every awaited target's state machine is Focused; the awaited list empties once it holds.
    UFUNCTION()
    protected void Check_AwaitedFocus(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllFocused = _AwaitedFocus.Num() > 0;
        for (auto Target : _AwaitedFocus)
        { AllFocused = AllFocused && utils_state_machine::Get_CurrentStateClass(Target.As_StateMachine()) == UMars_SmState_Interactable_Focused; }

        if (AllFocused)
        { _AwaitedFocus.Empty(); }

        auto Res = OutResult;
        Res.Set(AllFocused);
    }

    UFUNCTION()
    protected void OnCarrierHandsPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        _HandPhases.Add(InNew);
    }

    // The Hands state machine rests, listening for a reach.
    UFUNCTION()
    protected void Check_CarrierHandsRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hands) && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    protected void Add_Hotbar(FCk_Handle InCarrier, int32 InBagSlotCount)
    {
        auto Carrier = InCarrier;
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = InBagSlotCount;
        _Hotbar = utils_hotbar::Add(Carrier, Spec);
    }

    // A one-slot holder of its own, seeded with one item of InDefinition.
    protected FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }

    // What the pickup task does: transfer into whatever the hotbar names as the stow target for the item.
    protected void StowFrom(FCk_Handle_Inventory_DataOnly InHolder)
    {
        auto Items = InHolder.Get_Items();
        auto Target = FCk_Handle_Inventory_DataOnly();
        if (Items.Num() == 1)
        { Target = _Hotbar.TryGet_StowTarget(Items[0]); }

        if (ck::Is_NOT_Valid(Target) || Items.Num() != 1)
        {
            FinishFailure("stow precondition: a valid stow target and a holder with one item");
            return;
        }

        auto Holder = InHolder;
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Items[0], Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    // What a take does: transfer into whatever the hotbar names as the take target for the item.
    protected void TakeFrom(FCk_Handle_Inventory_DataOnly InHolder)
    {
        auto Items = InHolder.Get_Items();
        auto Target = FCk_Handle_Inventory_DataOnly();
        if (Items.Num() == 1)
        { Target = _Hotbar.TryGet_TakeTarget(Items[0]); }

        if (ck::Is_NOT_Valid(Target) || Items.Num() != 1)
        {
            FinishFailure("take precondition: a valid take target and a holder with one item");
            return;
        }

        auto Holder = InHolder;
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Items[0], Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    protected void Check_HoldersSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSeeded = true;
        for (const auto& Holder : _Holders)
        { AllSeeded = AllSeeded && Holder.Get_NumItems() == 1; }

        if (AllSeeded && _Items.Num() == 0)
        {
            for (const auto& Holder : _Holders)
            {
                auto Items = Holder.Get_Items();
                _Items.Add(Items[0]);
            }
        }

        auto Res = OutResult;
        Res.Set(AllSeeded);
    }

    UFUNCTION()
    protected void Step_StowFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    protected void Step_StowSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[1]);
    }

    UFUNCTION()
    protected void Step_StowThird(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[2]);
    }

    UFUNCTION()
    protected void Check_SecondStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(1)));
    }

    UFUNCTION()
    protected void Check_OverflowFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_Slot(2).Get_NumItems() == 1 && _Hotbar.Get_SelectedIndex() == TOptional<int32>(2));
    }

    UFUNCTION()
    protected void Step_SelectZero(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    protected void Check_SelectedZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    protected void Step_SelectEmptySlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    protected void Check_HandsEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()));
    }
}
