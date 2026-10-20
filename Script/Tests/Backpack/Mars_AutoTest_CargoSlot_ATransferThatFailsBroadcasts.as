// A holder accept policy that refuses every item, so any transfer into it fails.
class UMars_AutoTestHelper_CargoSlot_RefusingTarget : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = false; }
}

// A take whose target refuses the item fails, and the slot reports it once. A rock is stowed from its holder into a
// backpack's cargo slot 0, and OnItemChanged fires once, naming it. The rock is then taken toward a holder whose accept
// policy refuses everything. CkInventory rolls the transfer back. The slot's request processor ensures and broadcasts
// OnTransferFailed exactly once, from slot 0, naming the rock. The rock stays in slot 0, the refusing holder stays empty
// and OnItemChanged does not fire again. The actor below expects the rollback's warning and requires the ensure.
// Isolated Z band: -89000.
class UMars_AutoTest_CargoSlot_ATransferThatFailsBroadcasts : UMars_AutoTestRig_Carrier
{
    private FCk_Handle_Backpack _Backpack;
    private FCk_Handle_CargoSlot _Slot0;
    private FCk_Handle_Inventory_DataOnly _RefusingHolder;
    // Every OnItemChanged of slot 0, in order (invalid = emptied).
    private TArray<FCk_Handle_Item> _ItemChanges;
    // Every OnTransferFailed, in order: the slot that reported it and the item it names.
    private TArray<FCk_Handle_CargoSlot> _FailedSlots;
    private TArray<FCk_Handle_Item> _FailedItems;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_Backpack_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(200.0, 0.0, -89000.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnBackpackConstructed"));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
        _RefusingHolder = MakeRefusingHolder(InHandle);

        Add_Step_WaitUntil("the backpack is constructed with one cargo slot per mount and the rock's holder is seeded", n"Check_Ready");
        Add_Step("bind slot 0's signals and stow the rock into it from its holder", n"Step_BindAndStow");
        Add_Step_WaitUntil("slot 0 holds the rock", n"Check_Stowed");
        Add_Step("slot 0 announced the rock once; take it toward the refusing holder", n"Step_AssertStowedAndTake");
        Add_Step_WaitUntil("slot 0 reported the failed transfer", n"Check_TransferFailed");
        Add_Step("one failure naming the rock, and nothing moved", n"Step_AssertNothingMoved");
        Run_Steps(InHandle);
    }

    private FCk_Handle_Inventory_DataOnly MakeRefusingHolder(FCk_Handle InHandle)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        TSubclassOf<UMars_AutoTestHelper_CargoSlot_RefusingTarget> PolicyClass = UMars_AutoTestHelper_CargoSlot_RefusingTarget;
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(PolicyClass.GetDefaultObject(), n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        return utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);
    }

    UFUNCTION()
    private void OnBackpackConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Backpack = InEntityScriptHandle.As_Backpack();
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InMaybeItem)
    {
        _ItemChanges.Add(InMaybeItem);
    }

    UFUNCTION()
    private void OnSlotTransferFailed(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InItem)
    {
        _FailedSlots.Add(InSlot);
        _FailedItems.Add(InItem);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const UMars_ItemTrait_Backpack Trait = mars_items::Backpack().Get_ItemTraitByClass(UMars_ItemTrait_Backpack);
        const auto Ready = ck::IsValid(_Backpack) && _Backpack.Get_CargoSlotCount() == Trait.CargoSlots.Num() &&
            _Holders[0].Get_NumItems() == 1;
        if (Ready && _Items.Num() == 0)
        {
            auto Items = _Holders[0].Get_Items();
            _Items.Add(Items[0]);
            _Slot0 = _Backpack.Get_CargoSlot(0);
        }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Step_BindAndStow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Slot0, "cargo slot 0");
        _Slot0.BindTo_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged"));
        _Slot0.BindTo_OnTransferFailed(FMars_Delegate_CargoSlot_OnTransferFailed(this, n"OnSlotTransferFailed"));
        _Slot0.Request_Stow(FMars_Request_CargoSlot_Stow(_Items[0]));
    }

    UFUNCTION()
    private void Check_Stowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slot0.Get_Item() == _Items[0] && _ItemChanges.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertStowedAndTake(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ItemChanges.Num(), 1, "OnItemChanged fired once for the stow");
        Assert_True(_ItemChanges[0] == _Items[0], "the stow's OnItemChanged names the rock");
        Assert_Equals_Int(_Holders[0].Get_NumItems(), 0, "the rock's holder emptied into slot 0");
        Assert_Equals_Int(_FailedItems.Num(), 0, "no transfer failed while stowing");

        _Slot0.Request_Take(FMars_Request_CargoSlot_Take(_Items[0], _RefusingHolder));
    }

    UFUNCTION()
    private void Check_TransferFailed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailedItems.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertNothingMoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FailedItems.Num(), 1, "OnTransferFailed fired once");
        Assert_True(_FailedSlots[0] == _Slot0, "slot 0 reported the failure");
        Assert_True(_FailedItems[0] == _Items[0], "the failure names the rock");
        Assert_True(_Slot0.Get_Item() == _Items[0], "the rock is still in slot 0");
        Assert_Equals_Int(_RefusingHolder.Get_NumItems(), 0, "the refusing holder stayed empty");
        Assert_Equals_Int(_ItemChanges.Num(), 1, "OnItemChanged did not fire again");
    }
}

// Hand-authored so CkInventory's rollback warning for the refused take is expected and the slot's ensure is required
// exactly once. The warning is pinned to the item definition and the refusal reason; the ensure to the refusing target
// and the transfer result.
class AMars_AutoTest_CargoSlot_ATransferThatFailsBroadcasts_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_CargoSlot_ATransferThatFailsBroadcasts;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Item (Mars_ItemDef_Rock))] (Failed Rejected by Custom Acceptance Logic)");
        return Out;
    }

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Inventory.Mars.WorldItemHolder)] failed with [Failed_RejectedByCustomAcceptanceLogic]");
        return Out;
    }
}
