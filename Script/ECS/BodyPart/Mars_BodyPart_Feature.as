//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_BodyPartHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_BodyPart";
    RequiredFragments.Add(FMars_Feature_BodyPart);
    Description = "A monster part with its own Health and HitZone, a condition ledger, spill to the body, and a depletion policy (detach a leg, break, none)";
}

struct FMars_Feature_BodyPart {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// What the part does for its creature (read by behaviour, not by this feature).
enum EMars_BodyPart_Function
{
    Movement,
    Attack,
    Armor,
    Sensory,
    Support,
    Core
}

// Only ever moves forward: Pristine -> Damaged -> Ruined.
enum EMars_BodyPart_Condition
{
    Pristine,
    Damaged,
    Ruined
}

// What depletion of the part's Health does.
enum EMars_BodyPart_DepletionPolicy
{
    None,
    // The zone is disabled and OnBroken fires; the entity stays as it is.
    Break,
    // The part entity is a procedural leg: it is detached from its body, its released segments ragdoll as debris and
    // the severed limb (the leg and its parts) is destroyed by one timer on the leg.
    DetachLeg
}

enum EMars_BodyPart_State
{
    Attached,
    Severed,
    Broken
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// How a severed limb's released parts fall.
struct FMars_BodyPart_Debris
{
    UPROPERTY()
    float32 MassKg = 2.0f;

    // Horizontal push away from the body, cm/s.
    UPROPERTY()
    float32 OutwardSpeed = 250.0f;

    UPROPERTY()
    float32 UpSpeed = 150.0f;

    // From the sever to the destruction of the severed limb.
    UPROPERTY()
    float32 LifetimeSeconds = 8.0f;

    // A profile the gait's and surface motion's Visibility probes do not trace, so debris never reads as ground.
    UPROPERTY()
    FName CollisionProfile = n"Ragdoll";

    FMars_BodyPart_Debris() {}

    FMars_BodyPart_Debris(float32 InMassKg, float32 InOutwardSpeed, float32 InUpSpeed, float32 InLifetimeSeconds)
    {
        MassKg = InMassKg;
        OutwardSpeed = InOutwardSpeed;
        UpSpeed = InUpSpeed;
        LifetimeSeconds = InLifetimeSeconds;
    }
}

mixin FMars_Validation Validate(const FMars_BodyPart_Debris& Self)
{
    if (Self.MassKg <= 0.0f)
    { return FMars_Validation(f"BodyPart debris has a non-positive MassKg [{Self.MassKg}]"); }

    if (Self.LifetimeSeconds <= 0.0f)
    { return FMars_Validation(f"BodyPart debris has a non-positive LifetimeSeconds [{Self.LifetimeSeconds}]"); }

    if (Self.OutwardSpeed < 0.0f || Self.UpSpeed < 0.0f)
    { return FMars_Validation(f"BodyPart debris has a negative speed [{Self.OutwardSpeed}, {Self.UpSpeed}]"); }

    if (Self.CollisionProfile.IsNone())
    { return FMars_Validation("BodyPart debris has no CollisionProfile"); }

    return FMars_Validation();
}

struct FMars_BodyPart_Severance
{
    UPROPERTY()
    EMars_BodyPart_DepletionPolicy OnDepleted = EMars_BodyPart_DepletionPolicy::None;

    // Fraction of every hit on the part that also lands on the monster's body Health, [0, 1].
    UPROPERTY()
    float32 SpillToBody = 0.5f;

    // Ruins-impact damage (scaled, as the part took it) at RuinThreshold x Health.Max ruins the part, (0, 1].
    UPROPERTY()
    float32 RuinThreshold = 0.5f;

    UPROPERTY()
    FMars_BodyPart_Debris Debris;

    FMars_BodyPart_Severance() {}

    FMars_BodyPart_Severance(EMars_BodyPart_DepletionPolicy InOnDepleted, float32 InSpillToBody, float32 InRuinThreshold, FMars_BodyPart_Debris InDebris)
    {
        OnDepleted = InOnDepleted;
        SpillToBody = InSpillToBody;
        RuinThreshold = InRuinThreshold;
        Debris = InDebris;
    }
}

struct FMars_BodyPart_Spec
{
    // BodyPart.Mars.*; a leg's id is its FName, not a tag.
    UPROPERTY(meta = (Categories = "BodyPart"))
    FGameplayTag PartTag;

    UPROPERTY()
    EMars_BodyPart_Function Function = EMars_BodyPart_Function::Movement;

    UPROPERTY()
    FMars_Health_Spec Health;

    // Composed on the part entity beside the part's Health, which it feeds.
    UPROPERTY()
    FMars_HitZone_Spec Zone;

    UPROPERTY()
    FMars_BodyPart_Severance Severance;

    // The creature the part registers on and spills into.
    UPROPERTY()
    FCk_Handle_Monster Monster;

    // DetachLeg only: debris box half extents of the leg's released parts, one per segment in chain order, the foot last.
    UPROPERTY()
    TArray<FVector> SegmentHalfExtents;

    FMars_BodyPart_Spec() {}

    FMars_BodyPart_Spec(FGameplayTag InPartTag, EMars_BodyPart_Function InFunction, FMars_Health_Spec InHealth,
                        FMars_HitZone_Spec InZone, FMars_BodyPart_Severance InSeverance)
    {
        PartTag = InPartTag;
        Function = InFunction;
        Health = InHealth;
        Zone = InZone;
        Severance = InSeverance;
    }
}

mixin FMars_Validation Validate(const FMars_BodyPart_Spec& Self)
{
    if (Self.PartTag.IsValid() == false)
    { return FMars_Validation("BodyPart has no PartTag"); }

    const auto HealthValidation = Self.Health.Validate();
    if (HealthValidation.IsValid() == false)
    { return HealthValidation; }

    const auto ZoneValidation = Self.Zone.Validate();
    if (ZoneValidation.IsValid() == false)
    { return ZoneValidation; }

    const auto& Severance = Self.Severance;
    if (Severance.SpillToBody < 0.0f || Severance.SpillToBody > 1.0f)
    { return FMars_Validation(f"BodyPart has SpillToBody [{Severance.SpillToBody}] outside [0, 1]"); }

    if (Severance.RuinThreshold <= 0.0f || Severance.RuinThreshold > 1.0f)
    { return FMars_Validation(f"BodyPart has RuinThreshold [{Severance.RuinThreshold}] outside (0, 1]"); }

    if (ck::Is_NOT_Valid(Self.Monster))
    { return FMars_Validation("BodyPart has no Monster to register on"); }

    if (Severance.OnDepleted == EMars_BodyPart_DepletionPolicy::DetachLeg)
    {
        if (Self.SegmentHalfExtents.Num() == 0)
        { return FMars_Validation("BodyPart is a DetachLeg part with no debris half extents"); }

        return Severance.Debris.Validate();
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_BodyPart_Params
{
    UPROPERTY()
    FMars_BodyPart_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the BodyPart processors (and composed by Add). Readers count attached parts by State, never by handle
// validity: a severed leg stays a valid, world-owned entity until its debris timer destroys it.
struct FMars_Fragment_BodyPart
{
    // The part entity as a leg; invalid for a non-leg part.
    UPROPERTY()
    FCk_Handle_ProceduralLeg Leg;

    UPROPERTY()
    FCk_Handle_Health Health;

    UPROPERTY()
    FCk_Handle_HitZone Zone;

    UPROPERTY()
    EMars_BodyPart_State State = EMars_BodyPart_State::Attached;

    UPROPERTY()
    EMars_BodyPart_Condition Condition = EMars_BodyPart_Condition::Pristine;

    // Ruins-impact damage taken so far (scaled amounts).
    UPROPERTY()
    float32 RuinDamageTaken = 0.0f;
}

// Lives between the sever drain and the leg's OnDetached callback: the cause OnSevered carries.
struct FMars_Fragment_BodyPart_PendingSever
{
    UPROPERTY()
    FMars_DamageEvent Cause;
}

// One debris body and the impulse it takes once Jolt has added it.
struct FMars_BodyPart_PendingImpulse
{
    UPROPERTY()
    FCk_Handle_JoltBody Body;

    UPROPERTY()
    FVector Impulse = FVector::ZeroVector;

    FMars_BodyPart_PendingImpulse() {}

    FMars_BodyPart_PendingImpulse(FCk_Handle_JoltBody InBody, FVector InImpulse)
    {
        Body = InBody;
        Impulse = InImpulse;
    }
}

// Debris bodies waiting for Jolt to add them; an impulse before Get_IsBodyAdded is dropped (UMars_Processor_BodyPart_Debris
// applies each once its body is in, then removes the fragment when empty).
struct FMars_Fragment_BodyPart_PendingDebris
{
    UPROPERTY()
    TArray<FMars_BodyPart_PendingImpulse> Impulses;
}

struct FMars_Tag_BodyPart_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_BodyPart_OnConditionChanged(FCk_Handle_BodyPart InPart, EMars_BodyPart_Condition InOld, EMars_BodyPart_Condition InNew);
event void FMars_Delegate_BodyPart_OnConditionChanged_MC(FCk_Handle_BodyPart InPart, EMars_BodyPart_Condition InOld, EMars_BodyPart_Condition InNew);

// Fires once, when the leg has detached and its released parts have their debris bodies; InReleased are those parts
// (segments in chain order, the foot last), lifetime children of the now world-owned leg.
delegate void FMars_Delegate_BodyPart_OnSevered(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased);
event void FMars_Delegate_BodyPart_OnSevered_MC(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased);

delegate void FMars_Delegate_BodyPart_OnBroken(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause);
event void FMars_Delegate_BodyPart_OnBroken_MC(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause);

struct FMars_Fragment_BodyPart_Signals
{
    FMars_Delegate_BodyPart_OnConditionChanged_MC OnConditionChanged;
    FMars_Delegate_BodyPart_OnSevered_MC OnSevered;
    FMars_Delegate_BodyPart_OnBroken_MC OnBroken;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// A hit the part's zone routed (the setup processor forwards the zone's OnHit): the condition ledger and the spill.
struct FMars_Request_BodyPart_RecordHit
{
    UPROPERTY()
    FMars_DamageEvent Event;

    UPROPERTY()
    FMars_HitZone_Reaction Reaction;

    FMars_Request_BodyPart_RecordHit() {}

    FMars_Request_BodyPart_RecordHit(FMars_DamageEvent InEvent, FMars_HitZone_Reaction InReaction)
    {
        Event = InEvent;
        Reaction = InReaction;
    }
}

// Applies the depletion policy (the setup processor requests it on the part's Health OnDepleted). Ignored unless Attached.
struct FMars_Request_BodyPart_Sever
{
    UPROPERTY()
    FMars_DamageEvent Cause;

    FMars_Request_BodyPart_Sever() {}

    FMars_Request_BodyPart_Sever(FMars_DamageEvent InCause)
    {
        Cause = InCause;
    }
}

// Applied RecordHit -> Sever, each kind in arrival order: the lethal hit is in the ledger before the part severs.
struct FMars_Fragment_BodyPart_Requests
{
    UPROPERTY()
    TArray<FMars_Request_BodyPart_RecordHit> RecordHitRequests;

    UPROPERTY()
    TArray<FMars_Request_BodyPart_Sever> SeverRequests;
}
