//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_SurfaceNavigatorHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_SurfaceNavigator";
    RequiredFragments.Add(FMars_Feature_SurfaceNavigator);
    Description = "Goal-to-steering navigation for a SurfaceMotion body: a path from the nav surface or a straight line, waypoint following and a stuck watchdog";
}

struct FMars_Feature_SurfaceNavigator {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_SurfaceNavigator_Status
{
    Idle,
    Moving,
    Arrived,
    Failed
}

enum EMars_SurfaceNavigator_FailReason
{
    None,
    // The provider answered NoSurface or Blocked for the requested goal.
    NoPath,
    // The body made less than StuckDistance of progress for StuckSeconds while moving.
    Stuck
}

enum EMars_SurfaceNavigator_PathMode
{
    // The nav surface answered a route.
    Provider,
    // No provider covers the start (NoProvider) or its ground is not built yet (Unbuilt): one waypoint, the goal.
    StraightLine
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_SurfaceNavigator_Spec
{
    // The steering speed (SurfaceMotion clamps it to its own MaxSpeed).
    UPROPERTY()
    float32 Speed = 120.0f;

    // A waypoint counts as reached within this horizontal distance.
    UPROPERTY()
    float32 AcceptanceRadius = 40.0f;

    // Moving with less than StuckDistance of horizontal progress for this long fails the move as Stuck.
    UPROPERTY()
    float32 StuckSeconds = 2.0f;

    UPROPERTY()
    float32 StuckDistance = 15.0f;

    // The clearance a provider route keeps from walls.
    UPROPERTY()
    float32 AgentRadius = 40.0f;

    FMars_SurfaceNavigator_Spec() {}

    FMars_SurfaceNavigator_Spec(float32 InSpeed, float32 InAcceptanceRadius)
    {
        Speed = InSpeed;
        AcceptanceRadius = InAcceptanceRadius;
    }

    FMars_SurfaceNavigator_Spec(float32 InSpeed, float32 InAcceptanceRadius, float32 InStuckSeconds, float32 InStuckDistance,
                                float32 InAgentRadius)
    {
        Speed = InSpeed;
        AcceptanceRadius = InAcceptanceRadius;
        StuckSeconds = InStuckSeconds;
        StuckDistance = InStuckDistance;
        AgentRadius = InAgentRadius;
    }
}

mixin FMars_Validation Validate(const FMars_SurfaceNavigator_Spec& Self)
{
    if (Self.Speed <= 0.0f)
    { return FMars_Validation(f"SurfaceNavigator has a non-positive Speed [{Self.Speed}]"); }

    if (Self.AcceptanceRadius <= 0.0f)
    { return FMars_Validation(f"SurfaceNavigator has a non-positive AcceptanceRadius [{Self.AcceptanceRadius}]"); }

    if (Self.StuckSeconds <= 0.0f || Self.StuckDistance < 0.0f)
    { return FMars_Validation(f"SurfaceNavigator has a non-positive StuckSeconds [{Self.StuckSeconds}] or a negative StuckDistance [{Self.StuckDistance}]"); }

    if (Self.AgentRadius < 0.0f)
    { return FMars_Validation(f"SurfaceNavigator has a negative AgentRadius [{Self.AgentRadius}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_SurfaceNavigator_Params
{
    UPROPERTY()
    FMars_SurfaceNavigator_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The move being followed: where to, how the waypoints were made and which one is next.
struct FMars_SurfaceNavigator_Route
{
    UPROPERTY()
    FVector Goal = FVector::ZeroVector;

    UPROPERTY()
    EMars_SurfaceNavigator_PathMode PathMode = EMars_SurfaceNavigator_PathMode::StraightLine;

    // The provider's route (the goal appended when it stops short) or just the goal.
    UPROPERTY()
    TArray<FVector> Waypoints;

    UPROPERTY()
    int32 WaypointIndex = 0;
}

// The stuck watchdog: the body has to leave StuckAnchor by StuckDistance before StuckTimer passes StuckSeconds.
struct FMars_SurfaceNavigator_Watchdog
{
    UPROPERTY()
    float32 StuckTimer = 0.0f;

    UPROPERTY()
    FVector StuckAnchor = FVector::ZeroVector;
}

// What the navigator last asked SurfaceMotion for. A steering request is sticky (SurfaceMotion keeps the direction and
// speed until the next request), so the navigator re-steers only when this changes.
struct FMars_SurfaceNavigator_Steering
{
    UPROPERTY()
    FVector Direction = FVector::ZeroVector;

    // Unset: nothing steered since the move began, so the next steer always goes out.
    UPROPERTY()
    TOptional<float32> Speed;
}

// Written only by the navigator's two processors (and composed by Add). The navigator never writes the transform:
// SurfaceMotion is the sole mover.
struct FMars_Fragment_SurfaceNavigator
{
    UPROPERTY()
    FCk_Handle_SurfaceMotion Motion;

    UPROPERTY()
    EMars_SurfaceNavigator_Status Status = EMars_SurfaceNavigator_Status::Idle;

    UPROPERTY()
    EMars_SurfaceNavigator_FailReason FailReason = EMars_SurfaceNavigator_FailReason::None;

    UPROPERTY()
    FMars_SurfaceNavigator_Route Route;

    UPROPERTY()
    FMars_SurfaceNavigator_Watchdog Watchdog;

    UPROPERTY()
    FMars_SurfaceNavigator_Steering Steering;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Once per move that reached its last waypoint; the navigator is already Arrived and its steering cleared.
delegate void FMars_Delegate_SurfaceNavigator_OnArrived(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal);
event void FMars_Delegate_SurfaceNavigator_OnArrived_MC(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal);

// Once per failed move (no path, or stuck); the navigator is already Failed and its steering cleared.
delegate void FMars_Delegate_SurfaceNavigator_OnFailed(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal, EMars_SurfaceNavigator_FailReason InReason);
event void FMars_Delegate_SurfaceNavigator_OnFailed_MC(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal, EMars_SurfaceNavigator_FailReason InReason);

struct FMars_Fragment_SurfaceNavigator_Signals
{
    FMars_Delegate_SurfaceNavigator_OnArrived_MC OnArrived;
    FMars_Delegate_SurfaceNavigator_OnFailed_MC OnFailed;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Clears the steering and returns to Idle without a signal, whatever the navigator was doing.
struct FMars_Request_SurfaceNavigator_Stop
{
    // Placeholder: AngelScript rejects a TArray of an empty struct.
    UPROPERTY()
    bool Requested = true;
}

// Replaces any move in progress. The path is resolved once, when the request drains.
struct FMars_Request_SurfaceNavigator_MoveTo
{
    UPROPERTY()
    FVector Goal = FVector::ZeroVector;

    FMars_Request_SurfaceNavigator_MoveTo() {}

    FMars_Request_SurfaceNavigator_MoveTo(FVector InGoal)
    {
        Goal = InGoal;
    }
}

// Request_Stop drops every MoveTo queued before it, so applying Stop and then the last MoveTo is arrival order: a Stop
// after a MoveTo in one frame stops, a MoveTo after a Stop moves.
struct FMars_Fragment_SurfaceNavigator_Requests
{
    UPROPERTY()
    TArray<FMars_Request_SurfaceNavigator_Stop> StopRequests;

    UPROPERTY()
    TArray<FMars_Request_SurfaceNavigator_MoveTo> MoveToRequests;
}
