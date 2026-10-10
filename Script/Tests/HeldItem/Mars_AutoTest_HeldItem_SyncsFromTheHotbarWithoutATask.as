// HeldItem follows the hotbar on its own (UMars_Processor_HeldItem_Sync), with no task and no state machine. A bare carrier
// (a Hand node, a hotbar with two bag slots, HeldItem) stows rock A into empty hands (selected: none -> A), deselects
// (A -> none), selects it again (none -> A), stows rock B (the other bag slot; the hands keep A, no change) and rock C (the
// overflow, which selects itself: A -> C), then selects B's slot: the selection parks while C is in the overflow, and once
// C is gone (the eject a Drop answers, done here by removing it) it lands on B (C -> B). OnHeldItemChanged fires exactly
// those five times with those items, and the current item follows. Isolated origin (54800, -12000, -30000).
class UMars_AutoTest_HeldItem_SyncsFromTheHotbarWithoutATask : UMars_AutoTestRig_Carrier
{
    private const FVector k_Origin = FVector(54800.0, -12000.0, -30000.0);

    // In parallel: one entry per OnHeldItemChanged.
    private TArray<FCk_Handle_Item> _ChangedFrom;
    private TArray<FCk_Handle_Item> _ChangedTo;
    private int32 _EjectRequests = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));
        _Hotbar.BindTo_OnOverflowEjectRequested(FMars_Delegate_Hotbar_OnOverflowEjectRequested(this, n"OnOverflowEjectRequested"));

        for (int32 Index = 0; Index < 3; ++Index)
        { _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock())); }

        Add_Step_WaitUntil("every holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow rock A into the empty hands' bag slot", n"Step_StowFirst");
        Add_Step_WaitUntil("HeldItem changed: none -> A", n"Check_OneChange", 0, 0);
        Add_Step("deselect", n"Step_Deselect");
        Add_Step_WaitUntil("HeldItem changed: A -> none", n"Check_TwoChanges", 0, 0);
        Add_Step("select bag slot 0 again", n"Step_SelectZero");
        Add_Step_WaitUntil("HeldItem changed: none -> A", n"Check_ThreeChanges", 0, 0);
        Add_Step("stow rock B into the other bag slot", n"Step_StowSecond");
        Add_Step_WaitUntil("bag slot 1 holds it", n"Check_SecondStowed");
        Add_Step("stow rock C into the overflow", n"Step_StowThird");
        Add_Step_WaitUntil("HeldItem changed: A -> C", n"Check_FourChanges", 0, 0);
        Add_Step("select rock B's slot", n"Step_SelectOne");
        Add_Step_WaitUntil("the selection parks and asks for the overflow's eject", n"Check_EjectRequested", 0, 0);
        Add_Step("the eject: rock C leaves the overflow", n"Step_RemoveOverflowItem");
        Add_Step_WaitUntil("HeldItem changed: C -> B", n"Check_FiveChanges", 0, 0);
        Add_Step_WaitSeconds("a stray change would fire in this window", 0.25f);
        Add_Step("exactly those five changes, with those items", n"Step_AssertChanges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        _ChangedFrom.Add(InPrev);
        _ChangedTo.Add(InNew);
    }

    UFUNCTION()
    private void OnOverflowEjectRequested(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem)
    {
        ++_EjectRequests;
    }

    UFUNCTION()
    private void Check_OneChange(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChangedTo.Num() >= 1);
    }

    UFUNCTION()
    private void Check_TwoChanges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChangedTo.Num() >= 2);
    }

    UFUNCTION()
    private void Check_ThreeChanges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChangedTo.Num() >= 3);
    }

    UFUNCTION()
    private void Check_FourChanges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChangedTo.Num() >= 4);
    }

    UFUNCTION()
    private void Check_FiveChanges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChangedTo.Num() >= 5);
    }

    UFUNCTION()
    private void Step_Deselect(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Deselect();
    }

    UFUNCTION()
    private void Step_SelectOne(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    private void Check_EjectRequested(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_EjectRequests == 1);
    }

    UFUNCTION()
    private void Step_RemoveOverflowItem(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_HeldItem.Get_CurrentItem() == _Items[2], "while the selection is parked the hands still hold rock C");

        const auto OverflowIndex = _Hotbar.Get_OverflowIndex();
        auto Overflow = _Hotbar.Get_Slot(OverflowIndex);
        auto Request = FCk_Request_Inventory_RemoveItem(_Hotbar.Get_ItemAt(OverflowIndex));
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Overflow.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    UFUNCTION()
    private void Step_AssertChanges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChangedTo.Num(), 5, "OnHeldItemChanged fired five times");
        if (_ChangedTo.Num() != 5)
        { return; }

        const auto None = FCk_Handle_Item();
        Assert_Change(0, None, _Items[0]);
        Assert_Change(1, _Items[0], None);
        Assert_Change(2, None, _Items[0]);
        Assert_Change(3, _Items[0], _Items[2]);
        Assert_Change(4, _Items[2], _Items[1]);
        Assert_True(_HeldItem.Get_CurrentItem() == _Items[1], "the hands hold rock B");
        Assert_True(_HeldItem.Get_CurrentInventory() == _Hotbar.Get_Slot(1), "from bag slot 1");
    }

    private void Assert_Change(int32 InIndex, FCk_Handle_Item InFrom, FCk_Handle_Item InTo)
    {
        Assert_True(_ChangedFrom[InIndex] == InFrom && _ChangedTo[InIndex] == InTo,
            f"change {InIndex} is [{InFrom.ToString()}] -> [{InTo.ToString()}] (got [{_ChangedFrom[InIndex].ToString()}] -> [{_ChangedTo[InIndex].ToString()}])");
    }
}
