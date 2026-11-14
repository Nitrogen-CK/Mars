// A harness probe, not a creature: the smallest replicated monster, for the monster net tests. The server spawns it under
// utils_mars_net::Get_ReplicatedSpawnOwner; every machine composes its own monster on the root (the body Health and a
// flesh body zone with one box hurtbox) and, when asked, Break parts, each on its own scene node under the root with one
// box hurtbox.

// The spawn params, by the script's ExposeOnSpawn names, so no call site waits for the generated ones.
struct FMars_NetCombat_Monster_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    float32 BodyHealth = 100.0f;

    UPROPERTY()
    int32 PartCount = 0;

    UPROPERTY()
    float32 PartHealth = 30.0f;

    UPROPERTY()
    float32 PartSpill = 0.0f;

    FMars_NetCombat_Monster_SpawnParams() {}

    FMars_NetCombat_Monster_SpawnParams(FTransform InSpawnTransform, int32 InPartCount)
    {
        SpawnTransform = InSpawnTransform;
        PartCount = InPartCount;
    }
}

class UMars_NetCombat_Monster_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity, its transform, its body Health ledger and its
    // monster ledger replicate. The parts are each machine's own composition.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    float32 BodyHealth = 100.0f;

    UPROPERTY(ExposeOnSpawn)
    int32 PartCount = 0;

    UPROPERTY(ExposeOnSpawn)
    float32 PartHealth = 30.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 PartSpill = 0.0f;

    private const float32 k_CorpseSeconds = 8.0f;
    private const float64 k_PartSpacingCm = 80.0;
    private const FVector k_BodyHurtboxHalfExtents = FVector(40.0, 40.0, 40.0);
    private const FVector k_PartHurtboxHalfExtents = FVector(20.0, 20.0, 20.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetMonster");

        auto Monster = utils_monster::Add(InHandle, FMars_Monster_Spec(GameplayTags::Monster_Mars_Crawler, FMars_Health_Spec(BodyHealth),
            utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f), k_CorpseSeconds, ECk_Team_ID::Two));
        if (ck::Is_NOT_Valid(Monster))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto BodyZone = Monster.Get_BodyZone();
        utils_hit_zone::AddHurtbox_Box(BodyZone, Root, FMars_HitZone_Hurtbox(k_BodyHurtboxHalfExtents, FTransform::Identity));

        for (int32 Index = 0; Index < PartCount; ++Index)
        { Add_Part(Root, Monster, Index); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void Add_Part(FCk_Handle_Transform& InRoot, FCk_Handle_Monster InMonster, int32 InIndex)
    {
        auto Node = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, k_PartSpacingCm * (InIndex + 1), 0.0)));

        auto Zone = FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Limb);
        Zone.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Sever, 1.0f, EMars_HitZone_ConditionImpact::Damages));
        auto Spec = FMars_BodyPart_Spec(GameplayTags::BodyPart_Mars_Crawler_Leg, EMars_BodyPart_Function::Attack, FMars_Health_Spec(PartHealth),
            Zone, FMars_BodyPart_Severance(EMars_BodyPart_DepletionPolicy::Break, PartSpill, 0.5f, FMars_BodyPart_Debris()));
        Spec.Monster = InMonster;

        FCk_Handle PartEntity = Node;
        auto Part = utils_body_part::Add(PartEntity, Spec);
        if (ck::Is_NOT_Valid(Part))
        { return; }

        auto PartZone = Part.Get_Zone();
        auto NodeTransform = Node.As_Transform();
        utils_hit_zone::AddHurtbox_Box(PartZone, NodeTransform, FMars_HitZone_Hurtbox(k_PartHurtboxHalfExtents, FTransform::Identity));
    }
}
