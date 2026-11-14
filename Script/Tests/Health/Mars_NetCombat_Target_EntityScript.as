// A harness probe, not a feature: the smallest replicated entity with a Health, for the combat net tests. The server
// spawns it under utils_mars_net::Get_ReplicatedSpawnOwner; every machine composes its own Health, whose ledger is the
// entity's one replicated script fragment, a Body zone on the root with one box hurtbox, and, when asked, a limb zone on
// a child entity that is known through the root.

// The spawn params, by the script's ExposeOnSpawn names, so no call site waits for the generated ones.
struct FMars_NetCombat_Target_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    float32 MaxHealth = 100.0f;

    UPROPERTY()
    ECk_Team_ID Team = ECk_Team_ID::Two;

    UPROPERTY()
    ECk_EnableDisable LimbZone = ECk_EnableDisable::Disable;

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

    // Enabled, a child entity carries a Health and a Limb zone registered on this root, after the Body zone.
    UPROPERTY(ExposeOnSpawn)
    ECk_EnableDisable LimbZone = ECk_EnableDisable::Disable;

    private const float32 k_LimbMaxHealth = 30.0f;
    private const float32 k_CrushMultiplier = 1.5f;
    private const FVector k_HurtboxHalfExtents = FVector(40.0, 40.0, 40.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetCombatTarget");
        utils_team::Add(InHandle, Team, ECk_Replication::DoesNotReplicate);
        utils_health::Add(InHandle, FMars_Health_Spec(MaxHealth));

        auto Zone = utils_hit_zone::Add(InHandle, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, k_CrushMultiplier));
        utils_hit_zone::AddHurtbox_Box(Zone, Root, FMars_HitZone_Hurtbox(k_HurtboxHalfExtents, FTransform::Identity));

        if (LimbZone == ECk_EnableDisable::Enable)
        {
            auto Limb = utils_entity_lifetime::Request_CreateEntity(InHandle);
            utils_health::Add(Limb, FMars_Health_Spec(k_LimbMaxHealth));

            auto LimbSpec = utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Limb, k_CrushMultiplier);
            LimbSpec.Root = InHandle;
            utils_hit_zone::Add(Limb, LimbSpec);
        }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}
