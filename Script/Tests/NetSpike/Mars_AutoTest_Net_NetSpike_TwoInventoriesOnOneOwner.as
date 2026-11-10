// Probe D of the handle spike: two replicated capacity-1 DataOnly inventories (Slot.0, Slot.1) on one owner, the test
// SUBJECT, composed on both machines: the geometry of the hotbar's slots on the pawn. The server seeds one item into
// Slot.0 only. After a settle the client records what each slot holds. The framework's DataOnly replication keys its
// container by struct type on the lifetime owner (CkInventory_DataOnly_Processor.cpp), which predicts that Slot.1 shows
// the item too. It passes by recording: it logs one [NetSpike] D line and asserts only that it ran to the end.
// Surface: Ck.NetSpike.Net.AS_NetSpike_TwoInventoriesOnOneOwner
class UCk_AutoTest_Net_NetSpike_TwoInventoriesOnOneOwner : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 12.0f;

    private const float32 k_ServerHoldSeconds = 5.0f;
    private const float32 k_ClientSettleSeconds = 3.0f;

    private FCk_Handle_Inventory_DataOnly _Slot0;
    private FCk_Handle_Inventory_DataOnly _Slot1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _Slot0 = utils_net_spike::Add_OneSlotInventory(Subject, utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.Slot.0"));
        _Slot1 = utils_net_spike::Add_OneSlotInventory(Subject, utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.Slot.1"));

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
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
        const auto Count0 = _Slot0.Get_NumItems();
        const auto Count1 = _Slot1.Get_NumItems();
        Log(f"[NetSpike-server] D slot0={Count0} slot1={Count1}");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Slot0 = Describe(_Slot0);
        const auto Slot1 = Describe(_Slot1);
        const auto SameItem = Get_IsSameItemInBoth();
        Log(f"[NetSpike] D slot0={Slot0} slot1={Slot1} sameItemInBoth={SameItem}");
        FinishSuccess();
    }

    private FString Describe(FCk_Handle_Inventory_DataOnly InSlot)
    {
        auto Items = InSlot.Get_Items();
        auto Valid = 0;
        for (auto Item : Items)
        {
            if (ck::IsValid(Item))
            { Valid += 1; }
        }

        return f"{Items.Num()}items/{Valid}valid";
    }

    private bool Get_IsSameItemInBoth()
    {
        auto Items0 = _Slot0.Get_Items();
        auto Items1 = _Slot1.Get_Items();
        return Items0.Num() == 1 && Items1.Num() == 1 && Items0[0] == Items1[0];
    }
}
