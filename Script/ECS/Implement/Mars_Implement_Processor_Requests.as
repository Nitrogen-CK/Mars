// Drains Reset -> SetDrive -> SetLiftTarget -> SetTiltTarget -> SetSlideTarget -> Follow -> Look -> Settle. Reset
// levels the implement, zeroes the lift, the slide (and their targets) and the orbit, idles it and makes it steer
// itself (Own); SetDrive, SetLiftTarget, SetTiltTarget and SetSlideTarget are last-wins (a lift target only for a
// Commanded lift, a slide target only for a Commanded slide: any other is a caller's defect, ensured; tilt targets
// whatever the axes); Follow is last-wins and makes it Followed: the command's drive and targets (clamped as the
// requests clamp them), a Kick lift's velocity gains the command's rise in kick total, and the orbit phase is re-seated
// when it drifted; looks only collect into the pending look while Driven and Own; Settle puts every eased value at its
// target and writes the node there. The drain collects and the Tick measures: a dirty-marked processor is also pumped
// with a zero DeltaT, so nothing here integrates over time (a followed kick is a velocity step, as a look's is).
// Every copy runs it alike: with authority the kernel feeds it, without it the kernel's mirror sends the Follow.
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
        const auto HasSettle = InRequests.SettleRequests.Num() > 0;
        TArray<FMars_Request_Implement_SetDrive> SetDriveRequests = InRequests.SetDriveRequests;
        TArray<FMars_Request_Implement_SetLiftTarget> SetLiftTargetRequests = InRequests.SetLiftTargetRequests;
        TArray<FMars_Request_Implement_SetTiltTarget> SetTiltTargetRequests = InRequests.SetTiltTargetRequests;
        TArray<FMars_Request_Implement_SetSlideTarget> SetSlideTargetRequests = InRequests.SetSlideTargetRequests;
        TArray<FMars_Request_Implement_Follow> FollowRequests = InRequests.FollowRequests;
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

        if (FollowRequests.Num() > 0)
        { Apply_Follow(Self, InState, FollowRequests.Last().Command); }

        if (InState.Drive == EMars_Implement_Drive::Driven && InState.Steering == EMars_Implement_Steering::Own)
        {
            for (const auto& Request : LookRequests)
            { Collect_Look(InState, Request); }
        }

        if (HasSettle)
        { Apply_Settle(Self, InState); }

        const auto NewDrive = InState.Drive;
        if (NewDrive == StartDrive || Self.Has_Fragment(FMars_Fragment_Implement_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Implement_Signals).OnDriveChanged.Broadcast(Self, NewDrive);
    }

    // The look joins the pending look; its seconds join the pending seconds only while every look collected since the Tick
    // last ran carried them (the first look sets them, one without seconds unsets them for the rest of the frame).
    private void Collect_Look(FMars_Fragment_Implement& InState, const FMars_Request_Implement_Look& InRequest)
    {
        const auto IsFirst = InState.PendingLook.IsZero() && InState.PendingLookSeconds.IsSet() == false;
        InState.PendingLook += FVector(InRequest.LookDelta.X, InRequest.LookDelta.Y, 0.0);

        if (InRequest.Seconds.IsSet() == false)
        {
            InState.PendingLookSeconds.Reset();
            return;
        }

        if (IsFirst)
        {
            InState.PendingLookSeconds = InRequest.Seconds;
            return;
        }

        if (InState.PendingLookSeconds.IsSet())
        { InState.PendingLookSeconds = TOptional<float32>(InState.PendingLookSeconds.GetValue() + InRequest.Seconds.GetValue()); }
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
        InState.PendingLookSeconds.Reset();
        InState.OrbitPhase = 0.0f;
        InState.OrbitAlpha = 0.0f;
        InState.Steering = EMars_Implement_Steering::Own;
        InState.FollowedKickTotal.Reset();

        utils_implement::Apply_Pose(InImplement, InState);
        InState.WrittenPitch = 0.0f;
        InState.WrittenRoll = 0.0f;
        InState.WrittenYaw = 0.0f;
        InState.WrittenLift = 0.0f;
        InState.WrittenSlide = FVector2D::ZeroVector;
        InState.WrittenOrbit = FVector::ZeroVector;
    }

    // The shown pose at its targets at once and the node written there, as Reset writes it: nothing eases toward a
    // target this drain or an earlier one set. A None lift's target is its rest; a Kick lift's is its rest too.
    private void Apply_Settle(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState)
    {
        InState.Pitch = InState.TargetPitch;
        InState.Roll = InState.TargetRoll;
        InState.Yaw = InState.TargetYaw;
        InState.Lift = InState.TargetLift;
        InState.LiftVelocity = 0.0f;
        InState.Slide = InState.TargetSlide;
        InState.SlideVelocity = FVector2D::ZeroVector;
        InState.OrbitAlpha = InState.Drive == EMars_Implement_Drive::Driven ? 1.0f : 0.0f;

        utils_implement::Apply_Pose(InImplement, InState);
        InState.WrittenPitch = InState.Pitch;
        InState.WrittenRoll = InState.Roll;
        InState.WrittenYaw = InState.Yaw;
        InState.WrittenLift = InState.Lift;
        InState.WrittenSlide = InState.Slide;
        InState.WrittenOrbit = utils_implement::Make_OrbitOffset(InImplement.Get_Spec().Orbit, InState);
    }

    // Only a Commanded lift has a target to set (any other is the caller's defect); the spring (the Tick) carries the node
    // there.
    private void Apply_SetLiftTarget(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState, float32 InLift)
    {
        const auto& LiftSpec = InImplement.Get_Spec().Lift;
        if (ck::EnsureIfNot(LiftSpec.Mode == EMars_Implement_LiftMode::Commanded, f"[Implement] [{InImplement.ToString()}] got a lift target {InLift}: its lift is {LiftSpec.Mode :n}, not Commanded"))
        { return; }

        InState.TargetLift = Math::Clamp(InLift, LiftSpec.MinLift, LiftSpec.MaxLift);
    }

    // The tilt targets, each clamped to MaxTiltDegrees; the Tick tracks them at the bounded rate (and relaxes them per the
    // spec's Relax).
    private void Apply_SetTiltTarget(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState, FRotator InTilt)
    {
        const auto MaxTilt = InImplement.Get_Spec().Tilt.MaxTiltDegrees;
        InState.TargetPitch = Math::Clamp(float32(InTilt.Pitch), -MaxTilt, MaxTilt);
        InState.TargetYaw = Math::Clamp(float32(InTilt.Yaw), -MaxTilt, MaxTilt);
        InState.TargetRoll = Math::Clamp(float32(InTilt.Roll), -MaxTilt, MaxTilt);
    }

    // Only a Commanded slide has a target to set (any other is the caller's defect); it clamps to the spec's box or disc and
    // the spring (the Tick) carries the node there.
    private void Apply_SetSlideTarget(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState, FVector2D InSlide)
    {
        const auto& SlideSpec = InImplement.Get_Spec().Slide;
        if (ck::EnsureIfNot(SlideSpec.Mode == EMars_Implement_SlideMode::Commanded, f"[Implement] [{InImplement.ToString()}] got a slide target {InSlide}: its slide is {SlideSpec.Mode :n}, not Commanded"))
        { return; }

        InState.TargetSlide = utils_implement::Clamp_SlideTarget(SlideSpec, InSlide);
    }

    // The command steers from now on: its drive, its tilt targets (clamped as SetTiltTarget clamps), a Commanded lift's
    // target, the slide target where the slide has a reach (clamped to it), a Kick lift's velocity by the rise in kick total
    // since the last command (the first only records it), and the orbit phase re-seated past k_OrbitResyncRadians of drift.
    private void Apply_Follow(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState, const FMars_Implement_Command& InCommand)
    {
        const auto Spec = InImplement.Get_Spec();
        InState.Steering = EMars_Implement_Steering::Followed;
        InState.Drive = InCommand.Drive;
        Apply_SetTiltTarget(InImplement, InState, InCommand.Tilt);

        if (Spec.Lift.Mode == EMars_Implement_LiftMode::Commanded)
        { InState.TargetLift = Math::Clamp(InCommand.Lift, Spec.Lift.MinLift, Spec.Lift.MaxLift); }

        if (Spec.Slide.Radius > 0.0f || Spec.Slide.HalfExtentX > 0.0f || Spec.Slide.HalfExtentY > 0.0f)
        { InState.TargetSlide = utils_implement::Clamp_SlideTarget(Spec.Slide, InCommand.Slide); }

        if (Spec.Lift.Mode == EMars_Implement_LiftMode::Kick)
        {
            if (InState.FollowedKickTotal.IsSet())
            {
                const auto Rise = InCommand.KickTotal - InState.FollowedKickTotal.GetValue();
                if (Rise > 0.0f)
                { InState.LiftVelocity += Rise * Spec.Lift.Gain; }
            }

            InState.FollowedKickTotal = TOptional<float32>(InCommand.KickTotal);
        }

        if (Math::Abs(utils_implement::Get_PhaseDifference(InCommand.OrbitPhase, InState.OrbitPhase)) > utils_implement::k_OrbitResyncRadians)
        { InState.OrbitPhase = InCommand.OrbitPhase; }
    }
}
