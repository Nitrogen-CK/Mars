// The carrier's SM root state: the player HFSM's real Hotbar -> HeldItem glue.
class UMars_AutoTestState_FreeHandsCarrierRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_HotbarDrivesHeldItem);
    }
}

// A carrier (AttachPoints + Hotbar + HeldItem + HeldItemUse, the test entity, whose SM runs the player HFSM's
// HotbarDrivesHeldItem task) holding a rock can't start a RequiresFreeHands lever: Get_CanInteractWith reads
// CustomValidationFailed and a StartInteraction creates nothing, while the same lever without the flag reads
// CanInteractWith. Selecting the empty bag slot frees the hands; the gated lever then reads CanInteractWith and the same
// StartInteraction creates the interaction. Isolated Z band: -81000.
class UMars_AutoTest_Interactable_FreeHandsTargetRejectsAFullHand : UCk_AutoTest_Base
{
    private FCk_Handle _Carrier;
    private FCk_Handle_Hotbar _Hotbar;
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_StateMachine _Sm;
    private FCk_Handle_Inventory_DataOnly _RockHolder;
    private FCk_Handle_Item _Rock;
    private FCk_Handle_InteractTarget _GatedTarget;
    private FCk_Handle_InteractTarget _UngatedTarget;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -81000.0)),
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

        _RockHolder = MakeSeededHolder(InHandle, mars_items::Rock());
        _GatedTarget = MakeLeverTarget(InHandle, FVector(200.0, 0.0, -81000.0), true);
        _UngatedTarget = MakeLeverTarget(InHandle, FVector(200.0, 300.0, -81000.0), false);

        _Sm = utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_FreeHandsCarrierRig));

        Add_Step_WaitUntil("the carrier's SM runs the glue and the rock holder is seeded", n"Check_Ready");
        Add_Step("stow the rock into bag slot 0", n"Step_StowRockIntoHotbar");
        Add_Step_WaitUntil("the rock is held", n"Check_RockHeld");
        Add_Step("holding the rock: the gated lever refuses the carrier, the ungated one accepts; try to start the gated one", n"Step_AssertRefusedAndTryStart");
        Add_Step_WaitSeconds("give a wrongly accepted start time to create its interaction", 0.3f);
        Add_Step("the gated lever has no interaction from the carrier", n"Step_AssertNoInteraction");
        Add_Step("select the empty bag slot 1", n"Step_SelectEmptySlot");
        Add_Step_WaitUntil("the carrier's hands are empty", n"Check_HandsEmpty");
        Add_Step("empty hands: the gated lever accepts the carrier; start it", n"Step_AssertAcceptedAndStart");
        Add_Step_WaitUntil("the gated lever has the carrier's interaction", n"Check_HasInteraction", 0, 5.0f);
        Run_Steps(InHandle);
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
        Res.Set(Seeded && utils_state_machine::IsInState(_Sm, UMars_AutoTestState_FreeHandsCarrierRig));
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
    private void Step_AssertRefusedAndTryStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_interactable::Get_HandsAreFree(_Carrier), "a carrier holding the rock has full hands");

        const auto Gated = utils_interact_target::Get_CanInteractWith(_GatedTarget, _Carrier);
        Assert_True(Gated == ECk_CanInteractWithResult::CustomValidationFailed,
            f"the gated lever refuses a full hand (got [{Gated :n}])");

        const auto Ungated = utils_interact_target::Get_CanInteractWith(_UngatedTarget, _Carrier);
        Assert_True(Ungated == ECk_CanInteractWithResult::CanInteractWith,
            f"the ungated lever accepts a full hand (got [{Ungated :n}])");

        _GatedTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_AssertNoInteraction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Invalid(utils_interact_target::TryGet_Interaction(_GatedTarget, _Carrier),
            "the refused StartInteraction created no interaction");
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

    UFUNCTION()
    private void Step_AssertAcceptedAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_interactable::Get_HandsAreFree(_Carrier), "selecting the empty slot frees the hands");

        const auto Gated = utils_interact_target::Get_CanInteractWith(_GatedTarget, _Carrier);
        Assert_True(Gated == ECk_CanInteractWithResult::CanInteractWith,
            f"the gated lever accepts empty hands (got [{Gated :n}])");

        _GatedTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_HasInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(utils_interact_target::TryGet_Interaction(_GatedTarget, _Carrier)));
    }

    // A ManuallyCompleted lever (no mover): nothing completes its interaction in this test, so a started one stays live.
    private FCk_Handle_InteractTarget MakeLeverTarget(FCk_Handle InHandle, FVector InLocation, bool InRequiresFreeHands)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        auto Control = utils_control::Add(RootEntity, ControlSpec, FCk_Handle_Mover());

        auto Entry = Control.Make_InteractTarget(FText::FromString("Pull"));
        Entry.RequiresFreeHands = InRequiresFreeHands;

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(Entry);
        auto Interactable = utils_interactable::Create(Root, Spec);

        const auto Targets = Interactable.Get_AllInteractTargets();
        if (Targets.Num() != 1)
        {
            FinishFailure(f"the lever interactable at [{InLocation.ToString()}] has {Targets.Num()} interact targets, expected 1");
            return FCk_Handle_InteractTarget();
        }

        return Targets[0];
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
