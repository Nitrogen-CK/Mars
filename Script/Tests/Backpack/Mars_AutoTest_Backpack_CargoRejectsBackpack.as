// A cargo slot's accept policy refuses a backpack item even when the transfer bypasses Get_ActionFor, and an occupied
// slot reads Blocked_SlotOccupied for a carrier whose hands are full. Isolated Z band: -54000.
class UMars_AutoTest_Backpack_CargoRejectsBackpack : UCk_AutoTest_Base
{
    private FCk_Handle _Carrier;
    private FCk_Handle_Hotbar _Hotbar;
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_Backpack _Backpack;
    private FCk_Handle_CargoSlot _Slot0;

    // [0] second Backpack, [1] Rock, [2] Cog.
    private TArray<FCk_Handle_Inventory_DataOnly> _Holders;
    private TArray<FCk_Handle_Item> _Items;

    private bool _Backpack2TransferRecorded = false;
    private ECk_Inventory_OperationResult_Transfer _Backpack2TransferResult = ECk_Inventory_OperationResult_Transfer::Success;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -54000.0)),
            ECk_Replication::DoesNotReplicate);

        auto HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        auto BackNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(-30.0, 0.0, 20.0))).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, BackNode));
        utils_attach_points::Add(_Carrier, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 1;
        _Hotbar = utils_hotbar::Add(_Carrier, HotbarSpec);
        _HeldItem = utils_held_item::Add(_Carrier);

        // What the player HFSM's HotbarDrivesHeldItem task does: push the selection into HeldItem on every change.
        _Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));
        _Hotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnSlotItemChanged"));

        auto SpawnParams = UMars_Backpack_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(200.0, 0.0, -54000.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnBackpackConstructed"));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Backpack()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Cog()));

        Add_Step_WaitUntil("the backpack is constructed with 4 cargo slots and every holder is seeded", n"Check_Ready");
        Add_Step("force the second backpack into empty cargo slot 0", n"Step_ForceBackpack2IntoSlot0");
        Add_Step_WaitUntil("the forced transfer reported", n"Check_Backpack2TransferRecorded");
        Add_Step("cargo slot 0's policy refused the backpack", n"Step_AssertBackpack2Refused");
        Add_Step("stow the cog into slot 0", n"Step_StowCogIntoSlot0");
        Add_Step_WaitUntil("slot 0 holds the cog", n"Check_CogInSlot0");
        Add_Step("stow the rock into the carrier's hotbar", n"Step_StowRockIntoHotbar");
        Add_Step_WaitUntil("the carrier holds the rock", n"Check_RockHeld");
        Add_Step("an occupied slot reads Blocked_SlotOccupied for full hands", n"Step_AssertSlotOccupied");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnBackpackConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        auto Entity = FCk_Handle(InEntityScriptHandle);
        _Backpack = Entity.As_Backpack(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void OnSelectionChanged(FCk_Handle_Hotbar InHotbar, int32 InPrevIndex, int32 InNewIndex)
    {
        PushSelection();
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        PushSelection();
    }

    private void PushSelection()
    {
        if (ck::Is_NOT_Valid(_Hotbar) || ck::Is_NOT_Valid(_HeldItem))
        { return; }

        _HeldItem.Request_SetSlot(FMars_Request_HeldItem_SetSlot(_Hotbar.Get_SelectedSlot(), _Hotbar.Get_SelectedItem()));
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSeeded = true;
        for (const auto& Holder : _Holders)
        { AllSeeded = AllSeeded && Holder.Get_NumItems() == 1; }

        const auto Ready = AllSeeded && ck::IsValid(_Backpack) && _Backpack.Get_CargoSlotCount() == 4;
        if (Ready && _Items.Num() == 0)
        {
            for (const auto& Holder : _Holders)
            {
                auto Items = Holder.Get_Items();
                _Items.Add(Items[0]);
            }

            _Slot0 = _Backpack.Get_CargoSlot(0);
        }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Step_ForceBackpack2IntoSlot0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Holder = _Holders[0];
        Holder.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(_Items[0], _Slot0.Get_Inventory()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnForcedBackpack2Transfer"));
    }

    UFUNCTION()
    private void OnForcedBackpack2Transfer(FCk_Handle_Inventory InSource,
                                           FCk_Handle_Item InItem,
                                           FCk_Handle_Inventory InTarget,
                                           int32 InCount,
                                           FCk_Handle_Item InNewItemInTarget,
                                           ECk_Inventory_OperationResult_Transfer InResult)
    {
        _Backpack2TransferRecorded = true;
        _Backpack2TransferResult = InResult;
    }

    UFUNCTION()
    private void Check_Backpack2TransferRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Backpack2TransferRecorded);
    }

    UFUNCTION()
    private void Step_AssertBackpack2Refused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Backpack2TransferResult != ECk_Inventory_OperationResult_Transfer::Success,
            f"a backpack forced into an empty cargo slot reports a non-Success result (got [{_Backpack2TransferResult :n}])");
        Assert_False(_Slot0.Get_IsOccupied(), "cargo slot 0 after the refused backpack");
        Assert_Equals_Int(_Holders[0].Get_NumItems(), 1, "the second backpack's holder after the refused transfer");
    }

    UFUNCTION()
    private void Step_StowCogIntoSlot0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Slot0.Request_Stow(FMars_Request_CargoSlot_Stow(_Items[2]));
    }

    UFUNCTION()
    private void Check_CogInSlot0(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slot0.Get_Item() == _Items[2]);
    }

    UFUNCTION()
    private void Step_StowRockIntoHotbar(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = _Hotbar.TryGet_StowTarget(_Items[1]);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("stow precondition: the rock has a stow target");
            return;
        }

        auto Holder = _Holders[1];
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Items[1], Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_RockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[1]);
    }

    UFUNCTION()
    private void Step_AssertSlotOccupied(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Slot0.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_CargoSlot_Action::Blocked_SlotOccupied,
            f"Get_ActionFor(carrier holding a rock) on the occupied slot (got [{Action :n}])");
    }

    private FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.WorldItemHolder"), 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }
}

// Hand-authored so CkInventory's rollback Warning for the deliberately refused transfer is expected rather than a failure
// (the automation controller elevates Warnings to test errors; P1 precedent). Pinned to the item definition and the
// refusal reason so an unrelated refusal still fails the test.
class AMars_AutoTest_Backpack_CargoRejectsBackpack_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Backpack_CargoRejectsBackpack;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Mars_ItemDef_Backpack))] (Failed Rejected by Custom Acceptance Logic)");
        return Out;
    }
}
