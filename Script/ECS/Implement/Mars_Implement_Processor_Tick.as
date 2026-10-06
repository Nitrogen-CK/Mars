// What every step of one Implement's tick reads: the implement, its spec and the frame's real time.
struct FMars_Implement_Frame
{
    FCk_Handle_Implement Implement;
    FMars_Implement_Spec Spec;
    float32 DeltaSeconds = 0.0f;
}

// Every frame: the pending look (dropped unless Driven) is split into the slow part, which steers the tilt target, and the
// fast upward excess, which kicks the lift; the target relaxes and clamps, the tilt tracks it at a bounded rate, the lift
// spring settles, and ONE offset write of the node (only when the pose changed) moves the kinematic bodies under it.
class UMars_Processor_Implement_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    // Degrees of tilt or uu of lift.
    private const float32 k_PoseTolerance = 0.001f;

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

        Advance_Tilt(Frame, InState);
        Advance_LiftSpring(Frame, InState);
        Write_PoseIfChanged(Frame, InState);
    }

    // The node keeps the last written offset, so an implement at rest (or within k_PoseTolerance of the last write: the
    // lift spring only approaches rest) issues no write.
    private void Write_PoseIfChanged(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        const auto Changed = Math::Abs(InState.Pitch - InState.WrittenPitch) > k_PoseTolerance
            || Math::Abs(InState.Roll - InState.WrittenRoll) > k_PoseTolerance
            || Math::Abs(InState.Lift - InState.WrittenLift) > k_PoseTolerance;
        if (Changed == false)
        { return; }

        utils_implement::Apply_Pose(InFrame.Spec.Nodes.Node, InState);
        InState.WrittenPitch = InState.Pitch;
        InState.WrittenRoll = InState.Roll;
        InState.WrittenLift = InState.Lift;
    }

    // An idle implement drops the look. The upward look is split first: the degrees beyond what FlickSpeedDegreesPerSecond
    // covers this frame only lift (without the split every toss would also pitch the implement to its clamp); the rest
    // steers a target tilt that relaxes toward level without crossing it and clamps; the tilt tracks the target at a
    // bounded rate.
    private void Advance_Tilt(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        auto Look = InState.PendingLook;
        InState.PendingLook = FVector::ZeroVector;
        if (InState.Drive != EMars_Implement_Drive::Driven)
        { Look = FVector::ZeroVector; }

        const auto& TiltSpec = InFrame.Spec.Tilt;
        const auto UpDegrees = Math::Max(0.0f, float32(-Look.Y));
        const auto Excess = Math::Max(0.0f, UpDegrees - InFrame.Spec.Lift.FlickSpeedDegreesPerSecond * InFrame.DeltaSeconds);
        const auto TiltLookY = float32(Look.Y) + Excess;

        InState.TargetRoll += float32(Look.X) * TiltSpec.TiltPerLookDegree;
        InState.TargetPitch += -TiltLookY * TiltSpec.TiltPerLookDegree;

        const auto Relax = TiltSpec.LevelReturnDegreesPerSecond * InFrame.DeltaSeconds;
        InState.TargetRoll = Math::Clamp(Get_RelaxedTowardZero(InState.TargetRoll, Relax), -TiltSpec.MaxTiltDegrees, TiltSpec.MaxTiltDegrees);
        InState.TargetPitch = Math::Clamp(Get_RelaxedTowardZero(InState.TargetPitch, Relax), -TiltSpec.MaxTiltDegrees, TiltSpec.MaxTiltDegrees);

        const auto MaxStep = TiltSpec.MaxTiltRateDegreesPerSecond * InFrame.DeltaSeconds;
        InState.Roll += Math::Clamp(InState.TargetRoll - InState.Roll, -MaxStep, MaxStep);
        InState.Pitch += Math::Clamp(InState.TargetPitch - InState.Pitch, -MaxStep, MaxStep);

        Kick_Lift(InFrame, InState, Excess);
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

    // A damped spring pulls the lift back to rest; the lift stays within [MinLift, MaxLift] and a clamp stops it dead.
    private void Advance_LiftSpring(FMars_Implement_Frame& InFrame, FMars_Fragment_Implement& InState)
    {
        const auto& LiftSpec = InFrame.Spec.Lift;
        const auto Omega = 2.0f * float32(Math::DegreesToRadians(180.0)) * LiftSpec.SpringHz;
        const auto Stiffness = Omega * Omega;
        const auto Damping = 2.0f * LiftSpec.DampingRatio * float32(Math::Sqrt(Stiffness));

        InState.LiftVelocity += (-Stiffness * InState.Lift - Damping * InState.LiftVelocity) * InFrame.DeltaSeconds;
        InState.Lift += InState.LiftVelocity * InFrame.DeltaSeconds;

        if (InState.Lift > LiftSpec.MaxLift || InState.Lift < LiftSpec.MinLift)
        {
            InState.Lift = Math::Clamp(InState.Lift, LiftSpec.MinLift, LiftSpec.MaxLift);
            InState.LiftVelocity = 0.0f;
        }
    }

    private float32 Get_RelaxedTowardZero(float32 InValue, float32 InAmount)
    {
        if (InValue > 0.0f)
        { return Math::Max(0.0f, InValue - InAmount); }

        return Math::Min(0.0f, InValue + InAmount);
    }
}
