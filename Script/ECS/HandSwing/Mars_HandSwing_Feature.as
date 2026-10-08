//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HandSwingHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_HandSwing";
    RequiredFragments.Add(FMars_Feature_HandSwing);
    Description = "A procedural melee swing of the player's hand: windup, strike and recovery poses on a timeline, as an offset in the hand's space";
}

struct FMars_Feature_HandSwing {}

// Where the swing is on its timeline. None is at rest (the offset is identity).
enum EMars_HandSwing_Phase
{
    None,
    // Easing from where the hand was into the windup pose.
    Windup,
    // The fast travel from the windup pose through the impact to the strike pose.
    Strike,
    // Easing from the strike pose back to rest.
    Recover
}

//--------------------------------------------------------------------------------------------------------------------------
// Arc
//--------------------------------------------------------------------------------------------------------------------------

// One pose the swing passes through, in the hand's space (X forward, Y right, Z up; cm and degrees), and how the hand
// eases toward it.
struct FMars_HandSwing_Key
{
    UPROPERTY()
    FVector Location = FVector::ZeroVector;

    UPROPERTY()
    FRotator Rotation = FRotator::ZeroRotator;

    UPROPERTY()
    ECk_TweenEasing Easing = ECk_TweenEasing::OutCubic;

    FMars_HandSwing_Key() {}

    FMars_HandSwing_Key(FVector InLocation, FRotator InRotation, ECk_TweenEasing InEasing)
    {
        Location = InLocation;
        Rotation = InRotation;
        Easing = InEasing;
    }
}

// The shape of a swing, authored per item (UMars_ItemTrait_Strike::Swing). Rest -> Windup -> Strike -> Rest; the blow lands
// ImpactFraction of the way through the strike travel's time. The windup and recovery take whatever time the request
// leaves around the strike travel (Make_Timeline). Default: a right-handed chop.
struct FMars_HandSwing_Arc
{
    UPROPERTY()
    FMars_HandSwing_Key Windup = FMars_HandSwing_Key(FVector(-8.0, 3.0, 12.0), FRotator(35.0, -8.0, 0.0), ECk_TweenEasing::OutCubic);

    UPROPERTY()
    FMars_HandSwing_Key Strike = FMars_HandSwing_Key(FVector(14.0, -4.0, -14.0), FRotator(-55.0, 8.0, 0.0), ECk_TweenEasing::InQuad);

    UPROPERTY()
    ECk_TweenEasing RecoverEasing = ECk_TweenEasing::OutCubic;

    // Duration of the strike travel (Windup pose -> Strike pose).
    UPROPERTY()
    float32 StrikeSeconds = 0.12f;

    // Where in the strike travel's time the blow lands, 0..1: the request's ImpactSeconds falls here. With an
    // accelerating Strike easing the hand is still short of the travel's midpoint then, and fastest right after.
    UPROPERTY()
    float32 ImpactFraction = 0.65f;
}

// The swing's phase boundaries, seconds from its start (Make_Timeline).
struct FMars_HandSwing_Timeline
{
    UPROPERTY()
    float32 WindupEnd = 0.0f;

    UPROPERTY()
    float32 StrikeEnd = 0.0f;

    UPROPERTY()
    float32 RecoverEnd = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_HandSwing_Spec
{
    // The node the swing offsets, between the hand node's parent and everything that hangs off the hand (the
    // first-person gloves and the held item). Invalid keeps the ledger only: a body that draws the swing itself reads
    // Get_Pose.
    UPROPERTY()
    FCk_Handle_SceneNode Node;

    FMars_HandSwing_Spec() {}

    FMars_HandSwing_Spec(FCk_Handle_SceneNode InNode)
    {
        Node = InNode;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_HandSwing_Params
{
    UPROPERTY()
    FCk_Handle_SceneNode Node;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_HandSwing_HandleRequests, UMars_Processor_HandSwing_Tick and utils_hand_swing::Add.
struct FMars_Fragment_HandSwing
{
    UPROPERTY()
    EMars_HandSwing_Phase Phase = EMars_HandSwing_Phase::None;

    // Seconds since the swing in flight started.
    UPROPERTY()
    float32 Elapsed = 0.0f;

    // The swing in flight. A cancel rewrites its Strike key to the current pose, so the recovery starts from there.
    UPROPERTY()
    FMars_HandSwing_Arc Arc;

    UPROPERTY()
    FMars_HandSwing_Timeline Timeline;

    // Where the hand was when the swing in flight started (identity from rest; mid-swing for a restart).
    UPROPERTY()
    FTransform StartPose;

    // The current offset, hand space. Identity at rest.
    UPROPERTY()
    FTransform Pose;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_HandSwing_OnPhaseChanged(FCk_Handle_HandSwing InSwing, EMars_HandSwing_Phase InPrevious, EMars_HandSwing_Phase InNew);
event void FMars_Delegate_HandSwing_OnPhaseChanged_MC(FCk_Handle_HandSwing InSwing, EMars_HandSwing_Phase InPrevious, EMars_HandSwing_Phase InNew);

struct FMars_Fragment_HandSwing_Signals
{
    FMars_Delegate_HandSwing_OnPhaseChanged_MC OnPhaseChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Swing Arc so the blow lands ImpactSeconds from now and the hand is back at rest RecoverySeconds after that. A swing
// already in flight restarts from its current pose. The last one in a drain wins. Every field replicates, so the
// character carries the request to the other machines as-is.
struct FMars_Request_HandSwing_Start
{
    UPROPERTY()
    FMars_HandSwing_Arc Arc;

    UPROPERTY()
    float32 ImpactSeconds = 0.15f;

    UPROPERTY()
    float32 RecoverySeconds = 0.35f;

    FMars_Request_HandSwing_Start() {}

    FMars_Request_HandSwing_Start(const FMars_HandSwing_Arc& InArc, float32 InImpactSeconds, float32 InRecoverySeconds)
    {
        Arc = InArc;
        ImpactSeconds = InImpactSeconds;
        RecoverySeconds = InRecoverySeconds;
    }
}

// Abandon the swing in flight: recover to rest from the current pose. Ignored at rest. AngelScript rejects a TArray of
// an empty struct, so it carries one placeholder field.
struct FMars_Request_HandSwing_Cancel
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_HandSwing_Cancel() {}
}

// Drained Cancel -> Start: a start queued with a cancel starts fresh from the cancelled pose.
struct FMars_Fragment_HandSwing_Requests
{
    UPROPERTY()
    TArray<FMars_Request_HandSwing_Cancel> CancelRequests;

    UPROPERTY()
    TArray<FMars_Request_HandSwing_Start> StartRequests;
}
