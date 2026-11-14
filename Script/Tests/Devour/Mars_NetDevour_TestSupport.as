// Harness probes, not features: the smallest replicated devourer and victim, for the Devour net tests. The server
// spawns them under utils_mars_net::Get_ReplicatedSpawnOwner; every machine composes its own copy.

// The devourer's spawn params, by the script's ExposeOnSpawn names, so no call site waits for the generated ones.
struct FMars_NetDevour_Devourer_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Devour_Timing Timing;

    UPROPERTY()
    ECk_EnableDisable ViewNode = ECk_EnableDisable::Disable;

    FMars_NetDevour_Devourer_SpawnParams() {}

    FMars_NetDevour_Devourer_SpawnParams(FTransform InSpawnTransform, FMars_Devour_Timing InTiming)
    {
        SpawnTransform = InSpawnTransform;
        Timing = InTiming;
    }
}

class UMars_NetDevour_Devourer_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity, its transform and its Devour ledger replicate.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Devour_Timing Timing;

    // Enabled, a scene node under the root is the spec's View.
    UPROPERTY(ExposeOnSpawn)
    ECk_EnableDisable ViewNode = ECk_EnableDisable::Disable;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetDevourer");

        auto Spec = FMars_Devour_Spec();
        Spec.Timing = Timing;
        if (ViewNode == ECk_EnableDisable::Enable)
        { Spec.View = utils_scene_node::Create(Root, FTransform::Identity).As_Transform(); }

        utils_devour::Add(InHandle, Spec);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

// The victim's spawn params, by the script's ExposeOnSpawn name.
struct FMars_NetDevour_Victim_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    FMars_NetDevour_Victim_SpawnParams() {}

    FMars_NetDevour_Victim_SpawnParams(FTransform InSpawnTransform)
    {
        SpawnTransform = InSpawnTransform;
    }
}

class UMars_NetDevour_Victim_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity and its transform replicate, nothing else.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetDevourVictim");
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}
