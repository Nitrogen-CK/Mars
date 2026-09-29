class UMars_Processor_RotateTowards_Update : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_RotateTowards;
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_RotateTowards_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RotateTowards);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_RotateTowards& InState)
    {
        if (ck::Is_NOT_Valid(InState.GoalTargetPoint))
        { return; }

        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_RotateTowards_Params);

        const auto& AxisLocking = Params.AxisLockingSettings;
        if (AxisLocking.LockAxis_X && AxisLocking.LockAxis_Y && AxisLocking.LockAxis_Z)
        { return; }

        auto ThisAsTransform = InHandle.As_Transform();
        const auto CurrentWorldRotation = ThisAsTransform.Get_EntityCurrentRotation();

        auto DesiredWorldRotation = CalculateDesiredRotation(ThisAsTransform, InState.GoalTargetPoint, Params.AxisLockingSettings);
        DesiredWorldRotation = ApplyRangeClamping(ThisAsTransform, DesiredWorldRotation, InState.RangeClampSettings);

        const auto NewWorldRotation = CalculateConstrainedRotation(
            CurrentWorldRotation,
            DesiredWorldRotation,
            Params.TurnRateSettings,
            Params.AxisLockingSettings,
            InDeltaT);

        const float ApplicationTolerance = 0.001f;
        if (CurrentWorldRotation.Equals(NewWorldRotation, ApplicationTolerance) == false)
        {
            ApplyRotation(ThisAsTransform, CurrentWorldRotation, NewWorldRotation, Params.ControllerSettings);
        }

        // Compares the pre-application rotation, so the reached signal lands the frame after the final step.
        CheckAndBroadcastTargetReached(InHandle, InState, CurrentWorldRotation, DesiredWorldRotation, Params.TurnRateSettings.RotationTolerance);
    }

    private void CheckAndBroadcastTargetReached(FCk_Handle InHandle, FMars_Fragment_RotateTowards& InState, const FRotator& InCurrentRotation, const FRotator& InDesiredRotation, float InTolerance)
    {
        const bool IsNowAtTarget = InCurrentRotation.Equals(InDesiredRotation, InTolerance);

        if (IsNowAtTarget && InState.HasReachedTarget == false)
        {
            InState.HasReachedTarget = true;

            if (InHandle.Has_Fragment(FMars_Fragment_RotateTowards_Signals))
            {
                auto RotateTowardsHandle = InHandle.As_RotateTowards();
                InHandle.Get_Fragment(FMars_Fragment_RotateTowards_Signals).OnTargetReached.Broadcast(RotateTowardsHandle);
            }
        }
        else if (IsNowAtTarget == false && InState.HasReachedTarget)
        {
            InState.HasReachedTarget = false;
        }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Rotation Calculation
    //--------------------------------------------------------------------------------------------------------------------------

    private FRotator CalculateDesiredRotation(FCk_Handle_Transform InHandle, FCk_Handle_Transform InGoalTargetPoint, const FMars_RotateTowards_AxisLockingSettings& AxisLocking)
    {
        const auto CurrentRotation = InHandle.Get_EntityCurrentRotation();
        const auto StartLoc = InHandle.Get_EntityCurrentLocation();
        const auto TargetLoc = InGoalTargetPoint.Get_EntityCurrentLocation();

        auto DesiredRotation = Math::FindLookAtRotation(StartLoc, TargetLoc);

        if (AxisLocking.LockAxis_X)
        {
            DesiredRotation.Roll = CurrentRotation.Roll;
        }

        if (AxisLocking.LockAxis_Y)
        {
            DesiredRotation.Pitch = CurrentRotation.Pitch;
        }

        if (AxisLocking.LockAxis_Z)
        {
            DesiredRotation.Yaw = CurrentRotation.Yaw;
        }

        return DesiredRotation;
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Range Clamping
    //--------------------------------------------------------------------------------------------------------------------------

    private FRotator ApplyRangeClamping(
        FCk_Handle_Transform InEntityTransform,
        const FRotator& InDesiredRotation,
        const FMars_RotateTowards_RangeClampSettings& InRangeSettings)
    {
        if (InRangeSettings.CanApplyRangeClamping() == false)
        { return InDesiredRotation; }

        const auto RestRotation = ComputeRestRotation(InEntityTransform, InRangeSettings.RestReferencePoint);
        auto ClampedRotation = InDesiredRotation;

        if (InRangeSettings.YawRange.IsSet())
        {
            ClampedRotation.Yaw = ClampAngleToRange(
                InDesiredRotation.Yaw,
                RestRotation.Yaw,
                InRangeSettings.YawRange.GetValue());
        }

        if (InRangeSettings.PitchRange.IsSet())
        {
            ClampedRotation.Pitch = ClampAngleToRange(
                InDesiredRotation.Pitch,
                RestRotation.Pitch,
                InRangeSettings.PitchRange.GetValue());
        }

        if (InRangeSettings.RollRange.IsSet())
        {
            ClampedRotation.Roll = ClampAngleToRange(
                InDesiredRotation.Roll,
                RestRotation.Roll,
                InRangeSettings.RollRange.GetValue());
        }

        return ClampedRotation;
    }

    private FRotator ComputeRestRotation(FCk_Handle_Transform InEntityTransform, FCk_Handle_Transform InRestReferencePoint)
    {
        const auto EntityLocation = InEntityTransform.Get_EntityCurrentLocation();
        const auto RestPointLocation = InRestReferencePoint.Get_EntityCurrentLocation();
        return Math::FindLookAtRotation(EntityLocation, RestPointLocation);
    }

    private float ClampAngleToRange(float InDesiredAngle, float InRestAngle, const FCk_FloatRange& InRange)
    {
        return Math::ClampAngleToRange(InDesiredAngle, InRestAngle, InRange);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Turn Rate Interpolation
    //--------------------------------------------------------------------------------------------------------------------------

    private FRotator CalculateConstrainedRotation(
        const FRotator& CurrentRotation,
        const FRotator& DesiredRotation,
        const FMars_RotateTowards_TurnRateSettings& TurnRateSettings,
        const FMars_RotateTowards_AxisLockingSettings& AxisLocking,
        FCk_Time InDeltaT)
    {
        if (TurnRateSettings.UseInstantRotation)
        { return DesiredRotation; }

        auto NewRotation = CurrentRotation;
        const auto DeltaTime = InDeltaT.Get_Seconds();

        NewRotation.Roll = CalculateAxisRotation(
            CurrentRotation.Roll,
            DesiredRotation.Roll,
            TurnRateSettings.TurnRate_Roll,
            TurnRateSettings.RotationTolerance,
            DeltaTime,
            AxisLocking.LockAxis_X);

        NewRotation.Pitch = CalculateAxisRotation(
            CurrentRotation.Pitch,
            DesiredRotation.Pitch,
            TurnRateSettings.TurnRate_Pitch,
            TurnRateSettings.RotationTolerance,
            DeltaTime,
            AxisLocking.LockAxis_Y);

        NewRotation.Yaw = CalculateAxisRotation(
            CurrentRotation.Yaw,
            DesiredRotation.Yaw,
            TurnRateSettings.TurnRate_Yaw,
            TurnRateSettings.RotationTolerance,
            DeltaTime,
            AxisLocking.LockAxis_Z);

        return NewRotation;
    }

    private float CalculateAxisRotation(
        float CurrentAngle,
        float DesiredAngle,
        float TurnRate,
        float Tolerance,
        float DeltaTime,
        bool IsLocked)
    {
        if (IsLocked)
        { return CurrentAngle; }

        return Math::InterpolateAngle(CurrentAngle, DesiredAngle, TurnRate, Tolerance, DeltaTime);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Rotation Application
    //--------------------------------------------------------------------------------------------------------------------------

    private void ApplyRotation(
        FCk_Handle_Transform InTransformHandle,
        const FRotator& CurrentWorldRotation,
        const FRotator& NewWorldRotation,
        const FMars_RotateTowards_ControllerSettings& ControllerSettings)
    {
        auto MaybeValidOwningPawn = Cast<APawn>(InTransformHandle.TryGet_EntityOwningActor());
        if (ck::IsValid(MaybeValidOwningPawn))
        {
            ApplyRotationToPawn(MaybeValidOwningPawn, NewWorldRotation, ControllerSettings);
            return;
        }

        if (utils_scene_node::Has(InTransformHandle))
        {
            ApplyRotationToSceneNode(InTransformHandle.As_SceneNode(), CurrentWorldRotation, NewWorldRotation);
            return;
        }

        utils_transform::Request_SetRotation(InTransformHandle, NewWorldRotation);
    }

    // Composes the world-space delta onto the local offset, so the node turns by the same amount under any parent.
    private void ApplyRotationToSceneNode(
        FCk_Handle_SceneNode InSceneNodeHandle,
        const FRotator& CurrentWorldRotation,
        const FRotator& NewWorldRotation)
    {
        const auto CurrentOffset = InSceneNodeHandle.Get_Offset();
        const auto CurrentLocalRotation = CurrentOffset.GetRotation();

        const auto CurrentWorldQuat = FQuat(CurrentWorldRotation);
        const auto NewWorldQuat = FQuat(NewWorldRotation);
        const auto WorldDelta = CurrentWorldQuat.Inverse() * NewWorldQuat;

        const auto NewLocalQuat = CurrentLocalRotation * WorldDelta;

        const auto UpdateRequest = FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(
            NewLocalQuat,
            CurrentOffset.GetLocation(),
            CurrentOffset.GetScale3D()));

        utils_scene_node::Request_UpdateOffset(InSceneNodeHandle, UpdateRequest);
    }

    private void ApplyRotationToPawn(
        APawn& Pawn,
        const FRotator& NewRotation,
        const FMars_RotateTowards_ControllerSettings& ControllerSettings)
    {
        Pawn.SetActorRotation(NewRotation);
        Pawn.bUseControllerRotationRoll = ControllerSettings.UseControllerRotation_Roll;
        Pawn.bUseControllerRotationPitch = ControllerSettings.UseControllerRotation_Pitch;
        Pawn.bUseControllerRotationYaw = ControllerSettings.UseControllerRotation_Yaw;

        if (ControllerSettings.ApplyRotationToController)
        {
            auto MaybeValidController = Pawn.GetController();
            if (ck::IsValid(MaybeValidController))
            {
                MaybeValidController.SetControlRotation(NewRotation);
            }
        }
    }
}
