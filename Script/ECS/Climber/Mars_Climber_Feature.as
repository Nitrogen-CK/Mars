//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_ClimberHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Climber";
    RequiredFragments.Add(FMars_Feature_Climber);
    Description = "An entity that can climb ladders: the ladders on offer, the one being climbed and how far up (lives on the player)";
}
struct FMars_Feature_Climber {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// A property of the climber, not the ladder: the player composes it from its character config.
struct FMars_Climber_Spec
{
    // uu/s along a ladder's climb line.
    UPROPERTY()
    float32 ClimbSpeed = 220.0f;

    FMars_Climber_Spec() {}

    FMars_Climber_Spec(float32 InClimbSpeed)
    {
        ClimbSpeed = InClimbSpeed;
    }
}

// A non-positive speed never moves along the line.
mixin FMars_Validation Validate(const FMars_Climber_Spec& Self)
{
    if (Self.ClimbSpeed <= 0.0f)
    { return FMars_Validation(f"Climber has a non-positive ClimbSpeed [{Self.ClimbSpeed}]"); }

    return FMars_Validation();
}

// How a climb ended. Top: topped out onto the platform; Bottom: stepped off at the foot; Jump: jumped off away from the
// plane; Lost: the ladder died under the climber, or the climber's locomotion left the climb.
enum EMars_Climber_Dismount
{
    Top,
    Bottom,
    Jump,
    Lost
}

// A ladder zone the climber stands in.
struct FMars_Climber_Candidate
{
    UPROPERTY()
    FCk_Handle_Ladder Ladder;

    UPROPERTY()
    EMars_Ladder_Zone Zone = EMars_Ladder_Zone::Front;

    FMars_Climber_Candidate() {}

    FMars_Climber_Candidate(FCk_Handle_Ladder InLadder, EMars_Ladder_Zone InZone)
    {
        Ladder = InLadder;
        Zone = InZone;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Climber_Params
{
    UPROPERTY()
    FMars_Climber_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// One climb on one ladder, from the mount to the dismount.
struct FMars_Climber_Climb
{
    UPROPERTY()
    FCk_Handle_Ladder Ladder;

    // 0 foot .. 1 top.
    UPROPERTY()
    float32 Alpha = 0.0f;

    // False after a Top mount until Alpha drops below constants_climber::k_LeftTopAlpha: holding up right after mounting
    // at the top does not top out.
    UPROPERTY()
    bool HasLeftTop = true;

    // This frame's climb input, summed by the request drain; the tick clamps it to [-1, 1], consumes and zeroes it.
    UPROPERTY()
    float32 PendingAxis = 0.0f;
}

// Written only by the two Climber processors. With an owning character, a climb holds it on the ladder's climb line in
// MOVE_Flying; without one (headless) only the model runs. Only the request drain starts and ends a climb.
struct FMars_Fragment_Climber
{
    UPROPERTY()
    TArray<FMars_Climber_Candidate> Candidates;

    // Set while climbing.
    UPROPERTY()
    TOptional<FMars_Climber_Climb> Climb;

    // How the last climb ended; unset before the first one ends.
    UPROPERTY()
    TOptional<EMars_Climber_Dismount> LastDismount;
}

// Present while Climb is set; gates UMars_Processor_Climber_Tick.
struct FMars_Tag_Climber_Climbing {}

namespace constants_climber
{
    // A Top mount re-arms the top-out once the climber is below this alpha.
    const float32 k_LeftTopAlpha = 0.95f;

    // A top-out lifts the capsule this far above the platform so it does not start inside the floor (uu).
    const float64 k_TopOutClearance = 2.0;

    // A jump-off launch: away from the ladder's plane, and up (uu/s).
    const float64 k_JumpAwaySpeed = 300.0;
    const float64 k_JumpUpSpeed = 250.0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Climbing on a mount; NotClimbing on a dismount, with LastDismount already set.
enum EMars_Climber_ClimbState
{
    NotClimbing,
    Climbing
}

delegate void FMars_Delegate_Climber_OnClimbingChanged(FCk_Handle_Climber InClimber, EMars_Climber_ClimbState InClimbState);
event void FMars_Delegate_Climber_OnClimbingChanged_MC(FCk_Handle_Climber InClimber, EMars_Climber_ClimbState InClimbState);

delegate void FMars_Delegate_Climber_OnCandidatesChanged(FCk_Handle_Climber InClimber);
event void FMars_Delegate_Climber_OnCandidatesChanged_MC(FCk_Handle_Climber InClimber);

struct FMars_Fragment_Climber_Signals
{
    FMars_Delegate_Climber_OnClimbingChanged_MC OnClimbingChanged;
    FMars_Delegate_Climber_OnCandidatesChanged_MC OnCandidatesChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Climber_AddCandidate
{
    UPROPERTY()
    FCk_Handle_Ladder Ladder;

    UPROPERTY()
    EMars_Ladder_Zone Zone = EMars_Ladder_Zone::Front;

    FMars_Request_Climber_AddCandidate() {}

    FMars_Request_Climber_AddCandidate(FCk_Handle_Ladder InLadder, EMars_Ladder_Zone InZone)
    {
        Ladder = InLadder;
        Zone = InZone;
    }
}

struct FMars_Request_Climber_RemoveCandidate
{
    UPROPERTY()
    FCk_Handle_Ladder Ladder;

    UPROPERTY()
    EMars_Ladder_Zone Zone = EMars_Ladder_Zone::Front;

    FMars_Request_Climber_RemoveCandidate() {}

    FMars_Request_Climber_RemoveCandidate(FCk_Handle_Ladder InLadder, EMars_Ladder_Zone InZone)
    {
        Ladder = InLadder;
        Zone = InZone;
    }
}

// Latest wins; ignored while climbing.
struct FMars_Request_Climber_Mount
{
    UPROPERTY()
    FCk_Handle_Ladder Ladder;

    UPROPERTY()
    EMars_Ladder_Zone Zone = EMars_Ladder_Zone::Front;

    FMars_Request_Climber_Mount() {}

    FMars_Request_Climber_Mount(FCk_Handle_Ladder InLadder, EMars_Ladder_Zone InZone)
    {
        Ladder = InLadder;
        Zone = InZone;
    }
}

// Up (+) / down (-) along the line this frame; summed per drain, clamped to [-1, 1] by the tick. Ignored unless climbing.
struct FMars_Request_Climber_Climb
{
    UPROPERTY()
    float32 Axis = 0.0f;

    FMars_Request_Climber_Climb() {}

    FMars_Request_Climber_Climb(float32 InAxis)
    {
        Axis = InAxis;
    }
}

// Latest wins; ignored unless climbing. The tick ends a climb at the top, at the bottom or on a lost ladder with one too.
struct FMars_Request_Climber_Dismount
{
    UPROPERTY()
    EMars_Climber_Dismount Reason = EMars_Climber_Dismount::Jump;

    FMars_Request_Climber_Dismount() {}

    FMars_Request_Climber_Dismount(EMars_Climber_Dismount InReason)
    {
        Reason = InReason;
    }
}

// Applied RemoveCandidate -> AddCandidate -> Dismount -> Mount -> Climb: a dismount and a mount in one frame leave the
// climber on the new ladder, and climb input lands on the climb that frame ends in.
struct FMars_Fragment_Climber_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Climber_RemoveCandidate> RemoveCandidateRequests;

    UPROPERTY()
    TArray<FMars_Request_Climber_AddCandidate> AddCandidateRequests;

    UPROPERTY()
    TArray<FMars_Request_Climber_Dismount> DismountRequests;

    UPROPERTY()
    TArray<FMars_Request_Climber_Mount> MountRequests;

    UPROPERTY()
    TArray<FMars_Request_Climber_Climb> ClimbRequests;
}
