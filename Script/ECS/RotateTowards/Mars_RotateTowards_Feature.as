//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_RotateTowardsHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_RotateTowards";
    RequiredFragments.Add(FMars_Feature_RotateTowards);
    Description = "A transform entity that turns to face a target transform at a limited rate, optionally clamped to a range";
}
struct FMars_Feature_RotateTowards {}

//--------------------------------------------------------------------------------------------------------------------------
// Settings
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_RotateTowards_ControllerSettings
{
    UPROPERTY()
    bool UseControllerRotation_Roll = false;

    UPROPERTY()
    bool UseControllerRotation_Pitch = false;

    UPROPERTY()
    bool UseControllerRotation_Yaw = false;

    UPROPERTY()
    bool ApplyRotationToController = false;
}

struct FMars_RotateTowards_AxisLockingSettings
{
    UPROPERTY()
    bool LockAxis_X = false;

    UPROPERTY()
    bool LockAxis_Y = false;

    UPROPERTY()
    bool LockAxis_Z = false;
}

struct FMars_RotateTowards_TurnRateSettings
{
    UPROPERTY()
    float TurnRate_Roll = 180.0f;

    UPROPERTY()
    float TurnRate_Pitch = 180.0f;

    UPROPERTY()
    float TurnRate_Yaw = 180.0f;

    UPROPERTY()
    bool UseInstantRotation = false;

    UPROPERTY()
    float RotationTolerance = 1.0f;
}

// Ranges are relative to the rest rotation, the look-at from the entity to RestReferencePoint; clamping is disabled
// until RestReferencePoint is valid.
struct FMars_RotateTowards_RangeClampSettings
{
    UPROPERTY()
    TOptional<FCk_FloatRange> YawRange;

    UPROPERTY()
    TOptional<FCk_FloatRange> PitchRange;

    UPROPERTY()
    TOptional<FCk_FloatRange> RollRange;

    UPROPERTY()
    FCk_Handle_Transform RestReferencePoint;

    bool HasAnyRangeConstraint() const
    {
        return YawRange.IsSet() || PitchRange.IsSet() || RollRange.IsSet();
    }

    bool CanApplyRangeClamping() const
    {
        return HasAnyRangeConstraint() && ck::IsValid(RestReferencePoint);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_RotateTowards_Spec
{
    UPROPERTY()
    FCk_Handle_Transform GoalTargetPoint;

    UPROPERTY()
    FMars_RotateTowards_ControllerSettings ControllerSettings;

    UPROPERTY()
    FMars_RotateTowards_TurnRateSettings TurnRateSettings;

    UPROPERTY()
    FMars_RotateTowards_AxisLockingSettings AxisLockingSettings;

    UPROPERTY()
    FMars_RotateTowards_RangeClampSettings RangeClampSettings;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_RotateTowards_Params
{
    UPROPERTY()
    FMars_RotateTowards_ControllerSettings ControllerSettings;

    UPROPERTY()
    FMars_RotateTowards_TurnRateSettings TurnRateSettings;

    UPROPERTY()
    FMars_RotateTowards_AxisLockingSettings AxisLockingSettings;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_RotateTowards
{
    UPROPERTY()
    FCk_Handle_Transform GoalTargetPoint;

    UPROPERTY()
    FMars_RotateTowards_RangeClampSettings RangeClampSettings;

    UPROPERTY()
    bool HasReachedTarget = false;

    UPROPERTY()
    FCk_Handle_Transform PreviousTarget;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_RotateTowards_OnTargetChanged(FCk_Handle_RotateTowards InRotateTowards, FCk_Handle_Transform InNewTarget, FCk_Handle_Transform InPreviousTarget);
event void FMars_Delegate_RotateTowards_OnTargetChanged_MC(FCk_Handle_RotateTowards InRotateTowards, FCk_Handle_Transform InNewTarget, FCk_Handle_Transform InPreviousTarget);

delegate void FMars_Delegate_RotateTowards_OnTargetReached(FCk_Handle_RotateTowards InRotateTowards);
event void FMars_Delegate_RotateTowards_OnTargetReached_MC(FCk_Handle_RotateTowards InRotateTowards);

delegate void FMars_Delegate_RotateTowards_OnTargetCleared(FCk_Handle_RotateTowards InRotateTowards, FCk_Handle_Transform InPreviousTarget);
event void FMars_Delegate_RotateTowards_OnTargetCleared_MC(FCk_Handle_RotateTowards InRotateTowards, FCk_Handle_Transform InPreviousTarget);

struct FMars_Fragment_RotateTowards_Signals
{
    FMars_Delegate_RotateTowards_OnTargetChanged_MC OnTargetChanged;
    FMars_Delegate_RotateTowards_OnTargetReached_MC OnTargetReached;
    FMars_Delegate_RotateTowards_OnTargetCleared_MC OnTargetCleared;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_RotateTowards_UpdateTarget
{
    UPROPERTY()
    FCk_Handle_Transform NewTarget;

    FMars_Request_RotateTowards_UpdateTarget(FCk_Handle_Transform InNewTarget)
    {
        NewTarget = InNewTarget;
    }
}

struct FMars_Request_RotateTowards_SetRestReferencePoint
{
    UPROPERTY()
    FCk_Handle_Transform RestReferencePoint;

    FMars_Request_RotateTowards_SetRestReferencePoint(FCk_Handle_Transform InRestReferencePoint)
    {
        RestReferencePoint = InRestReferencePoint;
    }
}

struct FMars_Request_RotateTowards_SetYawRange
{
    UPROPERTY()
    FCk_FloatRange YawRange;

    FMars_Request_RotateTowards_SetYawRange(FCk_FloatRange InYawRange)
    {
        YawRange = InYawRange;
    }
}

struct FMars_Request_RotateTowards_SetPitchRange
{
    UPROPERTY()
    FCk_FloatRange PitchRange;

    FMars_Request_RotateTowards_SetPitchRange(FCk_FloatRange InPitchRange)
    {
        PitchRange = InPitchRange;
    }
}

struct FMars_Request_RotateTowards_SetRollRange
{
    UPROPERTY()
    FCk_FloatRange RollRange;

    FMars_Request_RotateTowards_SetRollRange(FCk_FloatRange InRollRange)
    {
        RollRange = InRollRange;
    }
}

// Each slot is latest-wins; within one pass UpdateTarget applies before ClearTarget.
struct FMars_Fragment_RotateTowards_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_RotateTowards_UpdateTarget> UpdateTarget;

    UPROPERTY()
    bool ClearTarget = false;

    UPROPERTY()
    TOptional<FMars_Request_RotateTowards_SetRestReferencePoint> SetRestReferencePoint;

    UPROPERTY()
    TOptional<FMars_Request_RotateTowards_SetYawRange> SetYawRange;

    UPROPERTY()
    TOptional<FMars_Request_RotateTowards_SetPitchRange> SetPitchRange;

    UPROPERTY()
    TOptional<FMars_Request_RotateTowards_SetRollRange> SetRollRange;
}
