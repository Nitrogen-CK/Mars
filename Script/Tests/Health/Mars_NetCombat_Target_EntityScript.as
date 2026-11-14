// A harness probe, not a feature: the smallest replicated entity with a Health, for the Health net tests. The server
// spawns it under utils_mars_net::Get_ReplicatedSpawnOwner; every machine composes its own Health, whose ledger is the
// entity's one replicated script fragment.

// The spawn params, by the script's ExposeOnSpawn names, so no call site waits for the generated ones.
struct FMars_NetCombat_Target_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    float32 MaxHealth = 100.0f;

    UPROPERTY()
    ECk_Team_ID Team = ECk_Team_ID::Two;

    FMars_NetCombat_Target_SpawnParams() {}

    FMars_NetCombat_Target_SpawnParams(FTransform InSpawnTransform, float32 InMaxHealth)
    {
        SpawnTransform = InSpawnTransform;
        MaxHealth = InMaxHealth;
    }
}

class UMars_NetCombat_Target_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity, its transform and its Health ledger replicate.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    float32 MaxHealth = 100.0f;

    UPROPERTY(ExposeOnSpawn)
    ECk_Team_ID Team = ECk_Team_ID::Two;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetCombatTarget");
        utils_team::Add(InHandle, Team, ECk_Replication::DoesNotReplicate);
        utils_health::Add(InHandle, FMars_Health_Spec(MaxHealth));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}
