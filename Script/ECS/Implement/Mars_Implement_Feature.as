//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_ImplementHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Implement";
    RequiredFragments.Add(FMars_Feature_Implement);
    Description = "A look-steered kinematic implement: a scene node tilted and lifted from the operator's look, carrying kinematic bodies into the physics world";
}
struct FMars_Feature_Implement {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Idle: the look is dropped and the tilt relaxes to level. Driven: the look steers.
enum EMars_Implement_Drive
{
    Idle,
    Driven
}

// Which look components steer which tilt target: a pan pitches and rolls, a basket only rolls (its lift takes the look's
// Y), an arm yaws and dips, a sliding tool never tilts (the targets stay level).
enum EMars_Implement_TiltAxes
{
    PitchAndRoll,
    RollOnly,
    PitchAndYaw,
    None
}

// Always: the targets relax toward level every frame (a pan levels as soon as the look stops). WhileIdle: a held
// implement keeps the tilt the hand gave it and levels once released.
enum EMars_Implement_Relax
{
    Always,
    WhileIdle
}

// Kick: a fast upward look kicks the lift and the spring returns it to rest (a toss). Commanded: the look's Y moves the
// lift target and the spring tracks it, so a yank overshoots and neutral holds (a held basket). None: the node never
// lifts.
enum EMars_Implement_LiftMode
{
    Kick,
    Commanded,
    None
}

// The look steers target tilts (split between pitch, roll and yaw by Axes) that clamp and, per Relax, relax back to level;
// the tilt tracks the targets at a bounded rate.
struct FMars_Implement_TiltSpec
{
    UPROPERTY()
    EMars_Implement_TiltAxes Axes = EMars_Implement_TiltAxes::PitchAndRoll;

    UPROPERTY()
    EMars_Implement_Relax Relax = EMars_Implement_Relax::Always;

    // Degrees of tilt per degree of look.
    UPROPERTY()
    float32 TiltPerLookDegree = 1.2f;

    // The tilt moves at most this fast: a one-frame snap would become a huge edge velocity through the kinematic push and
    // fling whatever rests on the implement. A faster look is not lost; the tilt catches up over the next frames.
    UPROPERTY()
    float32 MaxTiltRateDegreesPerSecond = 300.0f;

    UPROPERTY()
    float32 MaxTiltDegrees = 30.0f;

    // Relaxation toward level (every frame, or only while Idle: Relax).
    UPROPERTY()
    float32 LevelReturnDegreesPerSecond = 45.0f;

    // uu: the implement rests on a ring of this radius about its node (a pan on a trivet). A tilt then pivots on that ring,
    // not about the node: the node rises by RestRadius x sin(tilt) along the rest frame's up, so the low side of the base
    // stays on the ring instead of cutting through whatever is under it. 0 = tilt about the node.
    UPROPERTY()
    float32 RestRadius = 0.0f;

    FMars_Implement_TiltSpec() {}

    FMars_Implement_TiltSpec(
        float32 InTiltPerLookDegree,
        float32 InMaxTiltRateDegreesPerSecond,
        float32 InMaxTiltDegrees,
        float32 InLevelReturnDegreesPerSecond)
    {
        TiltPerLookDegree = InTiltPerLookDegree;
        MaxTiltRateDegreesPerSecond = InMaxTiltRateDegreesPerSecond;
        MaxTiltDegrees = InMaxTiltDegrees;
        LevelReturnDegreesPerSecond = InLevelReturnDegreesPerSecond;
    }
}

// A damped spring carries the lift toward a target within [MinLift, MaxLift]. Kick: the target is rest, and an upward look
// faster than FlickSpeedDegreesPerSecond kicks the lift (the excess degrees times Gain join the lift velocity).
// Commanded: the look's Y moves the target by LiftPerLookDegree. None: no lift.
struct FMars_Implement_LiftSpec
{
    UPROPERTY()
    EMars_Implement_LiftMode Mode = EMars_Implement_LiftMode::Kick;

    // Kick only.
    UPROPERTY()
    float32 FlickSpeedDegreesPerSecond = 250.0f;

    // uu/s of lift velocity per excess look degree (Kick only).
    UPROPERTY()
    float32 Gain = 8.0f;

    // uu of lift target per degree of look (Commanded only).
    UPROPERTY()
    float32 LiftPerLookDegree = 1.0f;

    UPROPERTY()
    float32 SpringHz = 4.0f;

    UPROPERTY()
    float32 DampingRatio = 0.5f;

    // uu above rest.
    UPROPERTY()
    float32 MaxLift = 20.0f;

    // uu; the lowest the spring may carry the node below its rest.
    UPROPERTY()
    float32 MinLift = -2.0f;

    FMars_Implement_LiftSpec() {}

    FMars_Implement_LiftSpec(
        float32 InFlickSpeedDegreesPerSecond,
        float32 InGain,
        float32 InSpringHz,
        float32 InDampingRatio,
        float32 InMaxLift,
        float32 InMinLift)
    {
        FlickSpeedDegreesPerSecond = InFlickSpeedDegreesPerSecond;
        Gain = InGain;
        SpringHz = InSpringHz;
        DampingRatio = InDampingRatio;
        MaxLift = InMaxLift;
        MinLift = InMinLift;
    }
}

// Look: the look moves the slide target. Commanded: the look never moves it; a kernel sets it outright with
// SetSlideTarget (a reach region the box or disc cannot express is the kernel's to clamp first) and the spring tracks it.
enum EMars_Implement_SlideMode
{
    Look,
    Commanded
}

// A constant circular motion of the node in its rest frame's XY plane while Driven (the stirring of a pan); the radius
// eases in and out over EaseSeconds so drive changes never snap. Radius 0 = no orbit.
struct FMars_Implement_OrbitSpec
{
    // uu.
    UPROPERTY()
    float32 Radius = 0.0f;

    UPROPERTY()
    float32 Hz = 1.0f;

    UPROPERTY()
    float32 EaseSeconds = 0.3f;

    FMars_Implement_OrbitSpec() {}

    FMars_Implement_OrbitSpec(float32 InRadius, float32 InHz)
    {
        Radius = InRadius;
        Hz = InHz;
    }

    FMars_Implement_OrbitSpec(float32 InRadius, float32 InHz, float32 InEaseSeconds)
    {
        Radius = InRadius;
        Hz = InHz;
        EaseSeconds = InEaseSeconds;
    }
}

// A target offset in the rest location's XY plane, clamped to a box of the half extents about Centre or, with a Radius, to a
// disc of that radius about Centre; a damped spring carries the node there. Look: while Driven the look moves the target
// (look right -> +Y, look down -> -X: a mouse pushed forward carries the node away from the operator) and Idle holds it;
// CmPerLookDegree 0 = no slide. Commanded: only SetSlideTarget moves it.
struct FMars_Implement_SlideSpec
{
    UPROPERTY()
    EMars_Implement_SlideMode Mode = EMars_Implement_SlideMode::Look;

    // Look only.
    UPROPERTY()
    float32 CmPerLookDegree = 0.0f;

    // uu about Centre (box clamp, Radius 0 only).
    UPROPERTY()
    float32 HalfExtentX = 0.0f;

    UPROPERTY()
    float32 HalfExtentY = 0.0f;

    // uu from the rest location: the centre of the reachable area (a tool parked off-centre over a round pot).
    UPROPERTY()
    FVector2D Centre = FVector2D::ZeroVector;

    // uu; > 0 clamps the target to a disc about Centre instead of the box.
    UPROPERTY()
    float32 Radius = 0.0f;

    UPROPERTY()
    float32 SpringHz = 4.0f;

    UPROPERTY()
    float32 DampingRatio = 0.8f;

    FMars_Implement_SlideSpec() {}
}

// Built by the placing script before Add. Node's current offset is the implement's rest pose; the feature writes its
// offset every frame. Kinematic Jolt bodies under it carry the motion into the physics world.
struct FMars_Implement_Nodes
{
    UPROPERTY()
    FCk_Handle_SceneNode Node;

    FMars_Implement_Nodes() {}

    FMars_Implement_Nodes(FCk_Handle_SceneNode InNode)
    {
        Node = InNode;
    }
}

struct FMars_Implement_Spec
{
    UPROPERTY()
    FMars_Implement_TiltSpec Tilt;

    UPROPERTY()
    FMars_Implement_LiftSpec Lift;

    UPROPERTY()
    FMars_Implement_OrbitSpec Orbit;

    UPROPERTY()
    FMars_Implement_SlideSpec Slide;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Implement_Nodes Nodes;

    FMars_Implement_Spec() {}

    FMars_Implement_Spec(FMars_Implement_TiltSpec InTilt, FMars_Implement_LiftSpec InLift)
    {
        Tilt = InTilt;
        Lift = InLift;
    }

    FMars_Implement_Spec(FMars_Implement_TiltSpec InTilt, FMars_Implement_LiftSpec InLift, FMars_Implement_OrbitSpec InOrbit)
    {
        Tilt = InTilt;
        Lift = InLift;
        Orbit = InOrbit;
    }
}

// An implement that cannot tilt (or tilts past a usable angle, or at no rate), a lift spring with no stiffness, damping
// or headroom, a floor above rest, a commanded lift that runs backwards or has no range, an orbit with a negative
// radius, no frequency or an instant ease, or a slide that runs backwards, has a negative reach or a spring with no
// stiffness or damping, or a commanded slide with no reach at all, is unusable.
mixin FMars_Validation Validate(const FMars_Implement_Spec& Self)
{
    if (Self.Tilt.TiltPerLookDegree <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Tilt.TiltPerLookDegree [{Self.Tilt.TiltPerLookDegree}]"); }

    if (Self.Tilt.MaxTiltRateDegreesPerSecond <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Tilt.MaxTiltRateDegreesPerSecond [{Self.Tilt.MaxTiltRateDegreesPerSecond}]"); }

    if (Self.Tilt.MaxTiltDegrees <= 0.0f || Self.Tilt.MaxTiltDegrees > 80.0f)
    { return FMars_Validation(f"Implement has Tilt.MaxTiltDegrees [{Self.Tilt.MaxTiltDegrees}] outside (0, 80]"); }

    if (Self.Tilt.LevelReturnDegreesPerSecond < 0.0f)
    { return FMars_Validation(f"Implement has a negative Tilt.LevelReturnDegreesPerSecond [{Self.Tilt.LevelReturnDegreesPerSecond}]"); }

    if (Self.Tilt.RestRadius < 0.0f)
    { return FMars_Validation(f"Implement has a negative Tilt.RestRadius [{Self.Tilt.RestRadius}]"); }

    if (Self.Lift.FlickSpeedDegreesPerSecond < 0.0f)
    { return FMars_Validation(f"Implement has a negative Lift.FlickSpeedDegreesPerSecond [{Self.Lift.FlickSpeedDegreesPerSecond}]"); }

    if (Self.Lift.Gain < 0.0f)
    { return FMars_Validation(f"Implement has a negative Lift.Gain [{Self.Lift.Gain}]"); }

    if (Self.Lift.SpringHz <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Lift.SpringHz [{Self.Lift.SpringHz}]"); }

    if (Self.Lift.DampingRatio <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Lift.DampingRatio [{Self.Lift.DampingRatio}]"); }

    if (Self.Lift.MaxLift <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Lift.MaxLift [{Self.Lift.MaxLift}]"); }

    if (Self.Lift.MinLift > 0.0f)
    { return FMars_Validation(f"Implement has a positive Lift.MinLift [{Self.Lift.MinLift}]"); }

    if (Self.Lift.LiftPerLookDegree < 0.0f)
    { return FMars_Validation(f"Implement has a negative Lift.LiftPerLookDegree [{Self.Lift.LiftPerLookDegree}]"); }

    if (Self.Lift.Mode == EMars_Implement_LiftMode::Commanded && Self.Lift.MaxLift <= Self.Lift.MinLift)
    { return FMars_Validation(f"Implement has a Commanded lift with Lift.MaxLift [{Self.Lift.MaxLift}] <= Lift.MinLift [{Self.Lift.MinLift}]"); }

    if (Self.Orbit.Radius < 0.0f)
    { return FMars_Validation(f"Implement has a negative Orbit.Radius [{Self.Orbit.Radius}]"); }

    if (Self.Orbit.Hz <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Orbit.Hz [{Self.Orbit.Hz}]"); }

    if (Self.Orbit.EaseSeconds <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Orbit.EaseSeconds [{Self.Orbit.EaseSeconds}]"); }

    const auto& Slide = Self.Slide;
    if (Slide.CmPerLookDegree < 0.0f)
    { return FMars_Validation(f"Implement has a negative Slide.CmPerLookDegree [{Slide.CmPerLookDegree}]"); }

    if (Slide.Radius < 0.0f)
    { return FMars_Validation(f"Implement has a negative Slide.Radius [{Slide.Radius}]"); }

    const auto IsCommanded = Slide.Mode == EMars_Implement_SlideMode::Commanded;
    const auto HasSlide = Slide.CmPerLookDegree > 0.0f || IsCommanded;
    if (HasSlide && (Slide.HalfExtentX < 0.0f || Slide.HalfExtentY < 0.0f))
    { return FMars_Validation(f"Implement has a negative Slide.HalfExtentX [{Slide.HalfExtentX}] or HalfExtentY [{Slide.HalfExtentY}]"); }

    if (HasSlide && (Slide.SpringHz <= 0.0f || Slide.DampingRatio <= 0.0f))
    { return FMars_Validation(f"Implement has a non-positive Slide.SpringHz [{Slide.SpringHz}] or DampingRatio [{Slide.DampingRatio}]"); }

    if (IsCommanded && Slide.Radius <= 0.0f && Slide.HalfExtentX <= 0.0f && Slide.HalfExtentY <= 0.0f)
    { return FMars_Validation("Implement has a Commanded slide with no reach (Slide.Radius, HalfExtentX and HalfExtentY all 0)"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Implement_Params
{
    UPROPERTY()
    FMars_Implement_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the Implement processors (and Add).
struct FMars_Fragment_Implement
{
    UPROPERTY()
    EMars_Implement_Drive Drive = EMars_Implement_Drive::Idle;

    // Degrees, what the node shows. Which of the three the look steers is the spec's Tilt.Axes.
    UPROPERTY()
    float32 Pitch = 0.0f;

    UPROPERTY()
    float32 Roll = 0.0f;

    UPROPERTY()
    float32 Yaw = 0.0f;

    // Where the look is steering; the tilt tracks it at MaxTiltRateDegreesPerSecond.
    UPROPERTY()
    float32 TargetPitch = 0.0f;

    UPROPERTY()
    float32 TargetRoll = 0.0f;

    UPROPERTY()
    float32 TargetYaw = 0.0f;

    // uu above rest.
    UPROPERTY()
    float32 Lift = 0.0f;

    // uu above rest; the lift spring tracks it. Rest (0) unless the lift is Commanded.
    UPROPERTY()
    float32 TargetLift = 0.0f;

    // uu/s.
    UPROPERTY()
    float32 LiftVelocity = 0.0f;

    // uu from the rest location in its XY plane: what the node shows, where the look (or a Commanded slide's
    // SetSlideTarget) is steering it, and how fast the spring carries it.
    UPROPERTY()
    FVector2D Slide = FVector2D::ZeroVector;

    UPROPERTY()
    FVector2D TargetSlide = FVector2D::ZeroVector;

    UPROPERTY()
    FVector2D SlideVelocity = FVector2D::ZeroVector;

    // Look drained since the Tick last ran (degrees; X yaw right+, Y pitch down+). The drain only adds here; the Tick
    // consumes it against a real frame time (a dirty-marked processor is also pumped with a zero DeltaT).
    UPROPERTY()
    FVector PendingLook = FVector::ZeroVector;

    // The node's offset at Add: the rest pose the tilt and lift are relative to. Written only by Add.
    UPROPERTY()
    FTransform RestOffset = FTransform::Identity;

    // Radians, wrapped to [0, 2 pi); advances while the orbit shows (OrbitAlpha > 0).
    UPROPERTY()
    float32 OrbitPhase = 0.0f;

    // 0..1, the share of Orbit.Radius the node shows: eases toward 1 while Driven and toward 0 while Idle.
    UPROPERTY()
    float32 OrbitAlpha = 0.0f;

    // The tilt, lift, slide and orbit offset the node's offset was last written with (the rest pose at Add): an implement
    // at rest writes nothing.
    UPROPERTY()
    float32 WrittenPitch = 0.0f;

    UPROPERTY()
    float32 WrittenRoll = 0.0f;

    UPROPERTY()
    float32 WrittenYaw = 0.0f;

    UPROPERTY()
    float32 WrittenLift = 0.0f;

    UPROPERTY()
    FVector2D WrittenSlide = FVector2D::ZeroVector;

    UPROPERTY()
    FVector WrittenOrbit = FVector::ZeroVector;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// A drain that changed the drive (a Reset that found it Driven reports Idle).
delegate void FMars_Delegate_Implement_OnDriveChanged(FCk_Handle_Implement InImplement, EMars_Implement_Drive InDrive);
event void FMars_Delegate_Implement_OnDriveChanged_MC(FCk_Handle_Implement InImplement, EMars_Implement_Drive InDrive);

// A fast upward look started a lift (the toss cue); InExcessDegrees is the look beyond the flick speed that frame.
delegate void FMars_Delegate_Implement_OnLiftKicked(FCk_Handle_Implement InImplement, float32 InExcessDegrees);
event void FMars_Delegate_Implement_OnLiftKicked_MC(FCk_Handle_Implement InImplement, float32 InExcessDegrees);

struct FMars_Fragment_Implement_Signals
{
    FMars_Delegate_Implement_OnDriveChanged_MC OnDriveChanged;
    FMars_Delegate_Implement_OnLiftKicked_MC OnLiftKicked;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// One drained look delta (degrees; X yaw right+, Y pitch down+). Summed per drain; accepted while Driven.
struct FMars_Request_Implement_Look
{
    UPROPERTY()
    FVector LookDelta = FVector::ZeroVector;

    FMars_Request_Implement_Look() {}

    FMars_Request_Implement_Look(FVector InLookDelta)
    {
        LookDelta = InLookDelta;
    }
}

// Last wins within a drain.
struct FMars_Request_Implement_SetDrive
{
    UPROPERTY()
    EMars_Implement_Drive Drive = EMars_Implement_Drive::Idle;

    FMars_Request_Implement_SetDrive() {}

    FMars_Request_Implement_SetDrive(EMars_Implement_Drive InDrive)
    {
        Drive = InDrive;
    }
}

// A Commanded lift's target set outright (uu above rest, clamped to [MinLift, MaxLift]), so a kernel can lower or raise
// the node without a look. Last wins within a drain; a traced no-op unless the lift is Commanded.
struct FMars_Request_Implement_SetLiftTarget
{
    UPROPERTY()
    float32 Lift = 0.0f;

    FMars_Request_Implement_SetLiftTarget() {}

    FMars_Request_Implement_SetLiftTarget(float32 InLift)
    {
        Lift = InLift;
    }
}

// The tilt targets set outright (degrees: Pitch, Yaw, Roll on top of the rest rotation, each clamped to MaxTiltDegrees),
// so a kernel can tip the node without a look, whatever the axes. The look still steers on top where the axes allow it;
// the targets hold while Driven under WhileIdle and relax as any target otherwise. Last wins within a drain.
struct FMars_Request_Implement_SetTiltTarget
{
    UPROPERTY()
    FRotator Tilt = FRotator::ZeroRotator;

    FMars_Request_Implement_SetTiltTarget() {}

    FMars_Request_Implement_SetTiltTarget(FRotator InTilt)
    {
        Tilt = InTilt;
    }
}

// A Commanded slide's target set outright (uu from the rest location in its XY plane, clamped to the spec's box or disc as
// a look target is), so a kernel owns the reach. Last wins within a drain; a traced no-op unless the slide is Commanded.
struct FMars_Request_Implement_SetSlideTarget
{
    UPROPERTY()
    FVector2D Slide = FVector2D::ZeroVector;

    FMars_Request_Implement_SetSlideTarget() {}

    FMars_Request_Implement_SetSlideTarget(FVector2D InSlide)
    {
        Slide = InSlide;
    }
}

// Levels the implement (targets and tilt), zeroes the lift and its target, the slide and its target and the orbit,
// clears the pending look and idles it.
// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Implement_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Implement_Reset() {}
}

// Applied Reset -> SetDrive -> SetLiftTarget -> SetTiltTarget -> SetSlideTarget -> Look, so a reset and the first drive,
// lift, tilt, slide and looks of a new session can share a drain.
struct FMars_Fragment_Implement_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Implement_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Implement_SetDrive> SetDriveRequests;

    UPROPERTY()
    TArray<FMars_Request_Implement_SetLiftTarget> SetLiftTargetRequests;

    UPROPERTY()
    TArray<FMars_Request_Implement_SetTiltTarget> SetTiltTargetRequests;

    UPROPERTY()
    TArray<FMars_Request_Implement_SetSlideTarget> SetSlideTargetRequests;

    UPROPERTY()
    TArray<FMars_Request_Implement_Look> LookRequests;
}
