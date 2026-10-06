// Every change of a slot's item - arrival and removal - broadcasts OnSlotItemChanged once, with the new item.
class UMars_AutoTest_Hotbar_SlotItemChangedBroadcasts : UMars_AutoTestRig_Carrier
{
    private int32 _ChangedCount = 0;
    // The latest change's slot index; unset until one fires.
    private TOptional<int32> _LastIndex;
    private FCk_Handle_Item _LastItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 2);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

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
        _LastIndex = TOptional<int32>(InIndex);
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
        Res.Set(_ChangedCount == 1 && Get_LastIndexIs(0) && ck::IsValid(_LastItem));
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
        Res.Set(_ChangedCount == 2 && Get_LastIndexIs(0) && ck::Is_NOT_Valid(_LastItem));
    }

    private bool Get_LastIndexIs(int32 InIndex) const
    {
        return _LastIndex.IsSet() && _LastIndex.GetValue() == InIndex;
    }
}
