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

// How the last climb ended. Top: topped out onto the platform; Bottom: stepped off at the foot; Jump: jumped off away
// from the plane; Lost: the ladder died under the climber.
enum EMars_Climber_Dismount
{
    None,
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
    float32 ClimbSpeed = 220.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written by the two Climber processors. With an owning character, a climb holds it on the ladder's climb line in
// MOVE_Flying; without one (headless) only the model runs.
struct FMars_Fragment_Climber
{
    UPROPERTY()
    TArray<FMars_Climber_Candidate> Candidates;

    // The ladder being climbed; invalid when not climbing.
    UPROPERTY()
    FCk_Handle_Ladder Ladder;

    // 0 foot .. 1 top.
    UPROPERTY()
    float32 Alpha = 0.0f;

    UPROPERTY()
    bool IsClimbing = false;

    UPROPERTY()
    EMars_Ladder_Zone MountZone = EMars_Ladder_Zone::Front;

    // False after a Top mount until Alpha drops below 0.95: holding up right after mounting at the top does not top out.
    UPROPERTY()
    bool HasLeftTop = true;

    UPROPERTY()
    EMars_Climber_Dismount LastDismount = EMars_Climber_Dismount::None;

    // This frame's climb input, summed by the request drain; the tick clamps it to [-1, 1], consumes and zeroes it.
    UPROPERTY()
    float32 PendingAxis = 0.0f;
}

// Present while IsClimbing; gates UMars_Processor_Climber_Tick.
struct FMars_Tag_Climber_Climbing {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Climber_OnClimbingChanged(FCk_Handle_Climber InClimber, bool InClimbing);
event void FMars_Delegate_Climber_OnClimbingChanged_MC(FCk_Handle_Climber InClimber, bool InClimbing);

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

// Latest wins; ignored unless climbing.
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
