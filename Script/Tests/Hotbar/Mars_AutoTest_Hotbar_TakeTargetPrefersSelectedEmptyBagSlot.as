// A taken item lands in the selected bag slot when it is empty (into the hands); otherwise it goes wherever a stow would
// put it: the first empty bag slot for an ordinary item, the backpack slot for a backpack.
class UMars_AutoTest_Hotbar_TakeTargetPrefersSelectedEmptyBagSlot : UCk_AutoTest_Base
{
    private FCk_Handle_Hotbar _Hotbar;

    // [0] Rock, [1] Cog, [2] Backpack.
    private TArray<FCk_Handle_Inventory_DataOnly> _Holders;
    private TArray<FCk_Handle_Item> _Items;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        _Hotbar = utils_hotbar::Add(LocalHandle, Spec);

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Cog()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Backpack()));

        Add_Step_WaitUntil("every holder holds its item", n"Check_HoldersSeeded");
        Add_Step("select empty slot 0", n"Step_SelectZero");
        Add_Step_WaitUntil("slot 0 is selected with empty hands", n"Check_SelectedZero");
        Add_Step("the rock's take target is the selected empty slot", n"Step_AssertTakeTargetIsSelected");
        Add_Step("stow the rock", n"Step_StowRock");
        Add_Step_WaitUntil("slot 0 holds the rock and stays selected", n"Check_RockInSelectedSlot");
        Add_Step("with slot 0 occupied, take targets follow the stow target", n"Step_AssertTakeTargetsFollowStow");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_HoldersSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSeeded = true;
        for (const auto& Holder : _Holders)
        { AllSeeded = AllSeeded && Holder.Get_NumItems() == 1; }

        if (AllSeeded && _Items.Num() == 0)
        {
            for (const auto& Holder : _Holders)
            {
                auto Items = Holder.Get_Items();
                _Items.Add(Items[0]);
            }
        }

        auto Res = OutResult;
        Res.Set(AllSeeded);
    }

    UFUNCTION()
    private void Step_SelectZero(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    private void Check_SelectedZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex() == 0 && ck::Is_NOT_Valid(_Hotbar.Get_SelectedItem()));
    }

    UFUNCTION()
    private void Step_AssertTakeTargetIsSelected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.TryGet_TakeTarget(_Items[0]) == _Hotbar.Get_Slot(0), "the rock's take target with empty slot 0 selected");
    }

    UFUNCTION()
    private void Step_StowRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_RockInSelectedSlot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(0) == _Items[0] && _Hotbar.Get_SelectedIndex() == 0);
    }

    UFUNCTION()
    private void Step_AssertTakeTargetsFollowStow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.TryGet_TakeTarget(_Items[1]) == _Hotbar.Get_Slot(1), "the cog's take target with slot 0 occupied and slot 1 free");
        Assert_True(_Hotbar.TryGet_TakeTarget(_Items[2]) == _Hotbar.Get_BackpackSlot(), "the backpack's take target is the backpack slot");
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

    // What the pickup task does: transfer into whatever the hotbar names as the stow target for the item.
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
