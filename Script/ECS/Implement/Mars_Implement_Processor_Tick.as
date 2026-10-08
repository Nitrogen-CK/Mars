// What every step of one Implement's tick reads: the implement, its spec, the frame's real time and the frame's look.
struct FMars_Implement_Frame
{
    FCk_Handle_Implement Implement;
    FMars_Implement_Spec Spec;
    float32 DeltaSeconds = 0.0f;

    // Drained once per frame (degrees; X yaw right+, Y pitch down+); zero unless Driven.
    FVector Look = FVector::ZeroVector;
}

// Every frame: the pending look (dropped unless Driven) steers the tilt targets by the spec's axes, less the fast upward
// excess that kicks a Kick lift; a Commanded lift takes the look's Y as its target instead. The targets relax (always, or
// only while Idle) and clamp, the tilt tracks them at a bounded rate, the lift spring tracks its target, a Look slide's
// target follows the look across the rest plane (a Commanded one's only its requests) and its spring tracks it, the orbit
// eases with the drive and turns, and ONE
// offset write of the node (only when the pose changed) moves the kinematic bodies under it.
class UMars_Processor_Implement_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    // Degrees of tilt or uu of lift.
    private const float32 k_PoseTolerance = 0.001f;
    // The springs integrate (semi-implicit Euler) in steps no longer than this: a long frame (a hitch, a minimized
    // editor at 3 fps) would otherwise blow a 4 Hz spring past its clamp and throw whatever rides the implement.
    private const float32 k_MaxSpringStepSeconds = 1.0f / 60.0f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Implement);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Implement& InState)
    {
        auto Frame = FMars_Implement_Frame();
        Frame.Implement = InHandle.As_Implement();
        Frame.Spec = Frame.Implement.Get_Spec();
        Frame.DeltaSeconds = float32(InDeltaT.Get_Seconds());
        Frame.Look = Take_PendingLook(InState);

        Advance_Tilt(Frame, InState);
        Advance_CommandedLift(Frame, InState);
        Advance_LiftSpring(Frame, InState);
        Advance_Slide(Frame, InState);
        Advance_Orbit(Frame, InState);
        Write_PoseIfChanged(Frame, InState);
    }

    // The node keeps the last written offset, so an implement at rest (or within k_PoseTolerance of the last write: the
    // lift spring only approaches rest) issues no write.
    private void Write_PoseIfChanged(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        const auto OrbitOffset = utils_implement::Make_OrbitOffset(InFrame.Spec.Orbit, InState);
        const auto Changed = Math::Abs(InState.Pitch - InState.WrittenPitch) > k_PoseTolerance
            || Math::Abs(InState.Roll - InState.WrittenRoll) > k_PoseTolerance
            || Math::Abs(InState.Yaw - InState.WrittenYaw) > k_PoseTolerance
            || Math::Abs(InState.Lift - InState.WrittenLift) > k_PoseTolerance
            || (InState.Slide - InState.WrittenSlide).Size() > k_PoseTolerance
            || (OrbitOffset - InState.WrittenOrbit).Size() > k_PoseTolerance;
        if (Changed == false)
        { return; }

        utils_implement::Apply_Pose(InFrame.Spec.Nodes.Node, InState, OrbitOffset, InFrame.Spec.Tilt.RestRadius);
        InState.WrittenPitch = InState.Pitch;
        InState.WrittenRoll = InState.Roll;
        InState.WrittenYaw = InState.Yaw;
        InState.WrittenLift = InState.Lift;
        InState.WrittenSlide = InState.Slide;
        InState.WrittenOrbit = OrbitOffset;
    }

    // The orbit's share eases toward 1 while Driven and toward 0 while Idle over EaseSeconds; the phase turns while any of
    // it shows, so an eased-out implement holds still.
    private void Advance_Orbit(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        const auto& OrbitSpec = InFrame.Spec.Orbit;
        const auto Step = InFrame.DeltaSeconds / OrbitSpec.EaseSeconds;
        const auto Goal = InState.Drive == EMars_Implement_Drive::Driven ? 1.0f : 0.0f;
        InState.OrbitAlpha = InState.OrbitAlpha < Goal
            ? Math::Min(Goal, InState.OrbitAlpha + Step)
            : Math::Max(Goal, InState.OrbitAlpha - Step);

        if (InState.OrbitAlpha <= 0.0f)
        { return; }

        const auto FullTurn = 2.0f * float32(Math::DegreesToRadians(180.0));
        InState.OrbitPhase += FullTurn * OrbitSpec.Hz * InFrame.DeltaSeconds;
        if (InState.OrbitPhase >= FullTurn)
        { InState.OrbitPhase -= FullTurn * float32(Math::FloorToInt(InState.OrbitPhase / FullTurn)); }
    }

    // The look is read once per frame and handed to every step; an idle implement drops it.
    private FVector Take_PendingLook(FMars_Fragment_Implement& InState)
    {
        const auto Look = InState.PendingLook;
        InState.PendingLook = FVector::ZeroVector;
        if (InState.Drive != EMars_Implement_Drive::Driven)
        { return FVector::ZeroVector; }

        return Look;
    }

    // A Kick lift splits the upward look first: the degrees beyond what FlickSpeedDegreesPerSecond covers this frame only
    // lift (without the split every toss would also pitch the implement to its clamp). The rest steers the targets the
    // axes name: X rolls (or yaws), Y pitches, unless RollOnly leaves Y to the lift. The targets relax toward level
    // without crossing it (every frame, or only while Idle so a held implement keeps its tilt) and clamp; the tilt tracks
    // them at a bounded rate.
    private void Advance_Tilt(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        const auto& TiltSpec = InFrame.Spec.Tilt;
        const auto Excess = Get_FlickExcess(InFrame);
        const auto SideSteer = float32(InFrame.Look.X) * TiltSpec.TiltPerLookDegree;
        const auto PitchSteer = -(float32(InFrame.Look.Y) + Excess) * TiltSpec.TiltPerLookDegree;

        switch (TiltSpec.Axes)
        {
            case EMars_Implement_TiltAxes::PitchAndRoll:
            {
                InState.TargetRoll += SideSteer;
                InState.TargetPitch += PitchSteer;
                break;
            }

            case EMars_Implement_TiltAxes::RollOnly:
            {
                InState.TargetRoll += SideSteer;
                break;
            }

            case EMars_Implement_TiltAxes::PitchAndYaw:
            {
                InState.TargetYaw += SideSteer;
                InState.TargetPitch += PitchSteer;
                break;
            }

            case EMars_Implement_TiltAxes::None:
            {
                break;
            }
        }

        if (TiltSpec.Relax == EMars_Implement_Relax::Always || InState.Drive == EMars_Implement_Drive::Idle)
        {
            const auto Relax = TiltSpec.LevelReturnDegreesPerSecond * InFrame.DeltaSeconds;
            InState.TargetRoll = Get_RelaxedTowardZero(InState.TargetRoll, Relax);
            InState.TargetPitch = Get_RelaxedTowardZero(InState.TargetPitch, Relax);
            InState.TargetYaw = Get_RelaxedTowardZero(InState.TargetYaw, Relax);
        }

        InState.TargetRoll = Math::Clamp(InState.TargetRoll, -TiltSpec.MaxTiltDegrees, TiltSpec.MaxTiltDegrees);
        InState.TargetPitch = Math::Clamp(InState.TargetPitch, -TiltSpec.MaxTiltDegrees, TiltSpec.MaxTiltDegrees);
        InState.TargetYaw = Math::Clamp(InState.TargetYaw, -TiltSpec.MaxTiltDegrees, TiltSpec.MaxTiltDegrees);

        const auto MaxStep = TiltSpec.MaxTiltRateDegreesPerSecond * InFrame.DeltaSeconds;
        InState.Roll += Math::Clamp(InState.TargetRoll - InState.Roll, -MaxStep, MaxStep);
        InState.Pitch += Math::Clamp(InState.TargetPitch - InState.Pitch, -MaxStep, MaxStep);
        InState.Yaw += Math::Clamp(InState.TargetYaw - InState.Yaw, -MaxStep, MaxStep);

        if (InFrame.Spec.Lift.Mode == EMars_Implement_LiftMode::Kick)
        { Kick_Lift(InFrame, InState, Excess); }
    }

    // The upward look degrees beyond what FlickSpeedDegreesPerSecond covers this frame; only a Kick lift takes them.
    private float32 Get_FlickExcess(const FMars_Implement_Frame& InFrame)
    {
        if (InFrame.Spec.Lift.Mode != EMars_Implement_LiftMode::Kick)
        { return 0.0f; }

        const auto UpDegrees = Math::Max(0.0f, float32(-InFrame.Look.Y));
        return Math::Max(0.0f, UpDegrees - InFrame.Spec.Lift.FlickSpeedDegreesPerSecond * InFrame.DeltaSeconds);
    }

    // A Commanded lift: the look's Y moves the target (a downward look lowers it), clamped to [MinLift, MaxLift]. The
    // look is zero unless Driven, so a released implement holds its target.
    private void Advance_CommandedLift(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        const auto& LiftSpec = InFrame.Spec.Lift;
        if (LiftSpec.Mode != EMars_Implement_LiftMode::Commanded)
        { return; }

        const auto Target = InState.TargetLift - float32(InFrame.Look.Y) * LiftSpec.LiftPerLookDegree;
        InState.TargetLift = Math::Clamp(Target, LiftSpec.MinLift, LiftSpec.MaxLift);
    }

    // The excess degrees times Gain join the lift velocity; a kick that starts a rise (not one that adds to a rising
    // implement) is the toss cue.
    private void Kick_Lift(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState, float32 InExcess)
    {
        if (InExcess <= 0.0f)
        { return; }

        const auto WasRising = InState.LiftVelocity > 0.0f;
        InState.LiftVelocity += InExcess * InFrame.Spec.Lift.Gain;

        if (WasRising)
        { return; }

        ck::Trace(f"[Implement] [{InFrame.Implement.ToString()}] lift {InExcess :.2} deg excess -> {InState.LiftVelocity :.1} uu/s");
        if (InFrame.Implement.Has_Fragment(FMars_Fragment_Implement_Signals))
        { InFrame.Implement.Get_Fragment(FMars_Fragment_Implement_Signals).OnLiftKicked.Broadcast(InFrame.Implement, InExcess); }
    }

    // A damped spring pulls the lift toward its target (rest unless Commanded), so a yank overshoots and a still look
    // holds; the lift stays within [MinLift, MaxLift] and a clamp stops it dead. A None lift never moves.
    private void Advance_LiftSpring(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        const auto& LiftSpec = InFrame.Spec.Lift;
        if (LiftSpec.Mode == EMars_Implement_LiftMode::None)
        { return; }

        const auto Omega = 2.0f * float32(Math::DegreesToRadians(180.0)) * LiftSpec.SpringHz;
        const auto Stiffness = Omega * Omega;
        const auto Damping = 2.0f * LiftSpec.DampingRatio * float32(Math::Sqrt(Stiffness));

        const auto Steps = Get_SpringSteps(InFrame.DeltaSeconds);
        const auto StepSeconds = InFrame.DeltaSeconds / float32(Steps);
        for (int32 Index = 0; Index < Steps; ++Index)
        {
            InState.LiftVelocity += (-Stiffness * (InState.Lift - InState.TargetLift) - Damping * InState.LiftVelocity) * StepSeconds;
            InState.Lift += InState.LiftVelocity * StepSeconds;
        }

        if (InState.Lift > LiftSpec.MaxLift || InState.Lift < LiftSpec.MinLift)
        {
            InState.Lift = Math::Clamp(InState.Lift, LiftSpec.MinLift, LiftSpec.MaxLift);
            InState.LiftVelocity = 0.0f;
        }
    }

    // A Look slide: the look moves the slide target (X right -> +Y, Y down -> -X), clamped to the reachable box or disc
    // about the spec's Centre; the look is zero unless Driven, so a released implement holds its target. A Commanded slide's
    // target moves only by SetSlideTarget (the drain clamps it). Either way a damped spring per axis carries the slide
    // there. A Look slide with CmPerLookDegree 0 never moves.
    private void Advance_Slide(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        const auto& SlideSpec = InFrame.Spec.Slide;
        const auto IsCommanded = SlideSpec.Mode == EMars_Implement_SlideMode::Commanded;
        if (IsCommanded == false && SlideSpec.CmPerLookDegree <= 0.0f)
        { return; }

        if (IsCommanded == false)
        {
            const auto Step = float64(SlideSpec.CmPerLookDegree);
            const auto Target = InState.TargetSlide + FVector2D(-InFrame.Look.Y * Step, InFrame.Look.X * Step);
            InState.TargetSlide = utils_implement::Clamp_SlideTarget(SlideSpec, Target);
        }

        const auto Omega = 2.0 * Math::DegreesToRadians(180.0) * float64(SlideSpec.SpringHz);
        const auto Stiffness = Omega * Omega;
        const auto Damping = 2.0 * float64(SlideSpec.DampingRatio) * Omega;

        const auto Steps = Get_SpringSteps(InFrame.DeltaSeconds);
        const auto StepSeconds = float64(InFrame.DeltaSeconds) / float64(Steps);
        for (int32 Index = 0; Index < Steps; ++Index)
        {
            InState.SlideVelocity += ((InState.TargetSlide - InState.Slide) * Stiffness - InState.SlideVelocity * Damping) * StepSeconds;
            InState.Slide += InState.SlideVelocity * StepSeconds;
        }
    }

    // How many sub-steps a frame of InDeltaSeconds takes so none exceeds k_MaxSpringStepSeconds (one more than the floor: at least one).
    private int32 Get_SpringSteps(float32 InDeltaSeconds)
    {
        return Math::FloorToInt(InDeltaSeconds / k_MaxSpringStepSeconds) + 1;
    }

    private float32 Get_RelaxedTowardZero(float32 InValue, float32 InAmount)
    {
        if (InValue > 0.0f)
        { return Math::Max(0.0f, InValue - InAmount); }

        return Math::Min(0.0f, InValue + InAmount);
    }
}
