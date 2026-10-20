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
// Combat spec: the attack loadout (authored assets; the entity script resolves them into Spec.ResolvedAttacks)
//--------------------------------------------------------------------------------------------------------------------------

// Retired with the clip fields below: the kernel never reads it. It stays for the frozen spawn-param layout; the
// attack authoring tools (Script/Editor/Mars_AttackAuthoring.as) read it as a reference default.
struct FMars_Crawler_AttackTiming
{
    UPROPERTY()
    float32 CooldownSeconds = 0.70f;

    UPROPERTY()
    float32 CancelSeconds = 0.15f;
}

// The two reference clips the editor's clip builder makes (Script/Editor/Mars_CrawlerAttackClips.as).
enum EMars_Crawler_AttackClipKind
{
    // The body alone.
    Jab,
    // The body with both front legs, through the ClawRight and ClawLeft slots.
    Pincer
}

// Retired: see FMars_Crawler_AttackTiming.
struct FMars_Crawler_AttackHit
{
    UPROPERTY()
    FVector LocalCenter = FVector::ZeroVector;

    UPROPERTY()
    float32 Radius = 20.0f;

    UPROPERTY()
    float32 Damage = 15.0f;

    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType = GameplayTags::DamageType_Mars_Blunt;

    UPROPERTY()
    float32 MaxSampleTravel = 80.0f;

    UPROPERTY()
    float32 MaxRootDrift = 10.0f;
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

// Retired: see FMars_Crawler_AttackTiming.
struct FMars_Crawler_Prepare
{
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

// Off by default: a crawler without Enabled composes no combat state. Enabled arms it only in a local combat world
// (utils_local_session::Get_IsLocalCombatWorld).
struct FMars_Crawler_Combat
{
    // What the crawler attacks with: the definitions, their selection and execution policy.
    UPROPERTY()
    TSoftObjectPtr<UMars_AttackLoadout_Data> Loadout;

    // Empty: the default body + front-claw anatomy (utils_crawler::Make_AttackAnatomy).
    UPROPERTY()
    TArray<FMars_Attack_AnatomyBinding> Anatomy;

    UPROPERTY()
    bool Enabled = false;

    // Whether an armed crawler chooses combat targets from the start; Request_SetAggression switches it at run time.
    UPROPERTY()
    ECk_EnableDisable StartAggressive = ECk_EnableDisable::Enable;

    // Retired with the clips: see FMars_Crawler_AttackTiming.
    UPROPERTY()
    FMars_Crawler_AttackTiming Timing;

    // Retired: Validate rejects a set clip (author a Loadout).
    UPROPERTY()
    TSoftObjectPtr<UCk_ProceduralAction_Data> JabClip;

    // Retired: Validate rejects a set clip (author a Loadout).
    UPROPERTY()
    TSoftObjectPtr<UCk_ProceduralAction_Data> PincerClip;

    // Retired with the clips: see FMars_Crawler_AttackTiming.
    UPROPERTY()
    FMars_Crawler_AttackHit Hit;

    UPROPERTY()
    FMars_Crawler_Targeting Targeting;

    // Retired with the clips: see FMars_Crawler_AttackTiming.
    UPROPERTY()
    FMars_Crawler_Prepare Prepare;
}

// A disabled profile is never checked: it composes nothing.
mixin FMars_Validation Validate(const FMars_Crawler_Combat& Self)
{
    if (Self.Enabled == false)
    { return FMars_Validation(); }

    if (Self.JabClip.IsNull() == false || Self.PincerClip.IsNull() == false)
    { return FMars_Validation(f"Crawler combat sets a retired JabClip [{Self.JabClip.ToSoftObjectPath().ToString()}] or PincerClip [{Self.PincerClip.ToSoftObjectPath().ToString()}]: author a Loadout"); }

    if (Self.Loadout.IsNull())
    { return FMars_Validation("Crawler combat has no Loadout"); }

    const auto TargetingValidation = Self.Targeting.Validate();
    if (TargetingValidation.IsValid() == false)
    { return TargetingValidation; }

    const auto Asset = Self.Loadout.Get();
    if (ck::Is_NOT_Valid(Asset))
    { return FMars_Validation(f"Crawler combat Loadout [{Self.Loadout.ToSoftObjectPath().ToString()}] is not loaded (the entity script loads it)"); }

    const auto Report = utils_attack::Validate_Loadout(Asset.Spec);
    return Report.Get_IsValid() ? FMars_Validation() : FMars_Validation(utils_crawler::Get_AttackValidationText(Report));
}

struct FMars_Crawler_Spec
{
    // Construction-time immutable values. Assets and frozen clips are pinned by the entity script.
    UPROPERTY(NotEditable, BlueprintHidden)
    FMars_Attack_ResolvedLoadout ResolvedAttacks;

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

    // How it answers lantern light (Mars_Crawler_Light.as); the entity script builds its Sense.
    UPROPERTY()
    FMars_Crawler_Light Light;

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

    const auto LightValidation = Self.Light.Validate();
    if (LightValidation.IsValid() == false)
    { return LightValidation; }

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
    FCk_Handle_ProceduralArticulation Articulation;

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

// Idle -> Windup -> Strike -> Recover -> Cooldown -> Idle. Windup is entered at admission; Strike and Recover when an
// accepted clip interval of that phase arrives; Cooldown when the accepted motion closes the Offense window. A cancel
// during Windup, Strike or Recover cancels the clip action and waits in CancelRecover for the action's return to finish,
// then cools down; damage is possible only from accepted Strike intervals.
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
    // The body pose latched a failure, or the clip action failed, was lost or stopped on its own: no recovery, straight
    // to neutral.
    PoseFailed,
    // The root drifted or turned, or an accepted sample jumped further than MaxSampleTravel.
    Displaced,
    // Combat was switched off for this crawler: no recovery, straight to neutral.
    Disabled,
    // A world body or another creature's hurtbox stood in the accepted sample path.
    Obstructed,
    RequiredPartUnavailable
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
    // A claimed limb's foot is not planted on trusted ground yet, or too few of the other legs stand (SupportStance).
    Stance,
    SelectionStale,
    AttackUnknown,
    RequiredPartUnavailable,
    SelectionNotPermitted,
    // A Shun crawler stands in the light of a lantern the target holds (Get_IsWarded).
    Warded
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
    TOptional<FMars_Request_Crawler_PrepareAttack> PendingPrepare;

    UPROPERTY()
    TOptional<FMars_Request_Crawler_StartAttack> PendingStart;

    UPROPERTY()
    TOptional<EMars_Crawler_AttackCancel> PendingCancel;
}

// The attack's clip action: one per attack, an entity of the crawler. The copied identity outlives the action handle
// until the attack forgets the released action.
struct FMars_Crawler_AttackStream
{
    UPROPERTY()
    FCk_Handle_ProceduralAction Action;

    UPROPERTY()
    FCk_ProceduralAction_Identity Identity;

    UPROPERTY()
    bool CancelRequested = false;
}

// What admission captured; the attack never re-aims.
struct FMars_Crawler_AttackStart
{
    UPROPERTY()
    int32 HurtCount = 0;

    // The root's forward on the support plane.
    UPROPERTY()
    FVector Direction = FVector::ZeroVector;

    UPROPERTY()
    FVector Root = FVector::ZeroVector;

    UPROPERTY()
    FTransform NeutralRootLocal = FTransform::Identity;

    // The combat target at admission; a later change of the combat target cancels the attack instead.
    UPROPERTY()
    FCk_Handle Target;
}

// The attack's one damage request, whatever the dealer made of it; cleared by the next admission.
struct FMars_Crawler_AttackDamageLedger
{
    UPROPERTY()
    bool Committed = false;

    // The accepted sample whose candidate was committed; 0 when none.
    UPROPERTY()
    int64 SampleId = 0;

    UPROPERTY()
    FMars_Crawler_EmitterContact Emitter;
}

struct FMars_Crawler_AttackDiagnostics
{
    UPROPERTY()
    TOptional<EMars_Crawler_AttackCancel> LastCancel;

    UPROPERTY()
    TOptional<EMars_Crawler_AttackReject> LastReject;

    // What the attack's action said when it last ended a PoseFailed cancel: its outcome and reason.
    UPROPERTY()
    ECk_ProceduralAction_Outcome LastActionOutcome = ECk_ProceduralAction_Outcome::None;

    UPROPERTY()
    FName LastActionReason;
}

// Owner: UMars_Processor_Crawler_AttackTick. Its inputs are the intents mailbox and the resolver's observations; the
// clip action owns the motion's timing.
struct FMars_Fragment_Crawler_Attack
{
    UPROPERTY()
    FMars_Attack_ResolvedPlan Plan;

    UPROPERTY()
    FMars_Attack_Admission Admission;

    UPROPERTY()
    FMars_Attack_Result Result;

    // Once per accepted attempt, independent of native action-handle lifetime.
    UPROPERTY()
    bool CueInterrupted = false;

    UPROPERTY()
    FMars_Crawler_AttackCleanup Cleanup;

    UPROPERTY()
    EMars_Crawler_AttackPhase Phase = EMars_Crawler_AttackPhase::Idle;

    // Bumped on every admission and every cancel: a candidate of an older generation never commits.
    UPROPERTY()
    int32 Generation = 0;

    UPROPERTY()
    float32 CooldownRemaining = 0.0f;

    // Set by a cancel, or folded in from the resolver's stream evidence: no later accepted interval of this attack may
    // sweep or produce a hit, whatever windows it carries.
    UPROPERTY()
    bool WindowClosed = false;

    UPROPERTY()
    FMars_Crawler_AttackStream Stream;

    UPROPERTY()
    FMars_Crawler_AttackStart Start;

    UPROPERTY()
    FMars_Crawler_AttackDamageLedger Ledger;

    UPROPERTY()
    FMars_Crawler_AttackDiagnostics Diagnostics;
}

// One stored hit on the attack's target, committed or discarded by the next attack tick.
struct FMars_Crawler_HitCandidate
{
    UPROPERTY()
    FMars_Crawler_EmitterContact EmitterContact;

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
}

// The resolver's read of the action's receipt stream.
struct FMars_Crawler_StreamEvidence
{
    UPROPERTY()
    int64 Cursor = 0;

    UPROPERTY()
    bool TerminalSeen = false;

    UPROPERTY()
    TOptional<FCk_ProceduralAction_Stamp> FirstAccepted;

    UPROPERTY()
    TOptional<FCk_ProceduralAction_Result> Terminal;

    UPROPERTY()
    FName TerminalSource;

    UPROPERTY()
    int64 ContentRevision = 0;

    UPROPERTY()
    int64 TopologyRevision = 0;

    UPROPERTY()
    FName Failure;

    UPROPERTY()
    bool Unavailable = false;

    UPROPERTY()
    bool Failed = false;

    // The resolver closed the damage window (a stream failure, a part failure, a displacement or an obstruction); the
    // tick folds it into the attack's WindowClosed.
    UPROPERTY()
    bool WindowClosed = false;

    // The sample sequence of the last accepted receipt of the current action; 0 when none.
    UPROPERTY()
    int64 AckSampleId = 0;

    UPROPERTY()
    int64 AckRevision = 0;
}

// How far the accepted motion got.
struct FMars_Crawler_AcceptedProgress
{
    // The clip interval of the last accepted receipt.
    UPROPERTY()
    FCk_ProceduralAction_Interval Interval;

    // The latest posed phase (Windup, Strike or Recover) an accepted interval reached; Idle before the first.
    UPROPERTY()
    EMars_Crawler_AttackPhase Phase = EMars_Crawler_AttackPhase::Idle;

    // An accepted interval carried the Offense window's exit: the clip's posed motion is over.
    UPROPERTY()
    bool OffenseEnded = false;
}

// What the accepted sweeps found.
struct FMars_Crawler_HitObservations
{
    UPROPERTY()
    TArray<FMars_Crawler_EmitterSegment> Emitters;

    UPROPERTY()
    TArray<FMars_Attack_Blocker> EmitterFailures;

    UPROPERTY()
    TArray<FMars_Attack_Blocker> RequiredPartFailures;

    UPROPERTY()
    TOptional<FMars_Crawler_HitCandidate> Candidate;

    UPROPERTY()
    bool Obstructed = false;

    UPROPERTY()
    TOptional<EMars_Crawler_AttackCancel> Displaced;

    // The longest sample-to-sample sweep of the current attack (diagnostics).
    UPROPERTY()
    float32 LongestSweep = 0.0f;
}

// Mailbox: written by UMars_Processor_Crawler_AttackResolve (FGroup_Overlap); UMars_Processor_Crawler_AttackTick consumes
// the candidate, the obstruction, the displacement and the accepted phase on the next frame and resets it at admission.
struct FMars_Fragment_Crawler_AttackObservations
{
    // Every validated accepted interval from the bounded 4 x 16 record drain; the tick copies and clears it once.
    UPROPERTY()
    TArray<FMars_Attack_CueObservation> PendingCueObservations;

    UPROPERTY()
    FMars_Crawler_StreamEvidence Stream;

    UPROPERTY()
    FMars_Crawler_AcceptedProgress Accepted;

    UPROPERTY()
    FMars_Crawler_HitObservations Hit;
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

// The Engage sub-SM's blackboard (the request-doctrine exception in CLAUDE.md): only the Engage stage tasks
// (Mars_Crawler_Hfsm.as) write it and no processor reads it; each stage's task writes the stage it hands over to and the
// sub-SM's polled conditions read it; leaving Engage resets it. Times are on the current stage's clock, StageElapsed.
struct FMars_Fragment_Crawler_EngageBlackboard
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
    FMars_Delegate_Crawler_OnAttackCue_MC OnAttackCue;
    FMars_Delegate_Crawler_OnAttackDecisionChanged_MC OnAttackDecisionChanged;
    FMars_Delegate_Crawler_OnAttackAdmitted_MC OnAttackAdmitted;
    FMars_Delegate_Crawler_OnAttackCompleted_MC OnAttackCompleted;
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

// One attack at Target, which must be the current combat target. The next attack tick admits it or records why not
// (Get_AttackLastReject); it is never queued behind an attack in flight.
struct FMars_Request_Crawler_StartAttack
{
    // None: fresh selection; set: the exact evaluated choice (rejected when stale or not the permitted one).
    UPROPERTY()
    FGameplayTag AttackId;

    UPROPERTY()
    int32 SelectionGeneration = 0;

    UPROPERTY()
    FCk_Handle Target;

    FMars_Request_Crawler_StartAttack() {}

    FMars_Request_Crawler_StartAttack(FCk_Handle InTarget)
    {
        Target = InTarget;
    }

    FMars_Request_Crawler_StartAttack(FCk_Handle InTarget, FGameplayTag InAttackId, int32 InSelectionGeneration)
    {
        Target = InTarget;
        AttackId = InAttackId;
        SelectionGeneration = InSelectionGeneration;
    }
}

// Starts (Enable) or abandons (Disable) the readiness wait for Target, which must be the current combat target: while it
// runs the kernel keeps the preferred attack and times it out after that definition's Prepare.TimeoutSeconds. Only an
// Idle attack starts one; an abandon resets it in any phase.
struct FMars_Request_Crawler_PrepareAttack
{
    UPROPERTY()
    FCk_Handle Target;

    UPROPERTY()
    ECk_EnableDisable Preparation = ECk_EnableDisable::Enable;

    FMars_Request_Crawler_PrepareAttack() {}

    FMars_Request_Crawler_PrepareAttack(FCk_Handle InTarget, ECk_EnableDisable InPreparation)
    {
        Target = InTarget;
        Preparation = InPreparation;
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

// Per kind: the last SetAggression and the last SetCombatTarget win, the first cancel reason wins, the last start and the
// last prepare are the ones considered.
struct FMars_Fragment_Crawler_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Crawler_PrepareAttack> PrepareAttackRequests;

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
