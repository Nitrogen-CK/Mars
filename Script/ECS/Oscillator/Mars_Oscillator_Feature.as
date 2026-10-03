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

enum EMars_Oscillator_RunState
{
    Stopped,
    Running
}

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

// A swing that moves in positive time, settling in non-negative time, and a catch angle the swing reaches.
mixin FMars_Validation Validate(const FMars_Oscillator_Spec& Self)
{
    if (Self.AmplitudeDegrees < 0.0f)
    { return FMars_Validation(f"AmplitudeDegrees [{Self.AmplitudeDegrees}] must not be negative"); }

    if (Self.PeriodSeconds <= 0.0f)
    { return FMars_Validation(f"PeriodSeconds [{Self.PeriodSeconds}] must be positive"); }

    if (Self.SettleSeconds < 0.0f)
    { return FMars_Validation(f"SettleSeconds [{Self.SettleSeconds}] must not be negative"); }

    if (Self.CatchAngleDegrees.IsSet() && Math::Abs(Self.CatchAngleDegrees.GetValue()) > Self.AmplitudeDegrees)
    { return FMars_Validation(f"CatchAngleDegrees [{Self.CatchAngleDegrees.GetValue()}] must be within AmplitudeDegrees [{Self.AmplitudeDegrees}]"); }

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

enum EMars_Oscillator_State
{
    // Easing to rest, or braking toward the catch angle when one is set.
    Stopped,
    Running,
    // Stopped and held at the catch angle. Time and Envelope stay where the catch took them.
    Caught
}

struct FMars_Fragment_Oscillator
{
    UPROPERTY()
    EMars_Oscillator_State State = EMars_Oscillator_State::Stopped;

    UPROPERTY()
    float32 Time = 0.0f;

    // 0 = at rest, 1 = full amplitude.
    UPROPERTY()
    float32 Envelope = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Oscillator_OnRunningChanged(FCk_Handle_Oscillator InOscillator, EMars_Oscillator_RunState InRunState);
event void FMars_Delegate_Oscillator_OnRunningChanged_MC(FCk_Handle_Oscillator InOscillator, EMars_Oscillator_RunState InRunState);

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
    EMars_Oscillator_RunState RunState = EMars_Oscillator_RunState::Stopped;

    FMars_Request_Oscillator_SetRunning() {}

    FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState InRunState)
    {
        RunState = InRunState;
    }
}

// SetRunning is absolute: the latest one wins.
struct FMars_Fragment_Oscillator_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Oscillator_SetRunning> SetRunningRequests;
}
