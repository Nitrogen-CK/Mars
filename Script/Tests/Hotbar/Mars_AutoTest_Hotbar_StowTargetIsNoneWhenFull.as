// Once both bag slots and the overflow slot hold an item there is nowhere to stow: the pickup target goes silent.
class UMars_AutoTest_Hotbar_StowTargetIsNoneWhenFull : UCk_AutoTest_Base
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

        for (int32 Index = 0; Index < 3; ++Index)
        { _Holders.Add(MakeSeededHolder(InHandle)); }

        Add_Step_WaitUntil("every holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the first rock", n"Step_StowFirst");
        Add_Step_WaitUntil("slot 0 holds it", n"Check_FirstStowed");
        Add_Step("stow the second rock", n"Step_StowSecond");
        Add_Step_WaitUntil("slot 1 holds it", n"Check_SecondStowed");
        Add_Step("stow the third rock", n"Step_StowThird");
        Add_Step_WaitUntil("the overflow slot holds it and is selected", n"Check_OverflowFilled");
        Add_Step("no stow target remains", n"Step_AssertNoStowTarget");
        Run_Steps(InHandle);
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
        Res.Set(_Hotbar.Get_Slot(2).Get_NumItems() == 1 && _Hotbar.Get_SelectedIndex() == TOptional<int32>(2));
    }

    UFUNCTION()
    private void Step_AssertNoStowTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // Any non-backpack item asks the same question; the stowed rock in slot 0 is one at hand.
        const auto Rock = _Hotbar.Get_ItemAt(0);
        Assert_Invalid(_Hotbar.TryGet_StowTarget(Rock), "a rock has no stow target with every slot full");
        Assert_False(_Hotbar.Get_CanStow(Rock), "Get_CanStow(rock) is false with every slot full");
    }

    private FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
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
