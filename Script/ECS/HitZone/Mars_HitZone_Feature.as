//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HitZoneHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_HitZone";
    RequiredFragments.Add(FMars_Feature_HitZone);
    Description = "A damageable zone: a zone tag, a damage-type reaction table, the Health it feeds and the hurtbox probes that link back to it";
}

struct FMars_Feature_HitZone {}

//--------------------------------------------------------------------------------------------------------------------------
// Reactions
//--------------------------------------------------------------------------------------------------------------------------

// What a hit of a reaction's damage type does to a part's condition (the BodyPart ledger reads it from OnHit).
enum EMars_HitZone_ConditionImpact
{
    None,
    // Pristine -> Damaged.
    Damages,
    // Accumulates toward the part's ruin threshold (crushing ruins soft parts).
    Ruins
}

// One row of a zone's reaction table: hits of DamageType are scaled by Multiplier.
struct FMars_HitZone_Reaction
{
    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType;

    UPROPERTY()
    float32 Multiplier = 1.0f;

    UPROPERTY()
    EMars_HitZone_ConditionImpact Impact = EMars_HitZone_ConditionImpact::Damages;

    FMars_HitZone_Reaction() {}

    FMars_HitZone_Reaction(FGameplayTag InDamageType, float32 InMultiplier, EMars_HitZone_ConditionImpact InImpact)
    {
        DamageType = InDamageType;
        Multiplier = InMultiplier;
        Impact = InImpact;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The zone always feeds the Health on its own entity (utils_health::Add first).
struct FMars_HitZone_Spec
{
    // HitZone.Mars.{Body, Limb}.
    UPROPERTY(meta = (Categories = "HitZone"))
    FGameplayTag ZoneTag;

    // First row naming a hit's damage type wins.
    UPROPERTY()
    TArray<FMars_HitZone_Reaction> Reactions;

    // Damage types with no row: scaled by this, with no condition impact.
    UPROPERTY()
    float32 DefaultMultiplier = 1.0f;

    FMars_HitZone_Spec() {}

    FMars_HitZone_Spec(FGameplayTag InZoneTag)
    {
        ZoneTag = InZoneTag;
    }
}

mixin FMars_Validation Validate(const FMars_HitZone_Spec& Self)
{
    if (Self.ZoneTag.IsValid() == false)
    { return FMars_Validation("HitZone has no ZoneTag"); }

    if (Self.DefaultMultiplier < 0.0f)
    { return FMars_Validation(f"HitZone has a negative DefaultMultiplier [{Self.DefaultMultiplier}]"); }

    for (int32 Index = 0; Index < Self.Reactions.Num(); ++Index)
    {
        const auto& Reaction = Self.Reactions[Index];
        if (Reaction.DamageType.IsValid() == false)
        { return FMars_Validation(f"HitZone reaction [{Index}] has no DamageType"); }

        if (Reaction.Multiplier < 0.0f)
        { return FMars_Validation(f"HitZone reaction [{Index}] has a negative Multiplier [{Reaction.Multiplier}]"); }
    }

    return FMars_Validation();
}

// A box hurtbox: a Probe.Mars.HitZone probe on a scene node under the transform it rides.
struct FMars_HitZone_Hurtbox
{
    UPROPERTY()
    FVector HalfExtents = FVector(20.0, 20.0, 20.0);

    UPROPERTY()
    FTransform LocalOffset = FTransform::Identity;

    FMars_HitZone_Hurtbox() {}

    FMars_HitZone_Hurtbox(FVector InHalfExtents, FTransform InLocalOffset)
    {
        HalfExtents = InHalfExtents;
        LocalOffset = InLocalOffset;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_HitZone_Params
{
    UPROPERTY()
    FMars_HitZone_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_HitZone_HandleRequests, Add and AddHurtbox_Box (composition).
struct FMars_Fragment_HitZone
{
    // The zone entity's own Health.
    UPROPERTY()
    FCk_Handle_Health Health;

    // Hurtbox node entities (each carries FMars_Fragment_HitZone_Link back to this zone).
    UPROPERTY()
    TArray<FCk_Handle> Hurtboxes;

    UPROPERTY()
    bool IsEnabled = true;

    // Hits routed while enabled.
    UPROPERTY()
    int32 HitCount = 0;
}

// Lives on every hurtbox node: a swept probe entity resolves to its zone through it (utils_hit_zone::TryGet_Zone).
struct FMars_Fragment_HitZone_Link
{
    UPROPERTY()
    FCk_Handle_HitZone Zone;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// One broadcast per routed hit, before it reaches the Health. InScaledEvent carries the multiplied Amount and HitZone =
// this zone; InReaction is the row that applied (DefaultMultiplier and Impact None when no row names the type).
delegate void FMars_Delegate_HitZone_OnHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction);
event void FMars_Delegate_HitZone_OnHit_MC(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction);

struct FMars_Fragment_HitZone_Signals
{
    FMars_Delegate_HitZone_OnHit_MC OnHit;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// A disabled zone ignores hits (and dealers reject them as ZoneDisabled).
struct FMars_Request_HitZone_SetEnabled
{
    UPROPERTY()
    ECk_EnableDisable EnableDisable = ECk_EnableDisable::Enable;

    FMars_Request_HitZone_SetEnabled() {}

    FMars_Request_HitZone_SetEnabled(ECk_EnableDisable InEnableDisable)
    {
        EnableDisable = InEnableDisable;
    }
}

// Destroys every hurtbox node (a severed limb's segments must lose their probes before they ragdoll).
struct FMars_Request_HitZone_ReleaseHurtboxes
{
    // AngelScript rejects a TArray of an empty struct.
    UPROPERTY()
    bool Requested = true;
}

struct FMars_Request_HitZone_Hit
{
    UPROPERTY()
    FMars_DamageEvent Event;

    FMars_Request_HitZone_Hit() {}

    FMars_Request_HitZone_Hit(FMars_DamageEvent InEvent)
    {
        Event = InEvent;
    }
}

// Applied SetEnabled -> ReleaseHurtboxes -> Hit, each kind in arrival order: a disable in the same drain already covers
// that drain's hits.
struct FMars_Fragment_HitZone_Requests
{
    UPROPERTY()
    TArray<FMars_Request_HitZone_SetEnabled> SetEnabledRequests;

    UPROPERTY()
    TArray<FMars_Request_HitZone_ReleaseHurtboxes> ReleaseHurtboxesRequests;

    UPROPERTY()
    TArray<FMars_Request_HitZone_Hit> HitRequests;
}
