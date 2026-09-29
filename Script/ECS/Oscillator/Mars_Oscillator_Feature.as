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
