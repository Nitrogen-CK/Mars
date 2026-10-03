//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HealthHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Health";
    RequiredFragments.Add(FMars_Feature_Health);
    Description = "An entity with hit points: a clamped float attribute, damage and heal requests drained by one processor, per-request signals and a once-only depletion";
}

struct FMars_Feature_Health {}

//--------------------------------------------------------------------------------------------------------------------------
// Damage Event
//--------------------------------------------------------------------------------------------------------------------------

// One hit, as every combat feature passes it along: the dealer stamps who and what, the zone stamps itself, and Health
// records the one that lands as LastHit.
struct FMars_DamageEvent
{
    UPROPERTY()
    float32 Amount = 0.0f;

    // DamageType.Mars.{Sever, Crush, Blunt}.
    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType;

    // Who dealt it (the player entity).
    UPROPERTY()
    FCk_Handle Instigator;

    // What dealt it (the item or hazard entity).
    UPROPERTY()
    FCk_Handle Causer;

    UPROPERTY()
    FVector HitLocation = FVector::ZeroVector;

    UPROPERTY()
    FVector HitNormal = FVector::UpVector;

    // Debris push; zero = none.
    UPROPERTY()
    FVector Impulse = FVector::ZeroVector;

    // Stamped by the zone that routed the hit; invalid for damage applied straight to a Health.
    UPROPERTY()
    FCk_Handle HitZone;

    FMars_DamageEvent() {}

    FMars_DamageEvent(float32 InAmount, FGameplayTag InDamageType)
    {
        Amount = InAmount;
        DamageType = InDamageType;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Field order is the positional constructor's order.
struct FMars_Health_Spec
{
    UPROPERTY()
    float32 Max = 100.0f;

    // <= 0 starts at Max.
    UPROPERTY()
    float32 Start = 0.0f;

    UPROPERTY()
    bool StartInvulnerable = false;

    FMars_Health_Spec() {}

    FMars_Health_Spec(float32 InMax)
    {
        Max = InMax;
    }

    FMars_Health_Spec(float32 InMax, float32 InStart)
    {
        Max = InMax;
        Start = InStart;
    }

    FMars_Health_Spec(float32 InMax, float32 InStart, bool InStartInvulnerable)
    {
        Max = InMax;
        Start = InStart;
        StartInvulnerable = InStartInvulnerable;
    }
}

// A non-positive Max has no hit points to lose, and a Start above Max would be clamped on the first write.
mixin FMars_Validation Validate(const FMars_Health_Spec& Self)
{
    if (Self.Max <= 0.0f)
    { return FMars_Validation(f"Health has a non-positive Max [{Self.Max}]"); }

    if (Self.Start > Self.Max)
    { return FMars_Validation(f"Health has Start [{Self.Start}] above Max [{Self.Max}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Health_Params
{
    UPROPERTY()
    FMars_Health_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_Health_HandleRequests (and composed by Add). The hit points themselves live in the
// attribute; IsDepleted is latched here, not derived from the attribute, so it flips exactly once per depletion.
struct FMars_Fragment_Health
{
    // FloatAttribute.Mars.Health, MinMax 0..Spec.Max.
    UPROPERTY()
    FCk_Handle_FloatAttribute Attribute;

    UPROPERTY()
    bool IsInvulnerable = false;

    UPROPERTY()
    bool IsDepleted = false;

    // The last hit that applied damage; meaningful only when HasLastHit.
    UPROPERTY()
    FMars_DamageEvent LastHit;

    UPROPERTY()
    bool HasLastHit = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// One broadcast per applied request (never coalesced, unlike the attribute's own signals). InApplied is what the hit
// actually removed (clamped to the remaining hit points); InRemaining is the value after it.
delegate void FMars_Delegate_Health_OnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining);
event void FMars_Delegate_Health_OnDamaged_MC(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining);

// InApplied is what the heal actually added (clamped to Max).
delegate void FMars_Delegate_Health_OnHealed(FCk_Handle_Health InHealth, float32 InApplied, float32 InRemaining);
event void FMars_Delegate_Health_OnHealed_MC(FCk_Handle_Health InHealth, float32 InApplied, float32 InRemaining);

// Once per depletion, carrying the hit that crossed zero; IsDepleted is already true when it fires.
delegate void FMars_Delegate_Health_OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause);
event void FMars_Delegate_Health_OnDepleted_MC(FCk_Handle_Health InHealth, FMars_DamageEvent InCause);

struct FMars_Fragment_Health_Signals
{
    FMars_Delegate_Health_OnDamaged_MC OnDamaged;
    FMars_Delegate_Health_OnHealed_MC OnHealed;
    FMars_Delegate_Health_OnDepleted_MC OnDepleted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Health_SetInvulnerable
{
    UPROPERTY()
    bool Invulnerable = true;

    FMars_Request_Health_SetInvulnerable() {}

    FMars_Request_Health_SetInvulnerable(bool InInvulnerable)
    {
        Invulnerable = InInvulnerable;
    }
}

// A positive heal on a depleted Health revives it (IsDepleted clears, so a later lethal hit depletes it again). A heal
// of <= 0 is ignored.
struct FMars_Request_Health_Heal
{
    UPROPERTY()
    float32 Amount = 0.0f;

    FMars_Request_Health_Heal() {}

    FMars_Request_Health_Heal(float32 InAmount)
    {
        Amount = InAmount;
    }
}

// Ignored while invulnerable or depleted, and when Event.Amount <= 0.
struct FMars_Request_Health_ApplyDamage
{
    UPROPERTY()
    FMars_DamageEvent Event;

    FMars_Request_Health_ApplyDamage() {}

    FMars_Request_Health_ApplyDamage(FMars_DamageEvent InEvent)
    {
        Event = InEvent;
    }
}

// Applied SetInvulnerable -> Heal -> ApplyDamage, each kind in arrival order, against one running value: two lethal hits
// in one drain deplete once (the second is clamped to the remainder), and an invulnerability toggle in the same drain
// already covers that drain's hits.
struct FMars_Fragment_Health_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Health_SetInvulnerable> SetInvulnerableRequests;

    UPROPERTY()
    TArray<FMars_Request_Health_Heal> HealRequests;

    UPROPERTY()
    TArray<FMars_Request_Health_ApplyDamage> ApplyDamageRequests;
}
