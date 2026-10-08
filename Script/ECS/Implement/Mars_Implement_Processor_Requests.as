// Drains Reset -> SetDrive -> SetLiftTarget -> SetTiltTarget -> SetSlideTarget -> Look. Reset levels the implement, zeroes
// the lift, the slide (and their targets) and the orbit and idles it; SetDrive, SetLiftTarget, SetTiltTarget and
// SetSlideTarget are last-wins (a lift target only for a Commanded lift, a slide target only for a Commanded slide; tilt
// targets whatever the axes); looks only collect into the pending look while Driven. The drain collects and the Tick
// measures: a dirty-marked processor is also pumped with a zero DeltaT, so nothing here integrates over time.
class UMars_Processor_Implement_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Implement_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Implement);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Implement_Requests& InRequests,
                       FMars_Fragment_Implement& InState)
    {
        auto Self = InHandle.As_Implement();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_Implement_SetDrive> SetDriveRequests = InRequests.SetDriveRequests;
        TArray<FMars_Request_Implement_SetLiftTarget> SetLiftTargetRequests = InRequests.SetLiftTargetRequests;
        TArray<FMars_Request_Implement_SetTiltTarget> SetTiltTargetRequests = InRequests.SetTiltTargetRequests;
        TArray<FMars_Request_Implement_SetSlideTarget> SetSlideTargetRequests = InRequests.SetSlideTargetRequests;
        TArray<FMars_Request_Implement_Look> LookRequests = InRequests.LookRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Implement_Requests);

        const auto StartDrive = InState.Drive;

        if (HasReset)
        { Apply_Reset(Self, InState); }

        if (SetDriveRequests.Num() > 0)
        { InState.Drive = SetDriveRequests.Last().Drive; }

        if (SetLiftTargetRequests.Num() > 0)
        { Apply_SetLiftTarget(Self, InState, SetLiftTargetRequests.Last().Lift); }

        if (SetTiltTargetRequests.Num() > 0)
        { Apply_SetTiltTarget(Self, InState, SetTiltTargetRequests.Last().Tilt); }

        if (SetSlideTargetRequests.Num() > 0)
        { Apply_SetSlideTarget(Self, InState, SetSlideTargetRequests.Last().Slide); }

        if (InState.Drive == EMars_Implement_Drive::Driven)
        {
            for (const auto& Request : LookRequests)
            { InState.PendingLook += FVector(Request.LookDelta.X, Request.LookDelta.Y, 0.0); }
        }

        const auto NewDrive = InState.Drive;
        if (NewDrive == StartDrive || Self.Has_Fragment(FMars_Fragment_Implement_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Implement_Signals).OnDriveChanged.Broadcast(Self, NewDrive);
    }

    private void Apply_Reset(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState)
    {
        InState.Drive = EMars_Implement_Drive::Idle;
        InState.Pitch = 0.0f;
        InState.Roll = 0.0f;
        InState.Yaw = 0.0f;
        InState.TargetPitch = 0.0f;
        InState.TargetRoll = 0.0f;
        InState.TargetYaw = 0.0f;
        InState.Lift = 0.0f;
        InState.TargetLift = 0.0f;
        InState.LiftVelocity = 0.0f;
        InState.Slide = FVector2D::ZeroVector;
        InState.TargetSlide = FVector2D::ZeroVector;
        InState.SlideVelocity = FVector2D::ZeroVector;
        InState.PendingLook = FVector::ZeroVector;
        InState.OrbitPhase = 0.0f;
        InState.OrbitAlpha = 0.0f;

        utils_implement::Apply_Pose(InImplement.Get_Node(), InState, FVector::ZeroVector);
        InState.WrittenPitch = 0.0f;
        InState.WrittenRoll = 0.0f;
        InState.WrittenYaw = 0.0f;
        InState.WrittenLift = 0.0f;
        InState.WrittenSlide = FVector2D::ZeroVector;
        InState.WrittenOrbit = FVector::ZeroVector;

        ck::Trace(f"[Implement] [{InImplement.ToString()}] reset: level, no lift, no slide, no orbit, idle");
    }

    // Only a Commanded lift has a target to set; the spring (the Tick) carries the node there.
    private void Apply_SetLiftTarget(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState, float32 InLift)
    {
        const auto& LiftSpec = InImplement.Get_Spec().Lift;
        if (LiftSpec.Mode != EMars_Implement_LiftMode::Commanded)
        {
            ck::Trace(f"[Implement] [{InImplement.ToString()}] lift target {InLift} ignored: the lift is {LiftSpec.Mode :n}, not Commanded");
            return;
        }

        InState.TargetLift = Math::Clamp(InLift, LiftSpec.MinLift, LiftSpec.MaxLift);
        ck::Trace(f"[Implement] [{InImplement.ToString()}] lift target -> {InState.TargetLift :.2}");
    }

    // The tilt targets, each clamped to MaxTiltDegrees; the Tick tracks them at the bounded rate (and relaxes them per the
    // spec's Relax).
    private void Apply_SetTiltTarget(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState, FRotator InTilt)
    {
        const auto MaxTilt = InImplement.Get_Spec().Tilt.MaxTiltDegrees;
        InState.TargetPitch = Math::Clamp(float32(InTilt.Pitch), -MaxTilt, MaxTilt);
        InState.TargetYaw = Math::Clamp(float32(InTilt.Yaw), -MaxTilt, MaxTilt);
        InState.TargetRoll = Math::Clamp(float32(InTilt.Roll), -MaxTilt, MaxTilt);
        ck::Trace(f"[Implement] [{InImplement.ToString()}] tilt target -> P={InState.TargetPitch :.2} Y={InState.TargetYaw :.2} R={InState.TargetRoll :.2}");
    }

    // Only a Commanded slide has a target to set; it clamps to the spec's box or disc and the spring (the Tick) carries the
    // node there.
    private void Apply_SetSlideTarget(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState, FVector2D InSlide)
    {
        const auto& SlideSpec = InImplement.Get_Spec().Slide;
        if (SlideSpec.Mode != EMars_Implement_SlideMode::Commanded)
        {
            ck::Trace(f"[Implement] [{InImplement.ToString()}] slide target {InSlide} ignored: the slide is {SlideSpec.Mode :n}, not Commanded");
            return;
        }

        InState.TargetSlide = utils_implement::Clamp_SlideTarget(SlideSpec, InSlide);
    }
}
