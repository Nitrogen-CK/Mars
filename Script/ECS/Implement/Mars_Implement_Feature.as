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

// The look steers a target tilt that relaxes back to level and clamps; the tilt tracks the target at a bounded rate.
struct FMars_Implement_TiltSpec
{
    // Degrees of tilt per degree of look.
    UPROPERTY()
    float32 TiltPerLookDegree = 1.2f;

    // The tilt moves at most this fast: a one-frame snap would become a huge edge velocity through the kinematic push and
    // fling whatever rests on the implement. A faster look is not lost; the tilt catches up over the next frames.
    UPROPERTY()
    float32 MaxTiltRateDegreesPerSecond = 300.0f;

    UPROPERTY()
    float32 MaxTiltDegrees = 30.0f;

    // Relaxation toward level.
    UPROPERTY()
    float32 LevelReturnDegreesPerSecond = 45.0f;

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

// An upward look faster than FlickSpeedDegreesPerSecond kicks the lift: the excess degrees times Gain are added to the
// lift velocity, and a damped spring brings the lift back to rest within [MinLift, MaxLift].
struct FMars_Implement_LiftSpec
{
    UPROPERTY()
    float32 FlickSpeedDegreesPerSecond = 250.0f;

    // uu/s of lift velocity per excess look degree.
    UPROPERTY()
    float32 Gain = 8.0f;

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
// or headroom, a floor above rest, or an orbit with a negative radius, no frequency or an instant ease, is unusable.
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

    if (Self.Orbit.Radius < 0.0f)
    { return FMars_Validation(f"Implement has a negative Orbit.Radius [{Self.Orbit.Radius}]"); }

    if (Self.Orbit.Hz <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Orbit.Hz [{Self.Orbit.Hz}]"); }

    if (Self.Orbit.EaseSeconds <= 0.0f)
    { return FMars_Validation(f"Implement has a non-positive Orbit.EaseSeconds [{Self.Orbit.EaseSeconds}]"); }

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

    // Degrees, what the node shows.
    UPROPERTY()
    float32 Pitch = 0.0f;

    UPROPERTY()
    float32 Roll = 0.0f;

    // Where the look is steering; the tilt tracks it at MaxTiltRateDegreesPerSecond.
    UPROPERTY()
    float32 TargetPitch = 0.0f;

    UPROPERTY()
    float32 TargetRoll = 0.0f;

    // uu above rest.
    UPROPERTY()
    float32 Lift = 0.0f;

    // uu/s.
    UPROPERTY()
    float32 LiftVelocity = 0.0f;

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

    // The tilt, lift and orbit offset the node's offset was last written with (the rest pose at Add): an implement at rest
    // writes nothing.
    UPROPERTY()
    float32 WrittenPitch = 0.0f;

    UPROPERTY()
    float32 WrittenRoll = 0.0f;

    UPROPERTY()
    float32 WrittenLift = 0.0f;

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

// Levels the implement (targets and tilt), zeroes the lift and the orbit, clears the pending look and idles it.
// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Implement_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Implement_Reset() {}
}

// Applied Reset -> SetDrive -> Look, so a reset and the first drive and looks of a new session can share a drain.
struct FMars_Fragment_Implement_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Implement_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Implement_SetDrive> SetDriveRequests;

    UPROPERTY()
    TArray<FMars_Request_Implement_Look> LookRequests;
}
