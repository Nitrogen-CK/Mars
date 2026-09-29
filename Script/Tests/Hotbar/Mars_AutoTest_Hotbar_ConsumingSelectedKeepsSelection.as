// Removing the held item leaves its slot selected with empty hands (PEAK): SelectedIndex never follows the item out.
class UMars_AutoTest_Hotbar_ConsumingSelectedKeepsSelection : UCk_AutoTest_Base
{
    private FCk_Handle_Hotbar _Hotbar;
    private TArray<FCk_Handle_Inventory_DataOnly> _Holders;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        _Hotbar = utils_hotbar::Add(LocalHandle, Spec);
        _Holders.Add(MakeSeededHolder(InHandle));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HolderSeeded");
        Add_Step("stow the rock", n"Step_Stow");
        Add_Step_WaitUntil("slot 0 holds it and is auto-held", n"Check_StowedAndSelected");
        Add_Step("remove the selected item", n"Step_RemoveSelected");
        Add_Step_WaitUntil("slot 0 is empty", n"Check_SlotEmpty");
        Add_Step_WaitFrames("let the sync pass observe the removal", 3);
        Add_Step("slot 0 stays selected with empty hands", n"Step_AssertSelectionKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_HolderSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Holders[0].Get_NumItems() == 1);
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_StowedAndSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)) && _Hotbar.Get_SelectedIndex() == 0);
    }

    UFUNCTION()
    private void Step_RemoveSelected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Slot = _Hotbar.Get_SelectedSlot();
        auto Request = FCk_Request_Inventory_RemoveItem(_Hotbar.Get_SelectedItem());
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Slot.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    UFUNCTION()
    private void Check_SlotEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_Slot(0).Get_NumItems() == 0);
    }

    UFUNCTION()
    private void Step_AssertSelectionKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Hotbar.Get_SelectedIndex(), 0, "SelectedIndex after the held item was removed");
        Assert_False(ck::IsValid(_Hotbar.Get_SelectedItem()), "Get_SelectedItem after the held item was removed");
    }

    private FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.WorldItemHolder"), 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Rock(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }

    // What the pickup task does: transfer into whatever the hotbar names as the stow target.
    private void StowFrom(FCk_Handle_Inventory_DataOnly InHolder)
    {
        auto Target = _Hotbar.TryGet_StowTarget();
        auto Items = InHolder.Get_Items();
        if (ck::Is_NOT_Valid(Target) || Items.Num() != 1)
        {
            FinishFailure("stow precondition: a valid stow target and a holder with one item");
            return;
        }

        auto Holder = InHolder;
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Items[0], Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }
}
