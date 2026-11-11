// The smallest replicated Mars entity script, for the replicated-spawn tests: every machine's DoConstruct records the
// Payload it received, so a client finds its copy by tag and Payload (utils_net_spawn_test::Find_Carrier). A carrier spawned
// with ChildInConstruct requests one Replicates child of its own from DoConstruct.

namespace constants_net_spawn_test
{
    const FName k_CarrierTag = n"TAG_MarsTestNetSpawnCarrier";
}

// What this machine's DoConstruct received; never replicated.
struct FMars_TESTONLY_NetSpawn_CarrierPayload
{
    UPROPERTY()
    int32 Payload = 0;

    FMars_TESTONLY_NetSpawn_CarrierPayload() {}

    FMars_TESTONLY_NetSpawn_CarrierPayload(int32 InPayload)
    {
        Payload = InPayload;
    }
}

// What a test spawns the carrier with; injection matches by property name.
struct FMars_TESTONLY_NetSpawn_CarrierParams
{
    UPROPERTY()
    FTransform SpawnTransform;

    UPROPERTY()
    int32 Payload = 0;

    UPROPERTY()
    bool ChildInConstruct = false;

    FMars_TESTONLY_NetSpawn_CarrierParams() {}

    FMars_TESTONLY_NetSpawn_CarrierParams(FVector InLocation, int32 InPayload)
    {
        SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);
        Payload = InPayload;
    }
}

class UMars_TESTONLY_NetSpawn_Carrier_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under a replicated owner; the entity and its transform replicate.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    int32 Payload = 0;

    // DoConstruct requests a Replicates child of this entity, payload utils_net_spawn_test::Get_ChildPayload(Payload), on
    // every machine (a client's request is the placeholder the replicated child resolves).
    UPROPERTY(ExposeOnSpawn)
    bool ChildInConstruct = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, constants_net_spawn_test::k_CarrierTag);
        InHandle.Add_Fragment(FMars_TESTONLY_NetSpawn_CarrierPayload(Payload));

        if (ChildInConstruct)
        { utils_net_spawn_test::Request_CarrierChild(InHandle, utils_net_spawn_test::Get_ChildPayload(Payload)); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

namespace utils_net_spawn_test
{
    int32 Get_ChildPayload(int32 InParentPayload)
    { return InParentPayload * 10 + 1; }

    // A flagless carrier child of InParent.
    void Request_CarrierChild(FCk_Handle& InParent, int32 InPayload)
    {
        auto Params = FMars_TESTONLY_NetSpawn_CarrierParams(FVector::ZeroVector, InPayload);
        utils_entity_script::Request_SpawnEntity(InParent, UMars_TESTONLY_NetSpawn_Carrier_EntityScript, Params);
    }
}
