// Removing the held item leaves its slot selected with empty hands: SelectedIndex never follows the item out.
class UMars_AutoTest_Hotbar_ConsumingSelectedKeepsSelection : UMars_AutoTestRig_Carrier
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 2);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

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
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)) && _Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
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
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(0), "slot 0 stays selected after the held item was removed");
        Assert_Invalid(_Hotbar.Get_SelectedItem(), "the hands are empty after the held item was removed");
    }
}
