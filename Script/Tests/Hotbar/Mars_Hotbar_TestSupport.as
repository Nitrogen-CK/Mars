// Test-only: a replicated carrier with a hotbar of its own (2 bag slots, the overflow, no backpack slot), for the tests
// that need a carrier with a replication driver on a single machine. Spawn it under the replicated spawn owner.
class UMars_TESTONLY_HotbarCarrier_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: replicates so its hotbar's slots take the replicated class.
    default _Replication = ECk_Replication::Replicates;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        Spec.BackpackSlot = ECk_EnableDisable::Disable;
        utils_hotbar::Add(InHandle, Spec);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

// The base of the single-machine tests on a replicated carrier: waits for the spawn owner, spawns the carrier under it
// from that continuation (tracked for cleanup) and waits for its hotbar to be ready.
UCLASS(Abstract)
class UMars_AutoTestRig_ReplicatedHotbarCarrier : UCk_AutoTest_Base
{
    protected FCk_Handle _Carrier;

    protected void Add_CarrierSteps()
    {
        Add_Step_WaitUntil("this world's replicated spawn owner is published", n"Check_SpawnOwnerReady");
        Add_Step("spawn the replicated carrier under the spawn owner", n"Step_SpawnCarrier");
        Add_Step_WaitUntil("the carrier's hotbar is ready", n"Check_CarrierHotbarReady");
    }

    protected FCk_Handle_Hotbar Get_CarrierHotbar() const
    {
        return _Carrier.As_Hotbar();
    }

    UFUNCTION()
    protected void Check_SpawnOwnerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(InHandle));
    }

    UFUNCTION()
    protected void Step_SpawnCarrier(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(InHandle);
        _Carrier = utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_HotbarCarrier_EntityScript, FInstancedStruct())
            .Get_EntityUnderConstruction();
        Track_ForCleanup(_Carrier);
    }

    UFUNCTION()
    protected void Check_CarrierHotbarReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Carrier) && _Carrier.Is_Hotbar() && _Carrier.As_Hotbar().Get_IsReady());
    }

    // InIndex's slot root; invalid while the slot is not adopted.
    protected FCk_Handle Get_SlotRoot(int32 InIndex) const
    {
        FCk_Handle Inventory = Get_CarrierHotbar().Get_Slot(InIndex);
        if (ck::Is_NOT_Valid(Inventory))
        { return FCk_Handle(); }

        return utils_entity_lifetime::Get_LifetimeOwner(Inventory);
    }
}
