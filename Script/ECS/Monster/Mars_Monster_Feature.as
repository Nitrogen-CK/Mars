//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_MonsterHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Monster";
    RequiredFragments.Add(FMars_Feature_Monster);
    Description = "A creature root: team, body Health and zone, the parts roster, the Dead attribute and the death request";
}

struct FMars_Feature_Monster {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Monster_Spec
{
    // Monster.Mars.*
    UPROPERTY(meta = (Categories = "Monster"))
    FGameplayTag MonsterTag;

    UPROPERTY()
    FMars_Health_Spec BodyHealth;

    // Composed on the root beside the body Health, which it feeds.
    UPROPERTY()
    FMars_HitZone_Spec BodyZone;

    // Between death and despawn (the Dead state's corpse timer).
    UPROPERTY()
    float32 CorpseSeconds = 8.0f;

    UPROPERTY()
    ECk_Team_ID Team = ECk_Team_ID::Two;

    FMars_Monster_Spec() {}

    FMars_Monster_Spec(FGameplayTag InMonsterTag, FMars_Health_Spec InBodyHealth, FMars_HitZone_Spec InBodyZone,
                       float32 InCorpseSeconds, ECk_Team_ID InTeam)
    {
        MonsterTag = InMonsterTag;
        BodyHealth = InBodyHealth;
        BodyZone = InBodyZone;
        CorpseSeconds = InCorpseSeconds;
        Team = InTeam;
    }
}

mixin FMars_Validation Validate(const FMars_Monster_Spec& Self)
{
    if (Self.MonsterTag.IsValid() == false)
    { return FMars_Validation("Monster has no MonsterTag"); }

    const auto HealthValidation = Self.BodyHealth.Validate();
    if (HealthValidation.IsValid() == false)
    { return HealthValidation; }

    const auto ZoneValidation = Self.BodyZone.Validate();
    if (ZoneValidation.IsValid() == false)
    { return ZoneValidation; }

    if (Self.CorpseSeconds < 0.0f)
    { return FMars_Validation(f"Monster has a negative CorpseSeconds [{Self.CorpseSeconds}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Monster_Params
{
    UPROPERTY()
    FMars_Monster_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_Monster_HandleRequests (and composed by Add). The roster is never pruned: a severed part
// stays listed, valid until its debris timer destroys it and invalid after. Readers count attached parts by the part's
// State and check validity before any read.
struct FMars_Fragment_Monster
{
    UPROPERTY()
    FCk_Handle_Health BodyHealth;

    UPROPERTY()
    FCk_Handle_HitZone BodyZone;

    // ByteAttribute.Mars.Monster.Dead (0 alive, 1 dead); the HFSM's Alive -> Dead condition reads it.
    UPROPERTY()
    FCk_Handle_ByteAttribute Dead;

    UPROPERTY()
    TArray<FCk_Handle_BodyPart> Parts;

    // Latched by the first Die: the monster is dead once it is set.
    UPROPERTY()
    TOptional<FMars_DamageEvent> DeathCause;
}

struct FMars_Tag_Monster_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Monster_OnPartRegistered(FCk_Handle_Monster InMonster, FCk_Handle_BodyPart InPart);
event void FMars_Delegate_Monster_OnPartRegistered_MC(FCk_Handle_Monster InMonster, FCk_Handle_BodyPart InPart);

// The fan-in of every registered part's OnSevered.
delegate void FMars_Delegate_Monster_OnPartSevered(FCk_Handle_Monster InMonster, FCk_Handle_BodyPart InPart);
event void FMars_Delegate_Monster_OnPartSevered_MC(FCk_Handle_Monster InMonster, FCk_Handle_BodyPart InPart);

// Once per monster; DeathCause and the Dead attribute request are already in place when it fires.
delegate void FMars_Delegate_Monster_OnDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause);
event void FMars_Delegate_Monster_OnDied_MC(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause);

struct FMars_Fragment_Monster_Signals
{
    FMars_Delegate_Monster_OnPartRegistered_MC OnPartRegistered;
    FMars_Delegate_Monster_OnPartSevered_MC OnPartSevered;
    FMars_Delegate_Monster_OnDied_MC OnDied;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Queued by utils_body_part::Add.
struct FMars_Request_Monster_RegisterPart
{
    UPROPERTY()
    FCk_Handle_BodyPart Part;

    FMars_Request_Monster_RegisterPart() {}

    FMars_Request_Monster_RegisterPart(FCk_Handle_BodyPart InPart)
    {
        Part = InPart;
    }
}

// Latched: only the first Die does anything. The setup processor requests it on the body Health's OnDepleted.
struct FMars_Request_Monster_Die
{
    UPROPERTY()
    FMars_DamageEvent Cause;

    FMars_Request_Monster_Die() {}

    FMars_Request_Monster_Die(FMars_DamageEvent InCause)
    {
        Cause = InCause;
    }
}

// Applied RegisterPart -> Die, each kind in arrival order: a part registered in the death frame is on the roster the Dead
// state sheds.
struct FMars_Fragment_Monster_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Monster_RegisterPart> RegisterPartRequests;

    UPROPERTY()
    TArray<FMars_Request_Monster_Die> DieRequests;
}
