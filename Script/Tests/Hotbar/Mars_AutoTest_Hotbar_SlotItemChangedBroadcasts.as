// Every change of a slot's item - arrival and removal - broadcasts OnSlotItemChanged once, with the new item.
class UMars_AutoTest_Hotbar_SlotItemChangedBroadcasts : UCk_AutoTest_Base
{
    private FCk_Handle_Hotbar _Hotbar;
    private TArray<FCk_Handle_Inventory_DataOnly> _Holders;
    private int32 _ChangedCount = 0;
    private int32 _LastIndex = -1;
    private FCk_Handle_Item _LastItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        _Hotbar = utils_hotbar::Add(LocalHandle, Spec);
        _Holders.Add(MakeSeededHolder(InHandle));

        _Hotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnSlotItemChanged"));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HolderSeeded");
        Add_Step("stow the rock", n"Step_Stow");
        Add_Step_WaitUntil("one change: slot 0 gained a valid item", n"Check_ArrivalBroadcast");
        Add_Step("remove it", n"Step_Remove");
        Add_Step_WaitUntil("a second change: slot 0 now holds nothing", n"Check_RemovalBroadcast");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        _ChangedCount += 1;
        _LastIndex = InIndex;
        _LastItem = InMaybeItem;
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
    private void Check_ArrivalBroadcast(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChangedCount == 1 && _LastIndex == 0 && ck::IsValid(_LastItem));
    }

    UFUNCTION()
    private void Step_Remove(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Slot = _Hotbar.Get_Slot(0);
        auto Request = FCk_Request_Inventory_RemoveItem(_Hotbar.Get_ItemAt(0));
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Slot.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    UFUNCTION()
    private void Check_RemovalBroadcast(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChangedCount == 2 && _LastIndex == 0 && ck::Is_NOT_Valid(_LastItem));
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
}
