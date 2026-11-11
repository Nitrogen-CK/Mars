// Pins a framework fact: two replicated capacity-1 DataOnly inventories (Slot.0, Slot.1) on one lifetime owner, the test
// subject, composed on both machines, show the same contents on a client. The server seeds one item into Slot.0 only and
// keeps the slots apart (Slot.0 holds it, Slot.1 is empty); the client's Slot.0 and Slot.1 both hold that one item, the
// same entity. DataOnly replication keys its container by struct type on the lifetime owner, not by inventory.
// The hotbar is built on this fact: each slot is a root of its own (UMars_HotbarSlot_EntityScript, see the header of
// Script/ECS/Hotbar/Mars_Hotbar_Feature.as) so that no two slot inventories share an owner. Red means the framework
// changed: if the client's slots now hold what the server's hold, DataOnly contents replicate per inventory and the
// per-slot roots may be simplified back to inventories on the carrier; any other result, re-check the hotbar's slots.
// Surface: Ck.Replication.Net.AS_Replication_TwoInventoriesOnOneOwnerShareContentsOnAClient
class UCk_AutoTest_Net_Replication_TwoInventoriesOnOneOwnerShareContentsOnAClient : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 12.0f;

    private const float32 k_ServerHoldSeconds = 5.0f;
    // A later write would show as a changed count or a different item.
    private const float32 k_ClientSettleSeconds = 1.0f;
    // Frames the client waits for the seeded item at all (8 s at the pinned 60 fps).
    private const int32 k_ClientMaxFrames = 480;

    private FCk_Handle_Inventory_DataOnly _Slot0;
    private FCk_Handle_Inventory_DataOnly _Slot1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _Slot0 = Add_OneSlotInventory(Subject, utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.Slot.0"));
        _Slot1 = Add_OneSlotInventory(Subject, utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.Slot.1"));

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientSlot0Filled", n"OnClientFilled", k_ClientMaxFrames);
            return;
        }

        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Rock(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        _Slot0.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition(this, n"OnServerSeeded"));
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Inventory InInventory, ECk_Inventory_OperationResult_AddByDefinition InResult,
                                int InAmountAdded, const TArray<FCk_Handle_Item>&in InItemsCreated)
    {
        if (InResult != ECk_Inventory_OperationResult_AddByDefinition::Success_AllAdded)
        { FinishFailure(f"seeding Slot.0 failed with [{InResult :n}]"); return; }

        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[MarsNet] two inventories on one owner, server: slot0={_Slot0.Get_NumItems()} slot1={_Slot1.Get_NumItems()}");
        Assert_Equals_Int(_Slot0.Get_NumItems(), 1, "the server's Slot.0 holds the seeded item");
        Assert_Equals_Int(_Slot1.Get_NumItems(), 0, "the server's Slot.1 stays empty");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientSlot0Filled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Slot0.Get_NumItems() > 0);
    }

    UFUNCTION()
    private void OnClientFilled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Items0 = _Slot0.Get_Items();
        auto Items1 = _Slot1.Get_Items();
        const auto SameItem = Items0.Num() == 1 && Items1.Num() == 1 && Items0[0] == Items1[0];
        Log(f"[MarsNet] two inventories on one owner, client: slot0={Describe(Items0)} slot1={Describe(Items1)} sameItemInBoth={SameItem}");

        Assert_False(utils_net::Get_HasAuthority(_Slot0), "the client's Slot.0 has no authority");
        Assert_Equals_Int(Items0.Num(), 1, "the client's Slot.0 holds the seeded item");
        Assert_Equals_Int(Get_ValidCount(Items0), 1, "the client's Slot.0 item is valid");
        Assert_Equals_Int(Items1.Num(), 1, "the client's Slot.1 shows Slot.0's item although the server's is empty");
        Assert_Equals_Int(Get_ValidCount(Items1), 1, "the client's Slot.1 item is valid");
        Assert_True(SameItem, "both client slots hold the same item entity");
        FinishSuccess();
    }

    private FCk_Handle_Inventory_DataOnly Add_OneSlotInventory(FCk_Handle& InOwner, FGameplayTag InName)
    {
        auto Params = utils_inventory_data_only::Make_Params_Bounded(InName, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(), FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        Params.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        return utils_inventory_data_only::Add(InOwner, Params, ECk_Replication::Replicates);
    }

    private int32 Get_ValidCount(const TArray<FCk_Handle_Item>& InItems) const
    {
        auto Valid = 0;
        for (auto Item : InItems)
        {
            if (ck::IsValid(Item))
            { Valid += 1; }
        }

        return Valid;
    }

    private FString Describe(const TArray<FCk_Handle_Item>& InItems) const
    {
        return f"{InItems.Num()}items/{Get_ValidCount(InItems)}valid";
    }
}
