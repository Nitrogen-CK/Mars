// A measurement carrier, not a feature: the smallest replicated Mars entity script that can be referenced by a replicated
// handle and can hold a replicated one-slot inventory, for the NetSpike probes. The server spawns it under
// utils_mars_net::Get_ReplicatedSpawnOwner; every machine's DoConstruct records the Payload it received, so a client finds
// its copy by tag and Payload. The probes write FMars_Fragment_NetSpike_Ref directly on the server through Get_Fragment +
// Request_MarkReplicationDirty, which only a feature's processors may do in game code.

namespace constants_net_spike
{
    const FName k_Tag = n"TAG_MarsNetSpike";
}

// The replicated reference under test: a handle to another replicated entity, and a serial that says which write it is.
struct FMars_Fragment_NetSpike_Ref
{
    UPROPERTY()
    FCk_Handle Target;

    UPROPERTY()
    int32 Serial = 0;
}

// What this machine's DoConstruct received and built; never replicated.
struct FMars_Fragment_NetSpike_Local
{
    UPROPERTY()
    int32 Payload = 0;

    // Invalid unless the spawn asked for an inventory.
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Inventory;
}

// What a probe spawns the carrier with; injection matches by property name.
struct FMars_NetSpike_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform;

    UPROPERTY()
    int32 Payload = 0;

    UPROPERTY()
    bool WithInventory = false;

    UPROPERTY()
    bool WithRef = false;

    FMars_NetSpike_SpawnParams() {}

    FMars_NetSpike_SpawnParams(FVector InLocation, int32 InPayload)
    {
        SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);
        Payload = InPayload;
    }
}

class UMars_NetSpike_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity, its transform, its inventory and its Ref replicate.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    int32 Payload = 0;

    // A capacity-1 replicated DataOnly inventory on the root.
    UPROPERTY(ExposeOnSpawn)
    bool WithInventory = false;

    // FMars_Fragment_NetSpike_Ref on the root, replicated.
    UPROPERTY(ExposeOnSpawn)
    bool WithRef = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, constants_net_spike::k_Tag);

        auto Local = FMars_Fragment_NetSpike_Local();
        Local.Payload = Payload;
        if (WithInventory)
        { Local.Inventory = utils_net_spike::Add_OneSlotInventory(InHandle, GameplayTags::Inventory_Mars_WorldItemHolder); }

        InHandle.Add_Fragment(Local);

        if (WithRef)
        { InHandle.Add_Fragment(FMars_Fragment_NetSpike_Ref(), ECk_Replication::Replicates); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

namespace utils_net_spike
{
    FCk_Handle_Inventory_DataOnly Add_OneSlotInventory(FCk_Handle& InOwner, FGameplayTag InName)
    {
        auto Params = utils_inventory_data_only::Make_Params_Bounded(InName, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(), FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        Params.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        return utils_inventory_data_only::Add(InOwner, Params, ECk_Replication::Replicates);
    }

    // The spike entity on InAny's machine whose DoConstruct received InPayload; invalid while it has not arrived.
    FCk_Handle Find(const FCk_Handle& InAny, int32 InPayload)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InAny, constants_net_spike::k_Tag))
        {
            if (Candidate.Has_Fragment(FMars_Fragment_NetSpike_Local) == false)
            { continue; }

            if (Candidate.Get_Fragment(FMars_Fragment_NetSpike_Local).Payload == InPayload)
            { return Candidate; }
        }

        return FCk_Handle();
    }

    FMars_Fragment_NetSpike_Local Get_Local(const FCk_Handle& InSpike)
    {
        return InSpike.Get_Fragment(FMars_Fragment_NetSpike_Local);
    }

    // How a probe's fact line spells a handle's validity.
    FString Get_ValidWord(bool InValid)
    {
        return InValid ? "valid" : "invalid";
    }
}
