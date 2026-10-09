// A hands-only item (the platter) stows into the overflow slot even while every bag slot is free, a bag slot's accept
// policy refuses it when a transfer bypasses the stow target, a later bag-slot arrival leaves the overflow selected, and a
// second hands-only item has nowhere to go (stow or take) while the overflow is taken.
class UMars_AutoTest_Hotbar_HandsOnlyItemStowsOnlyToTheOverflow : UMars_AutoTestRig_Carrier
{
    // Unset until the forced transfer reports.
    private TOptional<ECk_Inventory_OperationResult_Transfer> _PlatterTransferResult;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 2);

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Platter()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Platter()));

        Add_Step_WaitUntil("every holder holds its item", n"Check_HoldersSeeded");
        Add_Step("the platter's stow target is the overflow slot while every bag slot is free", n"Step_AssertStowTarget");
        Add_Step("force the platter into empty bag slot 0", n"Step_ForcePlatterIntoBagSlot");
        Add_Step_WaitUntil("the forced platter transfer reported", n"Check_PlatterTransferRecorded");
        Add_Step("bag slot 0's policy refused the platter", n"Step_AssertPlatterRefused");
        Add_Step("stow the platter", n"Step_StowFirst");
        Add_Step_WaitUntil("the overflow slot holds the platter and is selected", n"Check_PlatterInOverflowAndSelected");
        Add_Step("stow the rock", n"Step_StowSecond");
        Add_Step_WaitUntil("bag slot 0 holds the rock", n"Check_RockInBagSlot0");
        Add_Step_WaitFrames("let the sync pass observe the rock arrival", 3);
        Add_Step("the rock arrival kept the overflow selected", n"Step_AssertOverflowStillSelected");
        Add_Step("a second platter has no stow or take target while the overflow is taken", n"Step_AssertSecondPlatterHasNoTarget");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertStowTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Items[0].Has_HandsOnly(), "the platter is hands-only");
        Assert_False(_Items[1].Has_HandsOnly(), "the rock is not hands-only");
        Assert_True(_Hotbar.TryGet_StowTarget(_Items[0]) == _Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex()),
            "the platter's stow target is the overflow slot although both bag slots are free");
        Assert_True(_Hotbar.TryGet_StowTarget(_Items[1]) == _Hotbar.Get_Slot(0), "the rock's stow target is bag slot 0");
    }

    UFUNCTION()
    private void Step_ForcePlatterIntoBagSlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Holder = _Holders[0];
        Holder.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(_Items[0], _Hotbar.Get_Slot(0)),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnForcedPlatterTransfer"));
    }

    UFUNCTION()
    private void OnForcedPlatterTransfer(FCk_Handle_Inventory InSource,
                                         FCk_Handle_Item InItem,
                                         FCk_Handle_Inventory InTarget,
                                         int32 InCount,
                                         FCk_Handle_Item InNewItemInTarget,
                                         ECk_Inventory_OperationResult_Transfer InResult)
    {
        _PlatterTransferResult = TOptional<ECk_Inventory_OperationResult_Transfer>(InResult);
    }

    UFUNCTION()
    private void Check_PlatterTransferRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PlatterTransferResult.IsSet());
    }

    UFUNCTION()
    private void Step_AssertPlatterRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PlatterResult = _PlatterTransferResult.GetValue();
        Assert_True(PlatterResult != ECk_Inventory_OperationResult_Transfer::Success,
            f"a platter forced into an empty bag slot reports a non-Success result (got [{PlatterResult :n}])");
        Assert_Equals_Int(_Hotbar.Get_Slot(0).Get_NumItems(), 0, "bag slot 0 stays empty after the refused platter");
        Assert_Equals_Int(_Holders[0].Get_NumItems(), 1, "the platter's holder still holds it after the refused transfer");
    }

    UFUNCTION()
    private void Check_PlatterInOverflowAndSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto OverflowIndex = _Hotbar.Get_OverflowIndex();
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(OverflowIndex) == _Items[0] && _Hotbar.Get_SelectedIndex() == TOptional<int32>(OverflowIndex));
    }

    UFUNCTION()
    private void Check_RockInBagSlot0(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(0) == _Items[1]);
    }

    UFUNCTION()
    private void Step_AssertOverflowStillSelected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(_Hotbar.Get_OverflowIndex()),
            "a bag-slot arrival keeps the occupied overflow slot selected");
        Assert_True(_Hotbar.Get_ItemAt(_Hotbar.Get_OverflowIndex()) == _Items[0], "the overflow slot still holds the platter");
    }

    UFUNCTION()
    private void Step_AssertSecondPlatterHasNoTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Invalid(_Hotbar.TryGet_StowTarget(_Items[2]), "a second platter has no stow target while the overflow is taken");
        Assert_False(_Hotbar.Get_CanStow(_Items[2]), "Get_CanStow(second platter) is false while the overflow is taken");
        Assert_Invalid(_Hotbar.TryGet_TakeTarget(_Items[2]), "a second platter has no take target while the overflow is taken");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(1)), "bag slot 1 is still free: a hands-only item never takes it");
    }
}

// Hand-authored so CkInventory's rollback Warning for the deliberately refused transfer is expected rather than a failure
// (the automation controller elevates Warnings to test errors). Pinned to the item definition and the refusal reason so
// an unrelated refusal still fails the test.
class AMars_AutoTest_Hotbar_HandsOnlyItemStowsOnlyToTheOverflow_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Hotbar_HandsOnlyItemStowsOnlyToTheOverflow;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Mars_ItemDef_Platter))] (Failed Rejected by Custom Acceptance Logic)");
        return Out;
    }
}
