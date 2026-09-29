// Selecting away from an occupied overflow slot parks the selection and asks once for the overflow item to be
// dropped; the parked selection applies only after the overflow slot empties.
class UMars_AutoTest_Hotbar_LeavingOverflowParksSelection : UCk_AutoTest_Base
{
    private FCk_Handle_Hotbar _Hotbar;
    private TArray<FCk_Handle_Inventory_DataOnly> _Holders;
    private int32 _EjectCount = 0;
    private int32 _EjectPendingIndex = -2;
    private FCk_Handle_Item _EjectItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        _Hotbar = utils_hotbar::Add(LocalHandle, Spec);

        for (int32 Index = 0; Index < 3; ++Index)
        { _Holders.Add(MakeSeededHolder(InHandle)); }

        _Hotbar.BindTo_OnOverflowEjectRequested(FMars_Delegate_Hotbar_OnOverflowEjectRequested(this, n"OnOverflowEjectRequested"));

        Add_Step_WaitUntil("every holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the first rock", n"Step_StowFirst");
        Add_Step_WaitUntil("slot 0 holds it", n"Check_FirstStowed");
        Add_Step("stow the second rock", n"Step_StowSecond");
        Add_Step_WaitUntil("slot 1 holds it", n"Check_SecondStowed");
        Add_Step("stow the third rock", n"Step_StowThird");
        Add_Step_WaitUntil("the overflow slot holds it and is selected", n"Check_OverflowFilled");
        Add_Step("select bag slot 0", n"Step_SelectZero");
        Add_Step_WaitUntil("the eject request fired for pending index 0", n"Check_EjectRequested");
        Add_Step("the selection is still parked on the overflow slot", n"Step_AssertStillOnOverflow");
        Add_Step("select bag slot 0 again while parked", n"Step_SelectZero");
        Add_Step_WaitFrames("settle the re-press", 3);
        Add_Step("a re-press only re-parks", n"Step_AssertSingleEject");
        Add_Step("remove the overflow item", n"Step_RemoveOverflowItem");
        Add_Step_WaitUntil("the parked selection applies", n"Check_SelectedZero");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnOverflowEjectRequested(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem, int32 InPendingIndex)
    {
        _EjectCount += 1;
        _EjectPendingIndex = InPendingIndex;
        _EjectItem = InItem;
    }

    UFUNCTION()
    private void Check_HoldersSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSeeded = true;
        for (const auto& Holder : _Holders)
        { AllSeeded = AllSeeded && Holder.Get_NumItems() == 1; }

        auto Res = OutResult;
        Res.Set(AllSeeded);
    }

    UFUNCTION()
    private void Step_StowFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_FirstStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)));
    }

    UFUNCTION()
    private void Step_StowSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[1]);
    }

    UFUNCTION()
    private void Check_SecondStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(1)));
    }

    UFUNCTION()
    private void Step_StowThird(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[2]);
    }

    UFUNCTION()
    private void Check_OverflowFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_Slot(2).Get_NumItems() == 1 && _Hotbar.Get_SelectedIndex() == 2);
    }

    UFUNCTION()
    private void Step_SelectZero(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    private void Check_EjectRequested(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_EjectCount == 1 && _EjectPendingIndex == 0);
    }

    UFUNCTION()
    private void Step_AssertStillOnOverflow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Hotbar.Get_SelectedIndex(), 2, "SelectedIndex while the overflow item is still held");
        Assert_True(_EjectItem == _Hotbar.Get_ItemAt(2), "the eject request names the overflow item");
    }

    UFUNCTION()
    private void Step_AssertSingleEject(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_EjectCount, 1, "OnOverflowEjectRequested count after a re-press while parked");
        Assert_Equals_Int(_Hotbar.Get_SelectedIndex(), 2, "SelectedIndex after a re-press while parked");
    }

    UFUNCTION()
    private void Step_RemoveOverflowItem(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Overflow = _Hotbar.Get_Slot(2);
        auto Request = FCk_Request_Inventory_RemoveItem(_Hotbar.Get_ItemAt(2));
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Overflow.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
    }

    UFUNCTION()
    private void Check_SelectedZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex() == 0);
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
