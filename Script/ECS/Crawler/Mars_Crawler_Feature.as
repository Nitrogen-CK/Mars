//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_CrawlerHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Crawler";
    RequiredFragments.Add(FMars_Feature_Crawler);
    Description = "The legged crawler archetype: a procedural walker, one body part per leg with hurtboxes, a monster root, a navigator and a brain";
}

struct FMars_Feature_Crawler {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// What the crawler's body and legs are made of. Field order is the positional constructor's order.
struct FMars_Crawler_Vitals
{
    UPROPERTY()
    float32 BodyHealth = 120.0f;

    // Each leg's own Health.
    UPROPERTY()
    float32 LegHealth = 30.0f;

    // Fraction of every leg hit that also lands on the body, [0, 1].
    UPROPERTY()
    float32 SpillToBody = 0.5f;

    // How a severed leg's segments fall and how long they stay.
    UPROPERTY()
    FMars_BodyPart_Debris LegDebris;

    // From death to despawn: the Dead state's corpse timer (the monster's CorpseSeconds).
    UPROPERTY()
    float32 CorpseSeconds = 8.0f;

    FMars_Crawler_Vitals() {}

    FMars_Crawler_Vitals(float32 InBodyHealth, float32 InLegHealth, float32 InSpillToBody)
    {
        BodyHealth = InBodyHealth;
        LegHealth = InLegHealth;
        SpillToBody = InSpillToBody;
    }
}

// One leg's rigid parts. Field order is the positional constructor's order.
struct FMars_Crawler_LegRig
{
    // The rig asset's leg id (Leg0..).
    UPROPERTY()
    FName LegId;

    // Hip-first; each a direct lifetime child of the crawler root, unit scale, geometry centred, +X along the segment.
    UPROPERTY()
    TArray<FCk_Handle_Transform> Segments;

    UPROPERTY()
    FCk_Handle_Transform Foot;

    // One per segment in chain order, the foot last: hurtbox and debris box half extents.
    UPROPERTY()
    TArray<FVector> SegmentHalfExtents;

    FMars_Crawler_LegRig() {}

    FMars_Crawler_LegRig(FName InLegId, TArray<FCk_Handle_Transform> InSegments, FCk_Handle_Transform InFoot, TArray<FVector> InSegmentHalfExtents)
    {
        LegId = InLegId;
        Segments = InSegments;
        Foot = InFoot;
        SegmentHalfExtents = InSegmentHalfExtents;
    }
}

struct FMars_Crawler_Rig
{
    // The body pose's target and the body visual's parent: a direct lifetime child of the root, not a rig part.
    UPROPERTY()
    FCk_Handle_Transform Presentation;

    // The body visual's half extents; also the body hurtbox's.
    UPROPERTY()
    FVector BodyHalfExtents = FVector(40.0, 30.0, 15.0);

    // In the rig asset's leg order.
    UPROPERTY()
    TArray<FMars_Crawler_LegRig> Legs;
}

mixin FMars_Validation Validate(const FMars_Crawler_Rig& Self, int32 InLegCount)
{
    if (ck::Is_NOT_Valid(Self.Presentation))
    { return FMars_Validation("Crawler rig has no Presentation"); }

    if (Self.Legs.Num() != InLegCount)
    { return FMars_Validation(f"Crawler rig has [{Self.Legs.Num()}] legs for a LegCount of [{InLegCount}]"); }

    for (int32 Index = 0; Index < Self.Legs.Num(); ++Index)
    {
        const auto& Leg = Self.Legs[Index];
        if (Leg.Segments.Num() == 0 || ck::Is_NOT_Valid(Leg.Foot))
        { return FMars_Validation(f"Crawler rig leg [{Index}] has no segments or no foot"); }

        if (Leg.SegmentHalfExtents.Num() != Leg.Segments.Num() + 1)
        { return FMars_Validation(f"Crawler rig leg [{Index}] has [{Leg.SegmentHalfExtents.Num()}] half extents for [{Leg.Segments.Num()}] segments and a foot"); }
    }

    return FMars_Validation();
}

// Field order is the positional constructor's order.
struct FMars_Crawler_Spec
{
    // 4 or 6.
    UPROPERTY()
    int32 LegCount = 4;

    // World-space box the Roam task picks goals in. The entity script defaults an unset box to +-400 around the spawn.
    UPROPERTY()
    FBox RoamBounds;

    UPROPERTY()
    float32 RoamDwellSeconds = 1.5f;

    UPROPERTY()
    float32 FlinchSeconds = 0.6f;

    // Enabled legs needed to walk (the brain's CanWalk fact); fewer and the crawler cowers. [2, LegCount].
    UPROPERTY()
    int32 MinLegsToWalk = 3;

    UPROPERTY()
    FMars_Crawler_Vitals Vitals;

    // The transform entities the walker poses, built by the entity script with its visuals (features own no visuals).
    UPROPERTY()
    FMars_Crawler_Rig Rig;

    FMars_Crawler_Spec() {}

    FMars_Crawler_Spec(int32 InLegCount, FBox InRoamBounds)
    {
        LegCount = InLegCount;
        RoamBounds = InRoamBounds;
    }
}

mixin FMars_Validation Validate(const FMars_Crawler_Spec& Self)
{
    if (Self.LegCount != 4 && Self.LegCount != 6)
    { return FMars_Validation(f"Crawler has LegCount [{Self.LegCount}]; only 4 and 6 have rigs"); }

    if (Self.MinLegsToWalk < 2 || Self.MinLegsToWalk > Self.LegCount)
    { return FMars_Validation(f"Crawler has MinLegsToWalk [{Self.MinLegsToWalk}] outside [2, {Self.LegCount}]"); }

    if (Self.RoamBounds.Max.X <= Self.RoamBounds.Min.X || Self.RoamBounds.Max.Y <= Self.RoamBounds.Min.Y ||
        Self.RoamBounds.Max.Z < Self.RoamBounds.Min.Z)
    { return FMars_Validation(f"Crawler has empty RoamBounds [{Self.RoamBounds.Min.ToString()} .. {Self.RoamBounds.Max.ToString()}]"); }

    if (Self.RoamDwellSeconds <= 0.0f || Self.FlinchSeconds <= 0.0f)
    { return FMars_Validation(f"Crawler has a non-positive RoamDwellSeconds [{Self.RoamDwellSeconds}] or FlinchSeconds [{Self.FlinchSeconds}]"); }

    const auto& Vitals = Self.Vitals;
    if (Vitals.BodyHealth <= 0.0f || Vitals.LegHealth <= 0.0f)
    { return FMars_Validation(f"Crawler has a non-positive BodyHealth [{Vitals.BodyHealth}] or LegHealth [{Vitals.LegHealth}]"); }

    if (Vitals.SpillToBody < 0.0f || Vitals.SpillToBody > 1.0f)
    { return FMars_Validation(f"Crawler has SpillToBody [{Vitals.SpillToBody}] outside [0, 1]"); }

    if (Vitals.CorpseSeconds < 0.0f)
    { return FMars_Validation(f"Crawler has a negative CorpseSeconds [{Vitals.CorpseSeconds}]"); }

    const auto RigValidation = Self.Rig.Validate(Self.LegCount);
    if (RigValidation.IsValid == false)
    { return RigValidation; }

    return Vitals.LegDebris.Validate();
}

//--------------------------------------------------------------------------------------------------------------------------
// Rig (built by the entity script, which owns the visuals)
//--------------------------------------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Crawler_Params
{
    UPROPERTY()
    FMars_Crawler_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Composed by Add; nothing writes it afterwards (the walker's legs, the parts, the navigator and the brain on the same
// root keep their own state).
struct FMars_Fragment_Crawler
{
    UPROPERTY()
    FCk_Handle_SurfaceMotion Motion;

    UPROPERTY()
    FCk_Handle_ProceduralGait Gait;

    UPROPERTY()
    FCk_Handle_ProceduralBodyPose BodyPose;

    UPROPERTY()
    FCk_Handle_Transform Presentation;

    // In the rig asset's leg order; LegParts[i] is Legs[i] (the leg entity carries the part).
    UPROPERTY()
    TArray<FCk_Handle_ProceduralLeg> Legs;

    UPROPERTY()
    TArray<FCk_Handle_BodyPart> LegParts;

    // On the root (the motion's entity): goal -> path -> steering.
    UPROPERTY()
    FCk_Handle_SurfaceNavigator Navigator;
}

struct FMars_Tag_Crawler_NeedsSetup {}
