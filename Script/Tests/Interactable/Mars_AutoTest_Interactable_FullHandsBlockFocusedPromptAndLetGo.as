// The carrier's SM root state: the player HFSM's real Hotbar -> HeldItem and resolver -> interaction glue.
class UMars_AutoTestState_FullHandsCarrierRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_HotbarDrivesHeldItem);
        AddTask(InHandle, UMars_SmTask_InteractionResolverBinds);
    }
}

// A RequiresFreeHands lever focused by a carrier (AttachPoints + Hotbar + HeldItem + HeldItemUse + a Use resolver, the
// test entity) whose SM runs the player HFSM's HotbarDrivesHeldItem and InteractionResolverBinds tasks. With empty hands
// the prompt shows "Pull", the lever becomes the best Use target and the resolver glue starts the carrier's interaction.
// Selecting the rock's slot blocks the prompt (the hands-full reason in the blocked colour, "Pull" kept underneath) and
// the re-resolve drops the lever from the best Use targets, so the glue cancels the live interaction. Selecting the
// empty slot again clears the block. Isolated Z band: -82000.
class UMars_AutoTest_Interactable_FullHandsBlockFocusedPromptAndLetGo : UCk_AutoTest_Base
{
    private FCk_Handle _Carrier;
    private FCk_Handle_Hotbar _Hotbar;
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_StateMachine _Sm;
    private FCk_Handle_Inventory_DataOnly _RockHolder;
    private FCk_Handle_Item _Rock;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_InteractPrompt _Prompt;
    private TArray<ECk_SucceededFailed> _FinishedResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -82000.0)),
            ECk_Replication::DoesNotReplicate);

        auto HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, HandNode));
        utils_attach_points::Add(_Carrier, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 2;
        _Hotbar = utils_hotbar::Add(_Carrier, HotbarSpec);
        _HeldItem = utils_held_item::Add(_Carrier);
        utils_held_item_use::Add(_Carrier);
        _Resolver = utils_interaction_resolver::Add(_Carrier, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);

        _RockHolder = MakeSeededHolder(InHandle, mars_items::Rock());
        BuildLever(InHandle);

        _Sm = utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_FullHandsCarrierRig));

        Add_Step_WaitUntil("the carrier's SM runs the glue and the rock holder is seeded", n"Check_Ready");
        Add_Step("stow the rock into bag slot 0", n"Step_StowRockIntoHotbar");
        Add_Step_WaitUntil("the rock is held", n"Check_RockHeld");
        Add_Step("select the empty bag slot 1", n"Step_SelectEmptySlot");
        Add_Step_WaitUntil("the carrier's hands are empty", n"Check_HandsEmpty");
        Add_Step("the carrier focuses the lever, offers it to the resolver and opens Use", n"Step_FocusAndUse");
        Add_Step_WaitUntil("the lever is focused and the best Use target", n"Check_FocusedAndBest", 0, 5.0f);
        Add_Step_WaitUntil("the resolver glue started the carrier's interaction on the lever", n"Check_HasInteraction", 0, 5.0f);
        Add_Step("empty hands: the prompt shows Pull, unblocked", n"Step_AssertUnblocked");
        Add_Step("select the rock's slot 0", n"Step_SelectRockSlot");
        Add_Step_WaitUntil("the prompt is blocked, the lever left the best Use targets and the interaction is gone", n"Check_BlockedAndLetGo", 0, 5.0f);
        Add_Step("full hands: the prompt shows the hands-full reason over Pull, and the interaction did not succeed", n"Step_AssertBlocked");
        Add_Step("select the empty bag slot 1 again", n"Step_SelectEmptySlot");
        Add_Step_WaitUntil("the prompt is unblocked", n"Check_Unblocked", 0, 5.0f);
        Add_Step("empty hands again: the prompt shows Pull", n"Step_AssertUnblocked");
        Run_Steps(InHandle);
    }

    private FCk_InteractionResolver_Spec Make_ResolverSpec()
    {
        auto Channels = TArray<FGameplayTag>();
        Channels.Add(GameplayTags::InteractionChannel_Mars_Use);

        // The lever sits away from the carrier; one target needs no distance sort.
        auto Mapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, Channels);
        Mapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(Mapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    UFUNCTION()
    private void OnFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Seeded = _RockHolder.Get_NumItems() == 1;
        if (Seeded && ck::Is_NOT_Valid(_Rock))
        {
            auto Items = _RockHolder.Get_Items();
            _Rock = Items[0];
        }

        auto Res = OutResult;
        Res.Set(Seeded && utils_state_machine::IsInState(_Sm, UMars_AutoTestState_FullHandsCarrierRig));
    }

    UFUNCTION()
    private void Step_StowRockIntoHotbar(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = _Hotbar.TryGet_StowTarget(_Rock);
        if (ck::Is_NOT_Valid(Target) || Target != _Hotbar.Get_Slot(0))
        {
            FinishFailure("stow precondition: the rock's stow target is bag slot 0");
            return;
        }

        _RockHolder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Rock, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_RockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex() == TOptional<int32>(0) && _HeldItem.Get_CurrentItem() == _Rock);
    }

    UFUNCTION()
    private void Step_SelectEmptySlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    private void Check_HandsEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()));
    }

    // What the player HFSM's InteractionFocus and UseIntentToResolver tasks do for a focused lever with Use held.
    UFUNCTION()
    private void Step_FocusAndUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Use));
    }

    UFUNCTION()
    private void Check_FocusedAndBest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Interactable.Get_IsFocused() && Get_IsBestUseTarget());
    }

    UFUNCTION()
    private void Check_HasInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Carrier)));
    }

    UFUNCTION()
    private void Step_AssertUnblocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Prompt.Get_IsBlocked(), "empty hands leave the prompt unblocked");
        Assert_Equals_String(_Prompt.Get_DisplayText().ToString(), "Pull", "the prompt shows its text");
        Assert_True(_Prompt.Get_DisplayTextColor() == constants_ui_colors::k_PromptText,
            f"the prompt shows the action colour (got {DoFormat_Color(_Prompt.Get_DisplayTextColor())})");
    }

    UFUNCTION()
    private void Step_SelectRockSlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    private void Check_BlockedAndLetGo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Prompt.Get_IsBlocked() &&
                Get_IsBestUseTarget() == false &&
                ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _Carrier)));
    }

    UFUNCTION()
    private void Step_AssertBlocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_String(_Prompt.Get_DisplayText().ToString(), utils_interactable::Get_HandsFullText().ToString(),
            "the prompt shows the hands-full reason");
        Assert_True(_Prompt.Get_DisplayTextColor() == constants_ui_colors::k_PromptText_Blocked,
            f"the prompt shows the blocked colour (got {DoFormat_Color(_Prompt.Get_DisplayTextColor())})");
        Assert_Equals_String(_Prompt.Get_PromptText().ToString(), "Pull", "the prompt text underneath is kept");

        Assert_Equals_Int(_FinishedResults.Num(), 1, "the cancelled interaction finished once");
        if (_FinishedResults.Num() == 1)
        {
            Assert_True(_FinishedResults[0] != ECk_SucceededFailed::Succeeded,
                f"a cancelled interaction does not succeed (got [{_FinishedResults[0] :n}])");
        }
    }

    UFUNCTION()
    private void Check_Unblocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Prompt.Get_IsBlocked() == false);
    }

    private bool Get_IsBestUseTarget()
    {
        return _Resolver.Get_BestInteractTargets(GameplayTags::InteractionIntent_Mars_Use).Contains(_Target);
    }

    private FString DoFormat_Color(const FLinearColor& InColor) const
    {
        return f"[{InColor.R}, {InColor.G}, {InColor.B}, {InColor.A}]";
    }

    // A ManuallyCompleted lever (no mover): nothing completes its interaction in this test, so a started one stays live.
    private void BuildLever(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, FVector(200.0, 0.0, -82000.0)),
            ECk_Replication::DoesNotReplicate);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        auto Control = utils_control::Add(RootEntity, ControlSpec, FCk_Handle_Mover());

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(Control.Make_InteractTarget(FText::FromString("Pull")));
        _Interactable = utils_interactable::Create(Root, Spec);

        const auto Targets = _Interactable.Get_AllInteractTargets();
        if (Targets.Num() != 1)
        {
            FinishFailure(f"the lever interactable has {Targets.Num()} interact targets, expected 1");
            return;
        }

        _Target = Targets[0];
        _Prompt = _Target.As_InteractPrompt();
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinished"));
    }

    private FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
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
}
