//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_MoverHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Mover";
    RequiredFragments.Add(FMars_Feature_Mover);
    Description = "A scene-node entity that tweens its own offset between a start and an end pose";
}
struct FMars_Feature_Mover {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Poses are the scene node's local offset. Rotation is interpolated per component, so an EndRotation beyond 360
// degrees turns that many times.
struct FMars_Mover_Spec
{
    UPROPERTY()
    FVector StartLocation = FVector::ZeroVector;

    UPROPERTY()
    FRotator StartRotation = FRotator::ZeroRotator;

    UPROPERTY()
    FVector EndLocation = FVector::ZeroVector;

    UPROPERTY()
    FRotator EndRotation = FRotator::ZeroRotator;

    // Time for a full start-to-end move; partial moves take the matching fraction.
    UPROPERTY()
    float32 Duration = 0.5f;

    UPROPERTY()
    ECk_TweenEasing Easing = ECk_TweenEasing::InOutSine;

    UPROPERTY()
    bool StartAtEnd = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Mover_Params
{
    UPROPERTY()
    FVector StartLocation = FVector::ZeroVector;

    UPROPERTY()
    FRotator StartRotation = FRotator::ZeroRotator;

    UPROPERTY()
    FVector EndLocation = FVector::ZeroVector;

    UPROPERTY()
    FRotator EndRotation = FRotator::ZeroRotator;

    UPROPERTY()
    float32 Duration = 0.5f;

    UPROPERTY()
    ECk_TweenEasing Easing = ECk_TweenEasing::InOutSine;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Mover
{
    // The target end, not the current pose.
    UPROPERTY()
    bool AtEnd = false;

    // 0 at the start pose, 1 at the end pose.
    UPROPERTY()
    float32 Alpha = 0.0f;

    UPROPERTY()
    FCk_Handle_Tween Tween;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Mover_OnTargetChanged(FCk_Handle_Mover InMover, bool InAtEnd);
event void FMars_Delegate_Mover_OnTargetChanged_MC(FCk_Handle_Mover InMover, bool InAtEnd);

delegate void FMars_Delegate_Mover_OnArrived(FCk_Handle_Mover InMover, bool InAtEnd);
event void FMars_Delegate_Mover_OnArrived_MC(FCk_Handle_Mover InMover, bool InAtEnd);

struct FMars_Fragment_Mover_Signals
{
    FMars_Delegate_Mover_OnTargetChanged_MC OnTargetChanged;
    FMars_Delegate_Mover_OnArrived_MC OnArrived;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Mover_MoveTo
{
    UPROPERTY()
    bool AtEnd = false;

    FMars_Request_Mover_MoveTo(bool InAtEnd)
    {
        AtEnd = InAtEnd;
    }
}

// Puts the handle at an alpha right now, stopping any tween. AtEnd (the target) is untouched; a later MoveTo or
// Settle tweens from here.
struct FMars_Request_Mover_Scrub
{
    UPROPERTY()
    float32 Alpha = 0.0f;

    FMars_Request_Mover_Scrub() {}

    FMars_Request_Mover_Scrub(float32 InAlpha)
    {
        Alpha = InAlpha;
    }
}

// Tweens from the current alpha back to the AtEnd pose (after a scrub left the handle part way). AngelScript rejects
// an empty struct in a TOptional/TArray, so it carries one placeholder field.
struct FMars_Request_Mover_Settle
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mover_Settle() {}
}

// Absolute and latest-wins: one pending value per kind, overwritten by each new request. Drained Scrub -> MoveTo ->
// Settle, so a tween requested in the same frame as a scrub starts from the scrubbed alpha.
struct FMars_Fragment_Mover_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_Mover_MoveTo> MoveToRequest;

    UPROPERTY()
    TOptional<FMars_Request_Mover_Scrub> ScrubRequest;

    UPROPERTY()
    TOptional<FMars_Request_Mover_Settle> SettleRequest;
}
