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

enum EMars_Mover_Pose
{
    Start,
    End
}

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

    // The pose the mover starts at, and its first target.
    UPROPERTY()
    EMars_Mover_Pose StartPose = EMars_Mover_Pose::Start;
}

mixin FMars_Validation Validate(const FMars_Mover_Spec& Self)
{
    if (Self.Duration < 0.0f)
    { return FMars_Validation(f"Duration [{Self.Duration}] must not be negative"); }

    return FMars_Validation();
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
    // The pose the mover is going to (or is at), not the current pose.
    UPROPERTY()
    EMars_Mover_Pose Target = EMars_Mover_Pose::Start;

    // 0 at the start pose, 1 at the end pose.
    UPROPERTY()
    float32 Alpha = 0.0f;

    UPROPERTY()
    FCk_Handle_Tween Tween;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Mover_OnTargetChanged(FCk_Handle_Mover InMover, EMars_Mover_Pose InTarget);
event void FMars_Delegate_Mover_OnTargetChanged_MC(FCk_Handle_Mover InMover, EMars_Mover_Pose InTarget);

delegate void FMars_Delegate_Mover_OnArrived(FCk_Handle_Mover InMover, EMars_Mover_Pose InPose);
event void FMars_Delegate_Mover_OnArrived_MC(FCk_Handle_Mover InMover, EMars_Mover_Pose InPose);

struct FMars_Fragment_Mover_Signals
{
    FMars_Delegate_Mover_OnTargetChanged_MC OnTargetChanged;
    FMars_Delegate_Mover_OnArrived_MC OnArrived;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// To the current target, it acts as a Settle: it tweens back to that pose when a scrub left the handle part way.
struct FMars_Request_Mover_MoveTo
{
    UPROPERTY()
    EMars_Mover_Pose Target = EMars_Mover_Pose::Start;

    FMars_Request_Mover_MoveTo() {}

    FMars_Request_Mover_MoveTo(EMars_Mover_Pose InTarget)
    {
        Target = InTarget;
    }
}

// Puts the handle at an alpha right now, stopping any tween. The target is untouched; a later Settle (or a MoveTo, to
// either pose) tweens from here.
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

// Tweens from the current alpha back to the target pose (after a scrub left the handle part way); nothing when the
// handle already rests there.
struct FMars_Request_Mover_Settle
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mover_Settle() {}
}

// MoveTo and Scrub are absolute: the latest of each kind wins. Drained Scrub -> MoveTo -> Settle, so a tween requested in
// the same frame as a scrub starts from the scrubbed alpha.
struct FMars_Fragment_Mover_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Mover_MoveTo> MoveToRequests;

    UPROPERTY()
    TArray<FMars_Request_Mover_Scrub> ScrubRequests;

    UPROPERTY()
    TArray<FMars_Request_Mover_Settle> SettleRequests;
}
