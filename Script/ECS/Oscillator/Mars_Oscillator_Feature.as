//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_OscillatorHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Oscillator";
    RequiredFragments.Add(FMars_Feature_Oscillator);
    Description = "A scene node that swings sinusoidally about one rotation axis, easing in on start and settling on stop";
}
struct FMars_Feature_Oscillator {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Oscillator_Axis
{
    Pitch,
    Yaw,
    Roll
}

struct FMars_Oscillator_Spec
{
    UPROPERTY()
    float32 AmplitudeDegrees = 45.0f;

    UPROPERTY()
    float32 PeriodSeconds = 3.0f;

    UPROPERTY()
    EMars_Oscillator_Axis Axis = EMars_Oscillator_Axis::Pitch;

    UPROPERTY()
    bool StartRunning = true;

    // Time for the swing to ramp from rest to full amplitude on start, and back to rest on stop.
    UPROPERTY()
    float32 SettleSeconds = 1.5f;

    // Unset = stopping eases the swing to rest. Set = stopping is a brake: the swing carries on at full amplitude until it
    // passes this angle, then holds there; starting releases it from there. Within +-AmplitudeDegrees. A spec that does
    // not start running starts held at this angle.
    UPROPERTY()
    TOptional<float32> CatchAngleDegrees;
}

// A catch angle the swing reaches, on a swing that moves.
mixin FMars_Validation Validate(const FMars_Oscillator_Spec& Self)
{
    if (Self.CatchAngleDegrees.IsSet() == false)
    { return FMars_Validation(); }

    const auto CatchAngle = Self.CatchAngleDegrees.GetValue();
    if (Math::Abs(CatchAngle) > Self.AmplitudeDegrees)
    { return FMars_Validation(f"CatchAngleDegrees [{CatchAngle}] must be within AmplitudeDegrees [{Self.AmplitudeDegrees}]"); }

    if (Self.PeriodSeconds <= 0.0f)
    { return FMars_Validation(f"PeriodSeconds [{Self.PeriodSeconds}] must be positive for a swing to reach its catch angle"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Oscillator_Params
{
    UPROPERTY()
    float32 AmplitudeDegrees = 45.0f;

    UPROPERTY()
    float32 PeriodSeconds = 3.0f;

    UPROPERTY()
    EMars_Oscillator_Axis Axis = EMars_Oscillator_Axis::Pitch;

    UPROPERTY()
    float32 SettleSeconds = 1.5f;

    // The node's offset rotation when the oscillator was added; the swing is applied on top of it.
    UPROPERTY()
    FRotator RestRotation;

    UPROPERTY()
    TOptional<float32> CatchAngleDegrees;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Oscillator
{
    UPROPERTY()
    bool IsRunning = false;

    UPROPERTY()
    float32 Time = 0.0f;

    // 0 = at rest, 1 = full amplitude.
    UPROPERTY()
    float32 Envelope = 0.0f;

    // Stopped and held at the catch angle (CatchAngleDegrees set). Time and Envelope stay where the catch took them.
    UPROPERTY()
    bool IsCaught = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Oscillator_OnRunningChanged(FCk_Handle_Oscillator InOscillator, bool InRunning);
event void FMars_Delegate_Oscillator_OnRunningChanged_MC(FCk_Handle_Oscillator InOscillator, bool InRunning);

struct FMars_Fragment_Oscillator_Signals
{
    FMars_Delegate_Oscillator_OnRunningChanged_MC OnRunningChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Oscillator_SetRunning
{
    UPROPERTY()
    bool Running = false;

    FMars_Request_Oscillator_SetRunning(bool InRunning)
    {
        Running = InRunning;
    }
}

// Absolute and latest-wins: one pending value, overwritten by each new request.
struct FMars_Fragment_Oscillator_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_Oscillator_SetRunning> SetRunningRequest;
}
