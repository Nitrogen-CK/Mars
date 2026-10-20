// The hotbar gate cannot undo a ledger. A carrier whose hotbar is full (a rock in its one bag slot, another in the overflow
// slot) focuses the meat slab's pickup: the gate disables it, as nowhere could stow the slab. A ledger then claims the
// pickup, as a pan admitting the slab does. Moving the bag slot's rock back out frees room and the gate lets go; the
// ledger still holds the slab, so its pickup stays disabled, and the framework target with it. Isolated origin
// (58000, -12000, -30000).
class UMars_AutoTest_WorldItem_AHotbarGateCannotReenableALedgerHeldPickup : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(58000.0, -12000.0, -30000.0);
    // A food item's construction waits for its joint to import.
    private const int32 k_SlowPolls = 900;

    // Under construction until it is a WorldItem whose holder holds its item.
    private FCk_Handle _Entity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle_Item _SlabItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        _Entity = Spawn_FoodItemOnFloor(InHandle, mars_items::Food_MeatSlab(), k_Origin + FVector(200.0, 0.0, 0.0));

        Add_Step_WaitUntil("both rock holders are seeded", n"Check_HoldersSeeded", 0, 0);
        Add_Step_WaitUntil("the slab is constructed and its holder holds its item", n"Check_Constructed", k_SlowPolls, 0);
        Add_Step("stow the first rock into the bag slot", n"Step_StowFirst");
        Add_Step_WaitUntil("the bag slot holds the first rock", n"Check_FirstStowed", 0, 0);
        Add_Step("stow the second rock into the overflow slot", n"Step_StowSecond");
        Add_Step_WaitUntil("the hotbar has nowhere to stow the slab", n"Check_HotbarFull", 0, 0);
        Add_Step("the carrier focuses the slab's pickup", n"Step_Focus");
        Add_Step_WaitUntil("the hotbar gate disabled the pickup", n"Check_PickupDisabled", 0, 0);
        Add_Step("a ledger claims the slab's pickup", n"Step_LedgerClaims");
        Add_Step_WaitUntil("the ledger's claim is on the pickup", n"Check_LedgerClaimed", 0, 0);
        Add_Step("move the first rock back out of the bag slot", n"Step_FreeBagSlot");
        Add_Step_WaitUntil("the bag slot is free: the hotbar could stow the slab", n"Check_RoomFreed", 0, 0);
        Add_Step_WaitFrames("the gate's answer to the freed slot drains", 5);
        Add_Step("the ledger still holds the slab: its pickup and its framework target stay disabled", n"Step_AssertStillDisabled");
        Run_Steps(InHandle);
    }

    private FCk_Handle_InteractTarget Get_PickupTarget() const
    {
        return _Slab.Get_Pickup().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto WorldItem = TryGet_ConstructedWorldItem(_Entity);
        const auto IsConstructed = ck::IsValid(WorldItem);
        if (IsConstructed && ck::Is_NOT_Valid(_Slab))
        {
            _Slab = WorldItem;
            _SlabItem = _Slab.Get_HeldItem();
        }

        auto Res = OutResult;
        Res.Set(IsConstructed);
    }

    UFUNCTION()
    private void Check_FirstStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(0) == _Items[0]);
    }

    UFUNCTION()
    private void Check_HotbarFull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(_Hotbar.Get_OverflowIndex()) == _Items[1] && _Hotbar.Get_CanStow(_SlabItem) == false);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Slab.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
    }

    UFUNCTION()
    private void Check_PickupDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Check_LedgerClaimed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.Get_Pickup().Get_IsDisabledFor(EMars_Interactable_DisableReason::Ledger));
    }

    UFUNCTION()
    private void Step_LedgerClaims(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_world_item::Request_ClaimPickup(_Entity, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Step_FreeBagSlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Slot = _Hotbar.Get_Slot(0);
        Slot.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Items[0], _Holders[0]),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_RoomFreed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)) && _Hotbar.Get_CanStow(_SlabItem));
    }

    UFUNCTION()
    private void Step_AssertStillDisabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Slab.Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Disable,
            "the ledger's claim outlives the gate: the slab's pickup stays disabled");
        Assert_True(utils_interact_target::Get_Enabled(Get_PickupTarget()) == ECk_EnableDisable::Disable,
            "the pickup's framework target is disabled with it");
        Assert_True(_Slab.Get_Mount() == EMars_WorldItem_Mount::World, "the slab still lies in the world");
    }
}
