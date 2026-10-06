// The backpack slot takes only backpack items and a backpack item fits nowhere else: stow targets are item-aware, a
// backpack arrival never changes the selection (the pack goes on the back), a second backpack has nowhere to go, and the
// slot's accept policy refuses a forced transfer that bypasses the stow target.
class UMars_AutoTest_Hotbar_BackpackSlotTakesOnlyBackpacks : UMars_AutoTestRig_Carrier
{
    // Unset until the forced transfer reports.
    private TOptional<ECk_Inventory_OperationResult_Transfer> _CogTransferResult;
    private TOptional<ECk_Inventory_OperationResult_Transfer> _Backpack2TransferResult;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Hotbar(InHandle, 1);

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Backpack()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Backpack()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Cog()));

        Add_Step_WaitUntil("every holder holds its item", n"Check_HoldersSeeded");
        Add_Step("stow targets are item-aware", n"Step_AssertStowTargets");
        Add_Step("force the cog into the empty backpack slot", n"Step_ForceCogIntoBackpackSlot");
        Add_Step_WaitUntil("the forced cog transfer reported", n"Check_CogTransferRecorded");
        Add_Step("the backpack slot's policy refused the cog", n"Step_AssertCogRefused");
        Add_Step("stow the rock", n"Step_StowRock");
        Add_Step_WaitUntil("slot 0 holds the rock and is auto-held", n"Check_RockStowedAndSelected");
        Add_Step("stow the backpack", n"Step_StowBackpack");
        Add_Step_WaitUntil("the backpack slot holds it", n"Check_WearingBackpack");
        Add_Step_WaitFrames("let the sync pass observe the backpack arrival", 3);
        Add_Step("the backpack arrival kept the selection", n"Step_AssertSelectionKept");
        Add_Step("a second backpack has nowhere to go", n"Step_AssertSecondBackpackHasNoTarget");
        Add_Step("force the second backpack into the occupied backpack slot", n"Step_ForceBackpack2IntoBackpackSlot");
        Add_Step_WaitUntil("the forced backpack transfer reported", n"Check_Backpack2TransferRecorded");
        Add_Step("the occupied backpack slot refused it", n"Step_AssertBackpack2Refused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertStowTargets(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_HasBackpackSlot(), "the default spec gives the hotbar a backpack slot");
        Assert_True(_Hotbar.Get_BackpackIndex() == TOptional<int32>(2), "with one bag slot the backpack slot is index 2");
        Assert_Equals_Int(_Hotbar.Get_LastIndex(), 2, "with one bag slot the last index is the backpack slot's");
        Assert_True(_Hotbar.TryGet_StowTarget(_Items[0]) == _Hotbar.Get_Slot(0), "the rock's stow target is bag slot 0");
        Assert_True(_Hotbar.TryGet_StowTarget(_Items[1]) == _Hotbar.Get_BackpackSlot(), "the backpack's stow target is the backpack slot");
    }

    UFUNCTION()
    private void Step_ForceCogIntoBackpackSlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Holder = _Holders[3];
        Holder.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(_Items[3], _Hotbar.Get_BackpackSlot()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnForcedCogTransfer"));
    }

    UFUNCTION()
    private void OnForcedCogTransfer(FCk_Handle_Inventory InSource,
                                     FCk_Handle_Item InItem,
                                     FCk_Handle_Inventory InTarget,
                                     int32 InCount,
                                     FCk_Handle_Item InNewItemInTarget,
                                     ECk_Inventory_OperationResult_Transfer InResult)
    {
        _CogTransferResult = TOptional<ECk_Inventory_OperationResult_Transfer>(InResult);
    }

    UFUNCTION()
    private void Check_CogTransferRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_CogTransferResult.IsSet());
    }

    UFUNCTION()
    private void Step_AssertCogRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto CogResult = _CogTransferResult.GetValue();
        Assert_True(CogResult != ECk_Inventory_OperationResult_Transfer::Success,
            f"a cog forced into the empty backpack slot reports a non-Success result (got [{CogResult :n}])");
        Assert_Equals_Int(_Hotbar.Get_BackpackSlot().Get_NumItems(), 0, "the backpack slot stays empty after the refused cog");
        Assert_Equals_Int(_Holders[3].Get_NumItems(), 1, "the cog's holder still holds it after the refused transfer");
    }

    UFUNCTION()
    private void Step_StowRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_RockStowedAndSelected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)) && _Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    private void Step_StowBackpack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[1]);
    }

    UFUNCTION()
    private void Check_WearingBackpack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_IsWearingBackpack());
    }

    UFUNCTION()
    private void Step_AssertSelectionKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_SelectedIndex() == TOptional<int32>(0), "the backpack arrival keeps slot 0 selected");
        Assert_True(_Hotbar.Get_BackpackItem() == _Items[1], "Get_BackpackItem is the stowed backpack");
    }

    UFUNCTION()
    private void Step_AssertSecondBackpackHasNoTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Invalid(_Hotbar.TryGet_StowTarget(_Items[2]), "a second backpack has no stow target while one is worn");
        Assert_False(_Hotbar.Get_CanStow(_Items[2]), "Get_CanStow(second backpack) is false while one is worn");
    }

    UFUNCTION()
    private void Step_ForceBackpack2IntoBackpackSlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Holder = _Holders[2];
        Holder.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(_Items[2], _Hotbar.Get_BackpackSlot()),
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
        _Backpack2TransferResult = TOptional<ECk_Inventory_OperationResult_Transfer>(InResult);
    }

    UFUNCTION()
    private void Check_Backpack2TransferRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Backpack2TransferResult.IsSet());
    }

    UFUNCTION()
    private void Step_AssertBackpack2Refused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Backpack2Result = _Backpack2TransferResult.GetValue();
        Assert_True(Backpack2Result != ECk_Inventory_OperationResult_Transfer::Success,
            f"a second backpack forced into the occupied backpack slot reports a non-Success result (got [{Backpack2Result :n}])");
        Assert_Equals_Int(_Holders[2].Get_NumItems(), 1, "the second backpack's holder still holds it after the refused transfer");
        Assert_True(_Hotbar.Get_BackpackItem() == _Items[1], "the backpack slot still holds the first backpack");
    }
}

// Hand-authored so CkInventory's rollback Warning for each of the two deliberately refused transfers is expected rather
// than a failure (the automation controller elevates Warnings to test errors). One entry per refusal, each pinned to the
// item definition and the refusal reason so an unrelated refusal still fails the test.
class AMars_AutoTest_Hotbar_BackpackSlotTakesOnlyBackpacks_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Hotbar_BackpackSlotTakesOnlyBackpacks;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Mars_ItemDef_Cog))] (Failed Rejected by Custom Acceptance Logic)");
        Out.Add("(Mars_ItemDef_Backpack))] (Failed No Space Available)");
        return Out;
    }
}
