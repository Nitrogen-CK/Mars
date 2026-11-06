//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

// Composed ON the persistent world item's entity (the one whose body the kernel samples), so a contact handler resolves it
// straight from the body. The world item's body must be built with FCk_JoltBody_Spec.Set_PersistContacts(Enable): without
// it a resting awake body reports no contact after the first step and reads as unsupported once SupportGraceSeconds pass.
asset Mars_ScreamingTurnipHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_ScreamingTurnip";
    RequiredFragments.Add(FMars_Feature_ScreamingTurnip);
    Description = "A screaming root on a persistent world item: placement derived from its mount and its body's settle, and a repeating warning -> scream cycle while held or settled on the ground";
}
struct FMars_Feature_ScreamingTurnip {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// Where the root is, as the voice cares about it. Derived every tick from the world item's mount and its body's settle;
// nothing requests it.
enum EMars_ScreamingTurnip_Placement
{
    // A mount change in flight (a pending mount, an arrival, a pending release): the warning is frozen, not cancelled.
    Transfer,
    // Held in the hands, the mount settled: screams.
    Held,
    // In the world, not physically settled (in flight, rolling, bouncing): silent, the warning cancelled.
    Loose,
    // In the world, supported and still for the settle dwell: screams.
    LooseSettled,
    // Carried (stowed, not selected): silent, the warning cancelled.
    Protected
}

enum EMars_ScreamingTurnip_Phase
{
    // Silent: not eligible, or eligible this very tick and not yet started.
    Dormant,
    // The first stage of the warning.
    Anticipate,
    // The second stage of the warning; the scream commits the instant it completes.
    Inhale,
    // The burst after a commit.
    Scream,
    Recover,
    // Quiet until the cooldown measured from the last commit runs out.
    RecoveryIdle
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The voice's timings, seconds. The cooldown is measured from the scream COMMIT and includes the scream and its recovery,
// so an uninterrupted start-to-start period is CooldownSeconds + AnticipateSeconds + InhaleSeconds (9.5 s by default).
struct FMars_ScreamingTurnip_Vocal
{
    UPROPERTY()
    float32 AnticipateSeconds = 0.3f;

    UPROPERTY()
    float32 InhaleSeconds = 1.2f;

    UPROPERTY()
    float32 ScreamSeconds = 0.6f;

    UPROPERTY()
    float32 RecoverSeconds = 1.0f;

    UPROPERTY()
    float32 CooldownSeconds = 8.0f;
}

// Every stage takes time, and the cooldown outlasts the burst it follows.
mixin FMars_Validation Validate(const FMars_ScreamingTurnip_Vocal& Self)
{
    const auto AllFinite = Math::IsFinite(Self.AnticipateSeconds) && Math::IsFinite(Self.InhaleSeconds) && Math::IsFinite(Self.ScreamSeconds)
        && Math::IsFinite(Self.RecoverSeconds) && Math::IsFinite(Self.CooldownSeconds);
    if (AllFinite == false)
    { return FMars_Validation("ScreamingTurnip Vocal has a non-finite timing"); }

    if (Self.AnticipateSeconds <= 0.0f || Self.InhaleSeconds <= 0.0f || Self.ScreamSeconds <= 0.0f || Self.RecoverSeconds <= 0.0f)
    {
        return FMars_Validation(f"ScreamingTurnip Vocal has a non-positive stage (Anticipate [{Self.AnticipateSeconds}], Inhale "
            + f"[{Self.InhaleSeconds}], Scream [{Self.ScreamSeconds}], Recover [{Self.RecoverSeconds}])");
    }

    if (Self.CooldownSeconds < Self.ScreamSeconds)
    { return FMars_Validation(f"ScreamingTurnip Vocal CooldownSeconds [{Self.CooldownSeconds}] is shorter than ScreamSeconds [{Self.ScreamSeconds}]"); }

    return FMars_Validation();
}

// The physical settle test, cm/s and deg/s (never radians). Enter: supported, both speeds at or under the Enter bars for
// EnterDwellSeconds. Exit: support lost (at once), or either speed over its Exit bar for ExitDwellSeconds. A contact this
// old (SupportGraceSeconds) still counts as support: contact events arrive from the previous physics step.
struct FMars_ScreamingTurnip_Settlement
{
    UPROPERTY()
    float32 EnterLinearCmPerSec = 30.0f;

    UPROPERTY()
    float32 EnterAngularDegPerSec = 20.0f;

    UPROPERTY()
    float32 EnterDwellSeconds = 0.35f;

    UPROPERTY()
    float32 ExitLinearCmPerSec = 100.0f;

    UPROPERTY()
    float32 ExitAngularDegPerSec = 60.0f;

    UPROPERTY()
    float32 ExitDwellSeconds = 0.15f;

    UPROPERTY()
    float32 SupportGraceSeconds = 0.2f;
}

// The exit bars sit above the enter bars (the hysteresis), and every dwell and the grace are non-negative.
mixin FMars_Validation Validate(const FMars_ScreamingTurnip_Settlement& Self)
{
    if (Self.EnterLinearCmPerSec < 0.0f || Self.EnterAngularDegPerSec < 0.0f)
    { return FMars_Validation(f"ScreamingTurnip Settlement has a negative enter bar (linear [{Self.EnterLinearCmPerSec}], angular [{Self.EnterAngularDegPerSec}])"); }

    if (Self.ExitLinearCmPerSec < Self.EnterLinearCmPerSec || Self.ExitAngularDegPerSec < Self.EnterAngularDegPerSec)
    {
        return FMars_Validation(f"ScreamingTurnip Settlement exit bars (linear [{Self.ExitLinearCmPerSec}], angular "
            + f"[{Self.ExitAngularDegPerSec}]) sit under its enter bars (linear [{Self.EnterLinearCmPerSec}], angular [{Self.EnterAngularDegPerSec}])");
    }

    if (Self.EnterDwellSeconds < 0.0f || Self.ExitDwellSeconds < 0.0f || Self.SupportGraceSeconds <= 0.0f)
    {
        return FMars_Validation(f"ScreamingTurnip Settlement has a negative dwell or a non-positive grace (enter [{Self.EnterDwellSeconds}], "
            + f"exit [{Self.ExitDwellSeconds}], grace [{Self.SupportGraceSeconds}])");
    }

    return FMars_Validation();
}

// Built by the entity script before Add. Not UPROPERTYs: spawn params never carry handles.
struct FMars_ScreamingTurnip_Parts
{
    // The persistent world item whose mount and body the kernel reads; the kernel is composed on its entity.
    FCk_Handle_WorldItem WorldItem;

    FMars_ScreamingTurnip_Parts() {}

    FMars_ScreamingTurnip_Parts(FCk_Handle_WorldItem InWorldItem)
    {
        WorldItem = InWorldItem;
    }
}

mixin FMars_Validation Validate(const FMars_ScreamingTurnip_Parts& Self)
{
    if (ck::Is_NOT_Valid(Self.WorldItem))
    { return FMars_Validation("ScreamingTurnip has no Parts.WorldItem"); }

    return FMars_Validation();
}

struct FMars_ScreamingTurnip_Spec
{
    UPROPERTY()
    FMars_ScreamingTurnip_Vocal Vocal;

    UPROPERTY()
    FMars_ScreamingTurnip_Settlement Settlement;

    FMars_ScreamingTurnip_Parts Parts;
}

mixin FMars_Validation Validate(const FMars_ScreamingTurnip_Spec& Self)
{
    const auto Vocal = Self.Vocal.Validate();
    if (Vocal.IsValid() == false)
    { return Vocal; }

    const auto Settlement = Self.Settlement.Validate();
    if (Settlement.IsValid() == false)
    { return Settlement; }

    return Self.Parts.Validate();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_ScreamingTurnip_Params
{
    UPROPERTY()
    FMars_ScreamingTurnip_Vocal Vocal;

    UPROPERTY()
    FMars_ScreamingTurnip_Settlement Settlement;

    UPROPERTY()
    FCk_Handle_WorldItem WorldItem;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the ScreamingTurnip processors (and composed by Add). Every time is on Clock, the kernel's own monotonic
// time accumulated from the tick's delta.
struct FMars_Fragment_ScreamingTurnip
{
    UPROPERTY()
    EMars_ScreamingTurnip_Placement Placement = EMars_ScreamingTurnip_Placement::Loose;

    UPROPERTY()
    EMars_ScreamingTurnip_Phase Phase = EMars_ScreamingTurnip_Phase::Dormant;

    UPROPERTY()
    float32 Clock = 0.0f;

    UPROPERTY()
    float32 PhaseStartedAt = 0.0f;

    // Seconds into the warning (Anticipate then Inhale); kept across a Transfer, zeroed by a cancel.
    UPROPERTY()
    float32 WarningElapsed = 0.0f;

    UPROPERTY()
    TOptional<float32> LastScreamCommittedAt;

    // 0 = none yet.
    UPROPERTY()
    int32 ScreamSequence = 0;

    // The world item's root at the last commit.
    UPROPERTY()
    FVector LastWorldPosition = FVector::ZeroVector;

    // A Suspend was drained: the next tick re-derives placement and runs no voice.
    UPROPERTY()
    bool SuspendPending = false;

    // One diagnostic per entity for a commit with no transform to place it.
    UPROPERTY()
    bool WarnedMissingTransform = false;
}

// The settle sampler's scratch (mount World only), reset whenever the item leaves the world. Written by the Tick processor;
// the Setup processor's contact handler stamps LastSupportAt.
struct FMars_Fragment_ScreamingTurnip_Settle
{
    UPROPERTY()
    float32 EnterDwell = 0.0f;

    UPROPERTY()
    float32 ExitDwell = 0.0f;

    // Clock at the last non-sensor contact with the static world or a non-dynamic body.
    UPROPERTY()
    TOptional<float32> LastSupportAt;

    UPROPERTY()
    TOptional<FQuat> PrevRotation;

    UPROPERTY()
    TOptional<float32> PrevSampleAt;

    UPROPERTY()
    float32 AngularDegPerSec = 0.0f;

    UPROPERTY()
    float32 LinearCmPerSec = 0.0f;

    // The last sample's verdict: a recent supporting contact, or asleep.
    UPROPERTY()
    bool HasSupport = false;

    // One diagnostic per entity for a world-mounted item with no body to sample.
    UPROPERTY()
    bool WarnedMissingBody = false;
}

// The Setup processor binds the body's contacts once, then removes this tag.
struct FMars_Tag_ScreamingTurnip_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_ScreamingTurnip_OnPlacementChanged(FCk_Handle_ScreamingTurnip InTurnip,
    EMars_ScreamingTurnip_Placement InPrevious, EMars_ScreamingTurnip_Placement InNew);
event void FMars_Delegate_ScreamingTurnip_OnPlacementChanged_MC(FCk_Handle_ScreamingTurnip InTurnip,
    EMars_ScreamingTurnip_Placement InPrevious, EMars_ScreamingTurnip_Placement InNew);

delegate void FMars_Delegate_ScreamingTurnip_OnPhaseChanged(FCk_Handle_ScreamingTurnip InTurnip,
    EMars_ScreamingTurnip_Phase InPrevious, EMars_ScreamingTurnip_Phase InNew);
event void FMars_Delegate_ScreamingTurnip_OnPhaseChanged_MC(FCk_Handle_ScreamingTurnip InTurnip,
    EMars_ScreamingTurnip_Phase InPrevious, EMars_ScreamingTurnip_Phase InNew);

// One per commit. InWorldPosition is the world item's root at the commit, copied.
delegate void FMars_Delegate_ScreamingTurnip_OnScreamCommitted(FCk_Handle_ScreamingTurnip InTurnip, int32 InSequence, FVector InWorldPosition);
event void FMars_Delegate_ScreamingTurnip_OnScreamCommitted_MC(FCk_Handle_ScreamingTurnip InTurnip, int32 InSequence, FVector InWorldPosition);

struct FMars_Fragment_ScreamingTurnip_Signals
{
    FMars_Delegate_ScreamingTurnip_OnPlacementChanged_MC OnPlacementChanged;
    FMars_Delegate_ScreamingTurnip_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_ScreamingTurnip_OnScreamCommitted_MC OnScreamCommitted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Silences the voice as entering Loose does (the warning cancelled, phase Dormant, the last commit and the sequence kept);
// the next tick re-derives placement and runs no voice. For the owning entity script on teardown.
struct FMars_Request_ScreamingTurnip_Suspend
{
    // AngelScript rejects a TArray of an empty struct.
    UPROPERTY()
    bool Requested = true;

    FMars_Request_ScreamingTurnip_Suspend() {}
}

struct FMars_Fragment_ScreamingTurnip_Requests
{
    UPROPERTY()
    TArray<FMars_Request_ScreamingTurnip_Suspend> SuspendRequests;
}
