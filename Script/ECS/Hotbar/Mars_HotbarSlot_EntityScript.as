// One hotbar slot's root: a lifetime child of the hotbar's carrier holding the slot's capacity-1 inventory
// (utils_hotbar::Add_Slot). Spawned only by UMars_Processor_Hotbar_SpawnSlots, which picks this class when the carrier
// has a replication driver and the local twin below when it has none; the guards make either mistake loud.
class UMars_HotbarSlot_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: replicates with its carrier; the authority builds it and a client's request is the placeholder it
    // resolves to (matched by Index and Kind), so its inventory replicates through a driver of its own.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    int32 Index = 0;

    UPROPERTY(ExposeOnSpawn)
    EMars_Hotbar_SlotKind Kind = EMars_Hotbar_SlotKind::Bag;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        if (Get_IsMisplaced(InHandle))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        utils_entity_tag::Add(InHandle, n"TAG_MarsHotbarSlot");
        utils_hotbar::Add_Slot(InHandle, FMars_HotbarSlot_Spec(Index, Kind, _Replication));
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // Game worlds only (an editor preview world has no net). Each guard ensures once; the slot is then destroyed, which
    // leaves the hotbar unready rather than holding a slot whose contents never reach the other machines.
    private bool Get_IsMisplaced(const FCk_Handle& InHandle) const
    {
        const UWorld EntityWorld = utils_entity_lifetime::Get_WorldForEntity(InHandle);
        if (ck::Is_NOT_Valid(EntityWorld) || EntityWorld.IsGameWorld() == false)
        { return false; }

        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InHandle);
        const auto OwnerHasDriver = ck::IsValid(Owner) && utils_entity_replication_driver::Has(Owner);
        const auto Replicates = _Replication == ECk_Replication::Replicates;

        if (ck::EnsureIfNot(Replicates || OwnerHasDriver == false,
            f"[Hotbar] Slot [{Index}] [{InHandle.ToString()}] is the local slot class under [{Owner.ToString()}], which has a "
            + "replication driver: its contents would never reach the other machines. Spawn slots through utils_hotbar::Add. Destroyed."))
        { return true; }

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return false; }

        if (ck::EnsureIfNot(ck::IsValid(Owner) && Owner.Is_Hotbar(),
            f"[Hotbar] Slot [{Index}] [{InHandle.ToString()}] is under [{Owner.ToString()}], which is not a hotbar: spawn slots "
            + "through utils_hotbar::Add. Destroyed."))
        { return true; }

        if (ck::EnsureIfNot(Replicates == false || utils_entity_replication_driver::Has(InHandle),
            f"[Hotbar] Slot [{Index}] [{InHandle.ToString()}] is the replicated slot class with no replication driver on an "
            + f"authority (its carrier [{Owner.ToString()}] has none): its inventory cannot create an item. Spawn slots "
            + "through utils_hotbar::Add. Destroyed."))
        { return true; }

        return false;
    }
}

// The slot root for a carrier with no replication driver (a single-machine test rig): the same slot, local on its one
// machine.
class UMars_HotbarSlot_Local_EntityScript : UMars_HotbarSlot_EntityScript
{
    // Stance D: a driverless carrier replicates nothing, so neither does its slot.
    default _Replication = ECk_Replication::DoesNotReplicate;
}
