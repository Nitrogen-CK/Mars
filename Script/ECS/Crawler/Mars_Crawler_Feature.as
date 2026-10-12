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

// What the crawler's body and legs are made of.
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

// One leg's rigid parts.
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

//--------------------------------------------------------------------------------------------------------------------------
// Combat spec: the body jab (Mars_Crawler_Attack.as evaluates it)
//--------------------------------------------------------------------------------------------------------------------------

// One jab's phase lengths. CancelSeconds eases an interrupted attack back to neutral; PoseTimeoutSeconds bounds the wait
// for the body pose to publish a requested sample.
struct FMars_Crawler_AttackTiming
{
    UPROPERTY()
    float32 WindupSeconds = 0.40f;

    UPROPERTY()
    float32 StrikeSeconds = 0.12f;

    UPROPERTY()
    float32 RecoverSeconds = 0.50f;

    UPROPERTY()
    float32 CooldownSeconds = 0.70f;

    UPROPERTY()
    float32 CancelSeconds = 0.15f;

    UPROPERTY()
    float32 PoseTimeoutSeconds = 1.0f;
}

mixin FMars_Validation Validate(const FMars_Crawler_AttackTiming& Self)
{
    if (utils_crawler::Get_IsPositiveFinite(Self.WindupSeconds) == false || utils_crawler::Get_IsPositiveFinite(Self.StrikeSeconds) == false ||
        utils_crawler::Get_IsPositiveFinite(Self.RecoverSeconds) == false || utils_crawler::Get_IsPositiveFinite(Self.CooldownSeconds) == false ||
        utils_crawler::Get_IsPositiveFinite(Self.CancelSeconds) == false || utils_crawler::Get_IsPositiveFinite(Self.PoseTimeoutSeconds) == false)
    {
        return FMars_Validation(f"Crawler combat has a non-positive or non-finite duration (windup [{Self.WindupSeconds}], strike [{Self.StrikeSeconds}], recover [{Self.RecoverSeconds}], cooldown [{Self.CooldownSeconds}], cancel [{Self.CancelSeconds}], pose timeout [{Self.PoseTimeoutSeconds}])");
    }

    return FMars_Validation();
}

// Body-local action keys in centimetres, in the simulation body's axes, unit scale, and the easing into each. The strike
// key is translation only. The windup key may also pitch (rear the body up or dip it, about its own Y axis) by at most
// utils_crawler::MaxWindupPitchDegrees: the hit centre then travels an arc while the straight sample-to-sample hit query
// covers its chords, and at that limit a whole phase posed in one sample leaves the chord about 4 cm inside the arc for a
// hit centre 55 cm from the body's origin, well inside the hit sphere. Yaw and roll would swing the hit centre off the
// committed direction and stay rejected.
struct FMars_Crawler_AttackPose
{
    UPROPERTY()
    FTransform Windup = FTransform(FRotator::ZeroRotator, FVector(-10.0, 0.0, -5.0), FVector::OneVector);

    UPROPERTY()
    FTransform Strike = FTransform(FRotator::ZeroRotator, FVector(24.0, 0.0, 0.0), FVector::OneVector);

    UPROPERTY()
    ECk_TweenEasing WindupEasing = ECk_TweenEasing::OutCubic;

    UPROPERTY()
    ECk_TweenEasing StrikeEasing = ECk_TweenEasing::InQuad;

    // Also eases a cancelled attack back to neutral.
    UPROPERTY()
    ECk_TweenEasing RecoverEasing = ECk_TweenEasing::InOutCubic;
}

mixin FMars_Validation Validate(const FMars_Crawler_AttackPose& Self)
{
    if (utils_crawler::Get_IsPitchOnly(Self.Windup) == false || utils_crawler::Get_IsTranslationOnly(Self.Strike) == false)
    {
        return FMars_Validation(f"Crawler combat needs finite, unit-scale, translation-only keys, but for a windup pitch of at most {utils_crawler::MaxWindupPitchDegrees} degrees (windup [{Self.Windup.GetLocation().ToString()} {Self.Windup.Rotator().ToString()} {Self.Windup.GetScale3D().ToString()}], strike [{Self.Strike.GetLocation().ToString()} {Self.Strike.Rotator().ToString()} {Self.Strike.GetScale3D().ToString()}])");
    }

    return FMars_Validation();
}

// The pincer: the two front legs (the rig's first and last) leave the ground, are thrown up and apart through the windup
// (a spider's threat display) and slam down together in front of the body on the strike, riding the same phase clock and
// easings as the body keys. The keys are where the right claw's foot goes, in the simulation body's frame in centimetres
// (the root's, so they do not ride the body keys); the left claw mirrors them across the body's XZ plane. Each claw
// starts from, and recovers to, the spot its foot stood on. Off by default: a crawler without it, and one that cannot
// spare both front legs (see utils_crawler::Find_AttackClaws), jabs with its body alone. The claws are posed, not swept:
// the hit is still the body's sphere. utils_crawler::Make_RearingPincerCombat pairs these keys with body keys that rear.
struct FMars_Crawler_AttackPincer
{
    UPROPERTY()
    bool Enabled = false;

    UPROPERTY()
    FVector Windup = FVector(70.0, 55.0, 85.0);

    UPROPERTY()
    FVector Strike = FVector(125.0, 16.0, -30.0);

    // Each key lies between these fractions of the chain's length from the front leg's hip.
    UPROPERTY()
    float32 MinReachFraction = 0.2f;

    UPROPERTY()
    float32 MaxReachFraction = 0.9f;
}

// Where utils_crawler::Fit_PincerToRig moves a pincer's keys: onto RigData's front leg, no key lower than GroundClearance
// over its rest feet's ground.
struct FMars_Crawler_PincerFit
{
    UPROPERTY()
    UCk_ProceduralRig_Data RigData;

    UPROPERTY()
    float64 GroundClearance = 10.0;

    FMars_Crawler_PincerFit() {}

    FMars_Crawler_PincerFit(UCk_ProceduralRig_Data InRigData, float64 InGroundClearance)
    {
        RigData = InRigData;
        GroundClearance = InGroundClearance;
    }
}

// On the radial rig of InLegCount legs.
mixin FMars_Validation Validate(const FMars_Crawler_AttackPincer& Self, int32 InLegCount)
{
    return Self.Validate_OnRig(utils_crawler::Get_RigData(InLegCount));
}

// A disabled pincer is never checked. Both front legs share a hip distance from the body's XZ plane, so the right one
// answers for the pair.
mixin FMars_Validation Validate_OnRig(const FMars_Crawler_AttackPincer& Self, UCk_ProceduralRig_Data InRigData)
{
    if (Self.Enabled == false)
    { return FMars_Validation(); }

    if (utils_crawler::Get_IsFinite(Self.Windup) == false || utils_crawler::Get_IsFinite(Self.Strike) == false)
    { return FMars_Validation(f"Crawler pincer has a non-finite key (windup [{Self.Windup.ToString()}], strike [{Self.Strike.ToString()}])"); }

    if (Self.Windup.Y < 0.0 || Self.Strike.Y < 0.0)
    { return FMars_Validation(f"Crawler pincer keys are the right claw's and lie on the body's right (windup Y [{Self.Windup.Y}], strike Y [{Self.Strike.Y}])"); }

    if (Self.MinReachFraction < 0.0f || Self.MaxReachFraction > 1.0f || Self.MinReachFraction >= Self.MaxReachFraction)
    { return FMars_Validation(f"Crawler pincer has reach fractions [{Self.MinReachFraction}, {Self.MaxReachFraction}] outside 0 <= min < max <= 1"); }

    if (ck::Is_NOT_Valid(InRigData))
    { return FMars_Validation("Crawler pincer has no rig for its leg count"); }

    const TArray<FCk_ProceduralLeg_Spec> Legs = InRigData.Get_Legs();
    const auto Hip = Legs[0].Get_Placement().Get_HipLocal();
    const auto Reach = utils_crawler::Get_ChainReach(Legs[0]);
    const auto WindupDistance = (Self.Windup - Hip).Size();
    const auto StrikeDistance = (Self.Strike - Hip).Size();
    const auto Nearest = Reach * Self.MinReachFraction;
    const auto Farthest = Reach * Self.MaxReachFraction;
    if (WindupDistance < Nearest || WindupDistance > Farthest || StrikeDistance < Nearest || StrikeDistance > Farthest)
    { return FMars_Validation(f"Crawler pincer keys must lie [{Nearest}, {Farthest}] cm from the front hip [{Hip.ToString()}] (windup [{WindupDistance}], strike [{StrikeDistance}])"); }

    return FMars_Validation();
}

struct FMars_Crawler_AttackHit
{
    // The hit sphere's centre in the presentation's frame. The entity script defaults an unset one to the body's front face.
    UPROPERTY()
    FVector LocalCenter = FVector::ZeroVector;

    UPROPERTY()
    float32 Radius = 20.0f;

    UPROPERTY()
    float32 Damage = 15.0f;

    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType = GameplayTags::DamageType_Mars_Blunt;

    // An accepted hit centre that moves further than this between two samples cancels the attack (Displaced), unswept.
    UPROPERTY()
    float32 MaxSampleTravel = 80.0f;

    // The root moving further than this from where the attack started cancels it (Displaced).
    UPROPERTY()
    float32 MaxRootDrift = 10.0f;
}

mixin FMars_Validation Validate(const FMars_Crawler_AttackHit& Self)
{
    if (utils_crawler::Get_IsFinite(Self.LocalCenter) == false)
    { return FMars_Validation(f"Crawler combat has a non-finite hit LocalCenter [{Self.LocalCenter.ToString()}]"); }

    if (utils_crawler::Get_IsPositiveFinite(Self.Radius) == false || Math::IsFinite(Self.Damage) == false || Self.Damage < 0.0f)
    { return FMars_Validation(f"Crawler combat has a non-positive hit Radius [{Self.Radius}] or a negative or non-finite Damage [{Self.Damage}]"); }

    if (Self.DamageType.IsValid() == false)
    { return FMars_Validation("Crawler combat has no DamageType"); }

    if (utils_crawler::Get_IsPositiveFinite(Self.MaxSampleTravel) == false || utils_crawler::Get_IsPositiveFinite(Self.MaxRootDrift) == false)
    { return FMars_Validation(f"Crawler combat has a non-positive MaxSampleTravel [{Self.MaxSampleTravel}] or MaxRootDrift [{Self.MaxRootDrift}]"); }

    return FMars_Validation();
}

// Target acquisition (UMars_Processor_Crawler_Targeting) and the behaviour's approach cadence.
struct FMars_Crawler_Targeting
{
    UPROPERTY()
    float32 AcquireRadius = 700.0f;

    // A held target is kept until it leaves this radius (hysteresis over AcquireRadius).
    UPROPERTY()
    float32 LoseRadius = 900.0f;

    // Targets are only chosen and kept within this distance of the crawler's home (its root at Add).
    UPROPERTY()
    float32 HomeRadius = 600.0f;

    UPROPERTY()
    float32 SenseInterval = 0.20f;

    UPROPERTY()
    float32 RepathSeconds = 0.25f;

    UPROPERTY()
    float32 RepathDistance = 35.0f;

    UPROPERTY()
    float32 BlockedRetrySeconds = 1.0f;
}

mixin FMars_Validation Validate(const FMars_Crawler_Targeting& Self)
{
    if (utils_crawler::Get_IsPositiveFinite(Self.AcquireRadius) == false || utils_crawler::Get_IsPositiveFinite(Self.LoseRadius) == false ||
        utils_crawler::Get_IsPositiveFinite(Self.HomeRadius) == false || utils_crawler::Get_IsPositiveFinite(Self.SenseInterval) == false ||
        utils_crawler::Get_IsPositiveFinite(Self.RepathSeconds) == false || utils_crawler::Get_IsPositiveFinite(Self.RepathDistance) == false ||
        utils_crawler::Get_IsPositiveFinite(Self.BlockedRetrySeconds) == false)
    {
        return FMars_Validation(f"Crawler combat has a non-positive targeting value (acquire [{Self.AcquireRadius}], lose [{Self.LoseRadius}], home [{Self.HomeRadius}], sense [{Self.SenseInterval}], repath [{Self.RepathSeconds}] s / [{Self.RepathDistance}] cm, blocked retry [{Self.BlockedRetrySeconds}])");
    }

    if (Self.AcquireRadius > Self.LoseRadius)
    { return FMars_Validation(f"Crawler combat has an AcquireRadius [{Self.AcquireRadius}] beyond its LoseRadius [{Self.LoseRadius}]"); }

    return FMars_Validation();
}

// What must hold before a jab may start; the start request's admission checks it again.
struct FMars_Crawler_Prepare
{
    // Horizontal root-to-target distance. The entity script defaults an unset one to the body's half length + 70.
    UPROPERTY()
    float32 StartDistance = 0.0f;

    UPROPERTY()
    float32 FacingToleranceDegrees = 10.0f;

    UPROPERTY()
    float32 MaxHeightDifference = 60.0f;

    UPROPERTY()
    float32 MaxGroundSlopeDegrees = 35.0f;

    UPROPERTY()
    float32 MaxSpeedToStart = 3.0f;

    UPROPERTY()
    float32 TimeoutSeconds = 2.0f;
}

mixin FMars_Validation Validate(const FMars_Crawler_Prepare& Self)
{
    if (utils_crawler::Get_IsPositiveFinite(Self.StartDistance) == false || utils_crawler::Get_IsPositiveFinite(Self.TimeoutSeconds) == false)
    { return FMars_Validation(f"Crawler combat has a non-positive StartDistance [{Self.StartDistance}] or prepare TimeoutSeconds [{Self.TimeoutSeconds}]"); }

    if (utils_crawler::Get_IsPositiveFinite(Self.FacingToleranceDegrees) == false || Self.FacingToleranceDegrees > 180.0f ||
        utils_crawler::Get_IsPositiveFinite(Self.MaxGroundSlopeDegrees) == false || Self.MaxGroundSlopeDegrees > 90.0f)
    { return FMars_Validation(f"Crawler combat has a FacingToleranceDegrees [{Self.FacingToleranceDegrees}] outside (0, 180] or a MaxGroundSlopeDegrees [{Self.MaxGroundSlopeDegrees}] outside (0, 90]"); }

    if (Math::IsFinite(Self.MaxHeightDifference) == false || Self.MaxHeightDifference < 0.0f ||
        Math::IsFinite(Self.MaxSpeedToStart) == false || Self.MaxSpeedToStart < 0.0f)
    { return FMars_Validation(f"Crawler combat has a negative or non-finite MaxHeightDifference [{Self.MaxHeightDifference}] or MaxSpeedToStart [{Self.MaxSpeedToStart}]"); }

    return FMars_Validation();
}

// Off by default: a crawler without Enabled composes exactly as it did before combat existed. Enabled arms it only in a
// local combat world (utils_local_session::Get_IsLocalCombatWorld).
struct FMars_Crawler_Combat
{
    UPROPERTY()
    bool Enabled = false;

    // Whether an armed crawler chooses combat targets from the start; Request_SetAggression switches it at run time.
    UPROPERTY()
    ECk_EnableDisable StartAggressive = ECk_EnableDisable::Enable;

    UPROPERTY()
    FMars_Crawler_AttackTiming Timing;

    UPROPERTY()
    FMars_Crawler_AttackPose Pose;

    UPROPERTY()
    FMars_Crawler_AttackPincer Pincer;

    UPROPERTY()
    FMars_Crawler_AttackHit Hit;

    UPROPERTY()
    FMars_Crawler_Targeting Targeting;

    UPROPERTY()
    FMars_Crawler_Prepare Prepare;
}

// A disabled profile is never checked: it composes nothing.
mixin FMars_Validation Validate(const FMars_Crawler_Combat& Self)
{
    if (Self.Enabled == false)
    { return FMars_Validation(); }

    const auto TimingValidation = Self.Timing.Validate();
    if (TimingValidation.IsValid() == false)
    { return TimingValidation; }

    const auto PoseValidation = Self.Pose.Validate();
    if (PoseValidation.IsValid() == false)
    { return PoseValidation; }

    const auto HitValidation = Self.Hit.Validate();
    if (HitValidation.IsValid() == false)
    { return HitValidation; }

    const auto TargetingValidation = Self.Targeting.Validate();
    if (TargetingValidation.IsValid() == false)
    { return TargetingValidation; }

    return Self.Prepare.Validate();
}

struct FMars_Crawler_Spec
{
    // 4 or 6 on the Radial layout, 6 on the Spider (utils_crawler::Get_LayoutRigData).
    UPROPERTY()
    int32 LegCount = 4;

    // The rig the legs walk on and the clearance the body rides at.
    UPROPERTY()
    EMars_Crawler_Layout Layout = EMars_Crawler_Layout::Radial;

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

    // Disabled by default.
    UPROPERTY()
    FMars_Crawler_Combat Combat;

    FMars_Crawler_Spec() {}

    FMars_Crawler_Spec(int32 InLegCount, FBox InRoamBounds)
    {
        LegCount = InLegCount;
        RoamBounds = InRoamBounds;
    }
}

// The rig asset of the spec's layout and leg count; null when the pair has none.
mixin UCk_ProceduralRig_Data Get_RigData(const FMars_Crawler_Spec& Self)
{
    return utils_crawler::Get_LayoutRigData(Self.Layout, Self.LegCount);
}

mixin FMars_Validation Validate(const FMars_Crawler_Spec& Self)
{
    if (ck::Is_NOT_Valid(Self.Get_RigData()))
    { return FMars_Validation(f"Crawler has LegCount [{Self.LegCount}]; only 4 and 6 (Radial) and 6 (Spider) have rigs"); }

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
    if (RigValidation.IsValid() == false)
    { return RigValidation; }

    const auto CombatValidation = Self.Combat.Validate();
    if (CombatValidation.IsValid() == false)
    { return CombatValidation; }

    if (Self.Combat.Enabled)
    {
        const auto PincerValidation = Self.Combat.Pincer.Validate_OnRig(Self.Get_RigData());
        if (PincerValidation.IsValid() == false)
        { return PincerValidation; }
    }

    return Vitals.LegDebris.Validate();
}

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

// Composed by Add; afterwards only UMars_Processor_Crawler_Setup's damage handler writes it (HurtCount). The walker's
// legs, the parts, the navigator and the brain on the same root keep their own state.
struct FMars_Fragment_Crawler
{
    UPROPERTY()
    FCk_Handle_SurfaceMotion Motion;

    UPROPERTY()
    FCk_Handle_ProceduralGait Gait;

    UPROPERTY()
    FCk_Handle_ProceduralBodyPose BodyPose;

    // Armed crawlers own one body-channel player on the walker's articulation.
    UPROPERTY()
    FCk_Handle_ProceduralActionPlayer ActionPlayer;

    UPROPERTY()
    FCk_Handle_Transform Presentation;

    // In the rig asset's leg order; each leg entity carries its part, so the part names its leg.
    UPROPERTY()
    TArray<FCk_Handle_BodyPart> LegParts;

    // On the root (the motion's entity): goal -> path -> steering.
    UPROPERTY()
    FCk_Handle_SurfaceNavigator Navigator;

    // Damage events on the body or any leg so far. The Flinch task restarts its hold whenever it changes, so a hit that
    // lands while the flinch is being cleared cannot leave the crawler waiting on a fact that never clears.
    UPROPERTY()
    int32 HurtCount = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Combat state (an armed crawler only; utils_crawler::Add composes none of it otherwise)
//--------------------------------------------------------------------------------------------------------------------------

// Idle -> Windup -> Strike -> Recover -> Cooldown -> Idle. A cancel during Windup, Strike or Recover eases back to neutral
// in CancelRecover, then cools down; damage is possible only from accepted Strike samples.
enum EMars_Crawler_AttackPhase
{
    Idle,
    Windup,
    Strike,
    Recover,
    CancelRecover,
    Cooldown
}

enum EMars_Crawler_AttackCancel
{
    // The behaviour that asked for the attack left its state.
    StateExit,
    // The crawler took damage after the attack started.
    Hurt,
    // Fewer than MinLegsToWalk legs remain enabled.
    Crippled,
    // Dead or body Health depleted: no recovery, straight to neutral.
    Dead,
    // The attack's target is gone, depleted, disabled, out of LoseRadius, or the combat target changed.
    TargetLost,
    // Ungrounded, untrusted contact, too steep, or the gait or body pose is not Ready.
    Unsupported,
    // The body pose latched a failure: no recovery, straight to neutral.
    PoseFailed,
    // A requested pose sample was not published within PoseTimeoutSeconds.
    PoseTimeout,
    // The root drifted or turned, or an accepted sample jumped further than MaxSampleTravel.
    Displaced,
    // Combat was switched off for this crawler: no recovery, straight to neutral.
    Disabled,
    // A world body or another creature's hurtbox stood in the accepted sample path.
    Obstructed
}

enum EMars_Crawler_AttackReject
{
    Disarmed,
    // An attack, its recovery or its cooldown is still running.
    Busy,
    NoTarget,
    // Not the current combat target, or the target is no longer valid.
    TargetInvalid,
    OutOfRange,
    Facing,
    Moving,
    NotReady,
    Ungrounded,
    Slope,
    Height,
    Legs,
    Hurt,
    Dead,
    // A world body stands between the neutral and the windup hit centre.
    WindupBlocked,
    // A cancel arrived in the same request drain.
    CancelPending,
    // A pincer's claws are not both planted yet, or fewer than PincerMinStandingLegs of the other legs stand on trusted
    // ground.
    Stance
}

// Composed by Add on an armed crawler; never written afterwards.
struct FMars_Fragment_Crawler_Combat
{
    // Spec.Combat.Enabled in a local combat world.
    UPROPERTY()
    bool Armed = false;

    UPROPERTY()
    FCk_Handle_DamageDealer Dealer;

    // The root's location at Add: the leash centre of target acquisition.
    UPROPERTY()
    FVector Home = FVector::ZeroVector;
}

// Owner: UMars_Processor_Crawler_Targeting.
struct FMars_Fragment_Crawler_Targeting
{
    UPROPERTY()
    float32 SenseClock = 0.0f;

    // The last scan's choice (diagnostics).
    UPROPERTY()
    FCk_Handle Candidate;
}

// Owner: UMars_Processor_Crawler_HandleRequests.
struct FMars_Fragment_Crawler_CombatTarget
{
    // Targeting chooses targets only while this holds; switching it off also clears Target.
    UPROPERTY()
    bool Aggressive = true;

    UPROPERTY()
    FCk_Handle Target;

    // Bumped on every change of Target.
    UPROPERTY()
    int32 TargetGeneration = 0;
}

// Mailbox: written by UMars_Processor_Crawler_HandleRequests, consumed and reset by UMars_Processor_Crawler_AttackTick in
// the same frame.
struct FMars_Fragment_Crawler_AttackIntents
{
    UPROPERTY()
    TOptional<FMars_Request_Crawler_StartAttack> PendingStart;

    UPROPERTY()
    TOptional<EMars_Crawler_AttackCancel> PendingCancel;
}

// One front leg the attack's action has claimed. Points are the foot's, in the simulation body's frame.
struct FMars_Crawler_AttackClaw
{
    UPROPERTY()
    FCk_Handle_ProceduralLeg Leg;

    UPROPERTY()
    FName LegId;

    // 1 on the body's right, -1 on its left: the sign the pincer keys' Y takes.
    UPROPERTY()
    float32 Side = 1.0f;

    // Where the foot stood when the action first admitted a pose; unset until then.
    UPROPERTY()
    TOptional<FVector> Home;

    // The last point submitted; a cancelled attack eases back from it.
    UPROPERTY()
    FVector Requested = FVector::ZeroVector;

    UPROPERTY()
    FVector CancelRecoverStart = FVector::ZeroVector;
}

// Owner: UMars_Processor_Crawler_AttackTick, the one attack clock. Its inputs are the intents mailbox and the resolver's
// observations.
struct FMars_Fragment_Crawler_Attack
{
    UPROPERTY()
    EMars_Crawler_AttackPhase Phase = EMars_Crawler_AttackPhase::Idle;

    UPROPERTY()
    float32 PhaseElapsed = 0.0f;

    // Bumped on every admission and every cancel: a candidate of an older generation never commits.
    UPROPERTY()
    int32 Generation = 0;

    UPROPERTY()
    int32 HurtCountAtStart = 0;

    // The root's forward on the support plane at admission; the attack never re-aims.
    UPROPERTY()
    FVector CommittedDirection = FVector::ZeroVector;

    UPROPERTY()
    FVector RootAtStart = FVector::ZeroVector;

    UPROPERTY()
    FTransform NeutralRootLocal = FTransform::Identity;

    // The combat target at admission; a later change of the combat target cancels the attack instead.
    UPROPERTY()
    FCk_Handle Target;

    // The body pose sample awaiting acknowledgment; 0 when none.
    UPROPERTY()
    int64 PendingSampleId = 0;

    UPROPERTY()
    int64 NextSampleId = 0;

    // The pending sample is its phase's endpoint: its acknowledgment ends the phase.
    UPROPERTY()
    bool EndpointSubmitted = false;

    UPROPERTY()
    float32 PoseTimeoutElapsed = 0.0f;

    UPROPERTY()
    float32 CooldownRemaining = 0.0f;

    // The last action offset submitted; a cancelled attack eases back from it.
    UPROPERTY()
    FTransform RequestedActionOffset = FTransform::Identity;

    UPROPERTY()
    FTransform CancelRecoverStart = FTransform::Identity;

    // The front legs this attack's action claimed, right then left; empty for a body-only jab.
    UPROPERTY()
    TArray<FMars_Crawler_AttackClaw> Claws;

    // One scoped manual action per jab. The copied identity survives the action handle until its terminal stream drains.
    UPROPERTY()
    FCk_Handle ActionScope;

    UPROPERTY()
    FCk_Handle_ProceduralAction Action;

    UPROPERTY()
    FCk_ProceduralAction_Identity ActionIdentity;

    UPROPERTY()
    int64 ReceiptCursor = 0;

    UPROPERTY()
    bool EndRequested = false;

    UPROPERTY()
    bool TerminalSeen = false;

    UPROPERTY()
    bool TerminalConsumeIssued = false;

    UPROPERTY()
    bool TerminalConsumeSucceeded = false;

    // Latched by this attack's one damage request, whatever the dealer made of it; cleared by the next admission.
    UPROPERTY()
    bool DamageCommitted = false;

    // The sample whose candidate was committed; 0 when none.
    UPROPERTY()
    int64 CommittedSampleId = 0;

    // No later sample of this attack may produce a hit.
    UPROPERTY()
    bool WindowClosed = false;

    // Cooldown's identity sample went out.
    UPROPERTY()
    bool NeutralSubmitted = false;

    UPROPERTY()
    TOptional<EMars_Crawler_AttackCancel> LastCancel;

    UPROPERTY()
    TOptional<EMars_Crawler_AttackReject> LastReject;

    // What the attack's action said when it last ended a PoseFailed cancel (diagnostics): its outcome and reason.
    UPROPERTY()
    ECk_ProceduralAction_Outcome LastActionOutcome = ECk_ProceduralAction_Outcome::None;

    UPROPERTY()
    FName LastActionReason;
}

// One stored hit on the attack's target, committed or discarded by the next attack tick.
struct FMars_Crawler_HitCandidate
{
    UPROPERTY()
    FCk_Handle HitEntity;

    UPROPERTY()
    FCk_Handle_HitZone Zone;

    UPROPERTY()
    FCk_Handle Target;

    UPROPERTY()
    FVector Location = FVector::ZeroVector;

    UPROPERTY()
    FVector Normal = FVector::UpVector;

    UPROPERTY()
    int32 Generation = 0;

    UPROPERTY()
    int64 SampleId = 0;

    UPROPERTY()
    int32 HurtCount = 0;
}

// Mailbox: written by UMars_Processor_Crawler_AttackResolve (FGroup_Overlap); UMars_Processor_Crawler_AttackTick consumes
// the candidate, the obstruction and the displacement on the next frame and resets the attack's fields at admission.
struct FMars_Fragment_Crawler_AttackObservations
{
    UPROPERTY()
    int64 AckSampleId = 0;

    UPROPERTY()
    int64 AckRevision = 0;

    // The presentation's world transform of the last acknowledged sample.
    UPROPERTY()
    FTransform AcceptedWorld = FTransform::Identity;

    UPROPERTY()
    FVector AcceptedHitCenter = FVector::ZeroVector;

    UPROPERTY()
    FVector PreviousHitCenter = FVector::ZeroVector;

    UPROPERTY()
    TOptional<FMars_Crawler_HitCandidate> Candidate;

    UPROPERTY()
    bool Obstructed = false;

    UPROPERTY()
    TOptional<EMars_Crawler_AttackCancel> Displaced;

    UPROPERTY()
    bool ActionStreamFailed = false;

    // The longest sample-to-sample sweep of the current attack (diagnostics).
    UPROPERTY()
    float32 LongestSweep = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Engage (the behaviour layer's stage record; an armed crawler only)
//--------------------------------------------------------------------------------------------------------------------------

// The Engage behaviour's sub-SM stage (Mars_Crawler_Hfsm.as); None outside Engage.
enum EMars_Crawler_EngageStage
{
    None,
    Approach,
    Prepare,
    Attack,
    Wait
}

// Owner: the Engage stage tasks (Mars_Crawler_Hfsm.as), not a processor: each stage's task writes the stage it hands over
// to and the sub-SM's polled conditions read it; leaving Engage resets it. Times are on the current stage's clock,
// StageElapsed.
struct FMars_Fragment_Crawler_Engage
{
    UPROPERTY()
    EMars_Crawler_EngageStage Stage = EMars_Crawler_EngageStage::None;

    UPROPERTY()
    float32 StageElapsed = 0.0f;

    // Wait hands back to Approach no earlier than this.
    UPROPERTY()
    float32 RetryUntil = 0.0f;

    // Approach's last MoveTo; unset until the stage sends one.
    UPROPERTY()
    TOptional<float32> LastRepathAt;

    // Where the target stood at that MoveTo.
    UPROPERTY()
    FVector LastRepathTarget = FVector::ZeroVector;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Every phase change of the attack, once the attack state is fully written.
delegate void FMars_Delegate_Crawler_OnAttackPhaseChanged(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew);
event void FMars_Delegate_Crawler_OnAttackPhaseChanged_MC(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew);

// Every change of the combat target; an invalid handle is no target.
delegate void FMars_Delegate_Crawler_OnTargetChanged(FCk_Handle_Crawler InCrawler, FCk_Handle InOld, FCk_Handle InNew);
event void FMars_Delegate_Crawler_OnTargetChanged_MC(FCk_Handle_Crawler InCrawler, FCk_Handle InOld, FCk_Handle InNew);

struct FMars_Fragment_Crawler_Signals
{
    FMars_Delegate_Crawler_OnAttackPhaseChanged_MC OnAttackPhaseChanged;
    FMars_Delegate_Crawler_OnTargetChanged_MC OnTargetChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Switches target acquisition on or off. Off clears the combat target and cancels an attack in flight (Disabled); on
// lets the targeting processor choose again on its next scan.
struct FMars_Request_Crawler_SetAggression
{
    UPROPERTY()
    ECk_EnableDisable Aggression = ECk_EnableDisable::Enable;

    FMars_Request_Crawler_SetAggression() {}

    FMars_Request_Crawler_SetAggression(ECk_EnableDisable InAggression)
    {
        Aggression = InAggression;
    }
}

// Selects the combat target; an invalid handle clears it. A change cancels an attack in flight (TargetLost).
struct FMars_Request_Crawler_SetCombatTarget
{
    UPROPERTY()
    FCk_Handle Target;

    FMars_Request_Crawler_SetCombatTarget() {}

    FMars_Request_Crawler_SetCombatTarget(FCk_Handle InTarget)
    {
        Target = InTarget;
    }
}

// One jab at Target, which must be the current combat target. The next attack tick admits it or records why not
// (Get_AttackLastReject); it is never queued behind an attack in flight.
struct FMars_Request_Crawler_StartAttack
{
    UPROPERTY()
    FCk_Handle Target;

    FMars_Request_Crawler_StartAttack() {}

    FMars_Request_Crawler_StartAttack(FCk_Handle InTarget)
    {
        Target = InTarget;
    }
}

// Cancels the attack in flight. Idempotent: a recovery is never restarted. A start in the same drain is rejected.
struct FMars_Request_Crawler_CancelAttack
{
    UPROPERTY()
    EMars_Crawler_AttackCancel Reason = EMars_Crawler_AttackCancel::StateExit;

    FMars_Request_Crawler_CancelAttack() {}

    FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel InReason)
    {
        Reason = InReason;
    }
}

// Per kind: the last SetAggression and the last SetCombatTarget win, the first cancel reason wins, the last start is the
// one considered.
struct FMars_Fragment_Crawler_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Crawler_SetAggression> SetAggressionRequests;

    UPROPERTY()
    TArray<FMars_Request_Crawler_SetCombatTarget> SetCombatTargetRequests;

    UPROPERTY()
    TArray<FMars_Request_Crawler_StartAttack> StartAttackRequests;

    UPROPERTY()
    TArray<FMars_Request_Crawler_CancelAttack> CancelAttackRequests;
}

struct FMars_Tag_Crawler_NeedsSetup {}
