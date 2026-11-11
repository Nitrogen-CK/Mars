// The hotbar net tests' shared steps, on top of the world-item net rig: the carrier (a hand node, a hotbar with no
// backpack slot, HeldItem and HeldItemUse) is composed on the subject on both machines, as the pawn composes them, and
// each machine counts the hotbar signals its own copy raises.
UCLASS(Abstract)
class UMars_AutoTestRig_NetHotbar : UMars_AutoTestRig_NetWorldItem
{
    protected FMars_TESTONLY_NetCarrier _Carrier;
    protected int32 _SelectionChanges = 0;
    protected int32 _EjectRequests = 0;

    protected void Compose_HotbarCarrier(FVector InHandLocation, int32 InBagSlots)
    {
        _Carrier = Compose_Carrier(InHandLocation, InBagSlots);
        _Carrier.Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnCarrierSelectionChanged"));
        _Carrier.Hotbar.BindTo_OnOverflowEjectRequested(FMars_Delegate_Hotbar_OnOverflowEjectRequested(this, n"OnCarrierEjectRequested"));
    }

    UFUNCTION()
    protected void OnCarrierSelectionChanged(FCk_Handle_Hotbar InHotbar)
    {
        _SelectionChanges += 1;
    }

    UFUNCTION()
    protected void OnCarrierEjectRequested(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem)
    {
        _EjectRequests += 1;
    }

    UFUNCTION()
    protected void Is_HotbarReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier));
    }

    // Server: one item of InDefinition straight into InSlot. The hotbar must be ready.
    protected void Seed_ServerSlotWith(int32 InSlot, UCk_InventoryItem_Definition InDefinition)
    {
        auto Slot = _Carrier.Hotbar.Get_Slot(InSlot);
        auto Request = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Slot.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
    }

    // How many items InSlot holds on this machine; 0 while it is not adopted.
    protected int32 Get_SlotItemCount(int32 InSlot) const
    {
        auto Slot = _Carrier.Hotbar.Get_Slot(InSlot);
        if (ck::Is_NOT_Valid(Slot))
        { return 0; }

        return Slot.Get_NumItems();
    }

    // InSlot holds exactly one item, of InDefinition, on this machine.
    protected bool Get_SlotHolds(int32 InSlot, UCk_InventoryItem_Definition InDefinition) const
    {
        auto Slot = _Carrier.Hotbar.Get_Slot(InSlot);
        if (ck::Is_NOT_Valid(Slot) || Slot.Get_NumItems() != 1)
        { return false; }

        const auto Item = Slot.Get_SoleItem();
        return ck::IsValid(Item) && Item.Get_Definition() == InDefinition;
    }

    // This machine's slot root at InSlot is the replicated class, a lifetime child of the subject.
    protected bool Get_IsReplicatedSlotOfTheSubject(int32 InSlot)
    {
        FCk_Handle Inventory = _Carrier.Hotbar.Get_Slot(InSlot);
        if (ck::Is_NOT_Valid(Inventory))
        { return false; }

        auto Root = utils_entity_lifetime::Get_LifetimeOwner(Inventory);
        return ck::IsValid(Root) && utils_entity_lifetime::Get_LifetimeOwner(Root) == Get_SubjectEntity()
            && utils_entity_script::Has(Root) && utils_entity_script::Get_ScriptClass(Root.As_EntityScript()) == UMars_HotbarSlot_EntityScript;
    }

    UFUNCTION()
    protected void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }
}
