// A harness probe, not a feature: the smallest replicated Mars entity script, for the replication net tests. The server
// spawns it under utils_mars_net::Get_ReplicatedSpawnOwner; every machine's DoConstruct records the Payload it received
// in a local fragment, and the ledger is the one replicated script fragment. The tests write the ledger directly on the
// server through Get_Fragment + Request_MarkReplicationDirty, which only a feature's processors may do in game code.

// What this machine's DoConstruct received; never replicated, so a client's copy proves the spawn params crossed.
struct FMars_Fragment_NetSmoke_Local
{
    UPROPERTY()
    int32 Payload = 0;

    FMars_Fragment_NetSmoke_Local(int32 InPayload)
    {
        Payload = InPayload;
    }
}

// The replicated ledger: written on the authority only, read everywhere.
struct FMars_Fragment_NetSmoke_Ledger
{
    UPROPERTY()
    int32 Value = 0;
}

class UMars_NetSmoke_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity, its transform and its ledger replicate.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    int32 Payload = 0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, FTransform::Identity, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsNetSmoke");
        InHandle.Add_Fragment(FMars_Fragment_NetSmoke_Local(Payload));
        InHandle.Add_Fragment(FMars_Fragment_NetSmoke_Ledger(), ECk_Replication::Replicates);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}
