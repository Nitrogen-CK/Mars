//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_DamageDealerHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_DamageDealer";
    RequiredFragments.Add(FMars_Feature_DamageDealer);
    Description = "The attacker side of damage: resolves a hit probe to its zone, applies the team attitude gate and scale, and forwards the hit";
}

struct FMars_Feature_DamageDealer {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_DamageDealer_RejectReason
{
    // The hit entity is neither a zone nor a hurtbox linked to a live zone.
    NoHitZone,
    // The zone's team is the dealer's (or the zone is the dealer itself) and the dealer disallows friendly fire.
    Friendly,
    ZoneDisabled
}

// What the dealer does with a hit on a zone of its own team (or on itself).
enum EMars_DamageDealer_FriendlyFire
{
    Reject,
    Allow
}

struct FMars_DamageDealer_Spec
{
    // Multiplies every dealt event's Amount.
    UPROPERTY()
    float32 DamageScale = 1.0f;

    UPROPERTY()
    EMars_DamageDealer_FriendlyFire FriendlyFire = EMars_DamageDealer_FriendlyFire::Reject;

    FMars_DamageDealer_Spec() {}

    FMars_DamageDealer_Spec(float32 InDamageScale)
    {
        DamageScale = InDamageScale;
    }

    FMars_DamageDealer_Spec(float32 InDamageScale, EMars_DamageDealer_FriendlyFire InFriendlyFire)
    {
        DamageScale = InDamageScale;
        FriendlyFire = InFriendlyFire;
    }
}

// A melee swing's sphere sweep (utils_damage_dealer::Try_StrikeSweep), world space.
struct FMars_DamageDealer_Sweep
{
    UPROPERTY()
    FVector Start;

    UPROPERTY()
    FVector End;

    UPROPERTY()
    float32 Radius = 25.0f;

    FMars_DamageDealer_Sweep() {}

    FMars_DamageDealer_Sweep(FVector InStart, FVector InEnd, float32 InRadius)
    {
        Start = InStart;
        End = InEnd;
        Radius = InRadius;
    }
}

mixin FMars_Validation Validate(const FMars_DamageDealer_Spec& Self)
{
    if (Self.DamageScale < 0.0f)
    { return FMars_Validation(f"DamageDealer has a negative DamageScale [{Self.DamageScale}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_DamageDealer_Params
{
    UPROPERTY()
    FMars_DamageDealer_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_DamageDealer_HandleRequests (and composed by Add).
struct FMars_Fragment_DamageDealer
{
    UPROPERTY()
    int32 HitsDealt = 0;

    UPROPERTY()
    int32 HitsRejected = 0;

    // The last forwarded (scaled) event; unset until a hit is dealt.
    UPROPERTY()
    TOptional<FMars_DamageEvent> LastDealt;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// The hit was forwarded to InZone (InEvent is scaled by the dealer's DamageScale; the zone scales it again).
delegate void FMars_Delegate_DamageDealer_OnDamageDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent);
event void FMars_Delegate_DamageDealer_OnDamageDealt_MC(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent);

delegate void FMars_Delegate_DamageDealer_OnDamageRejected(FCk_Handle_DamageDealer InDealer, FCk_Handle InHitEntity, EMars_DamageDealer_RejectReason InReason);
event void FMars_Delegate_DamageDealer_OnDamageRejected_MC(FCk_Handle_DamageDealer InDealer, FCk_Handle InHitEntity, EMars_DamageDealer_RejectReason InReason);

struct FMars_Fragment_DamageDealer_Signals
{
    FMars_Delegate_DamageDealer_OnDamageDealt_MC OnDamageDealt;
    FMars_Delegate_DamageDealer_OnDamageRejected_MC OnDamageRejected;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// HitEntity is what the sweep hit (a hurtbox node, or a zone entity itself); the dealer resolves it to the zone, so the
// zone - not a context root - is the hit's identity.
struct FMars_Request_DamageDealer_DealDamage
{
    UPROPERTY()
    FCk_Handle HitEntity;

    UPROPERTY()
    FMars_DamageEvent Event;

    FMars_Request_DamageDealer_DealDamage() {}

    FMars_Request_DamageDealer_DealDamage(FCk_Handle InHitEntity, FMars_DamageEvent InEvent)
    {
        HitEntity = InHitEntity;
        Event = InEvent;
    }
}

// Applied in arrival order, each resolved, gated and forwarded on its own.
struct FMars_Fragment_DamageDealer_Requests
{
    UPROPERTY()
    TArray<FMars_Request_DamageDealer_DealDamage> DealDamageRequests;
}
