//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_CountdownHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Countdown";
    RequiredFragments.Add(FMars_Feature_Countdown);
    Description = "A logic node that a rising input charges to full and that drains one step at a time, asserting its mechanism source while charged";
}
struct FMars_Feature_Countdown {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Countdown_Spec
{
    // Charge when full; one step drains every SecondsPerStep.
    UPROPERTY()
    int32 Steps = 4;

    UPROPERTY()
    float32 SecondsPerStep = 2.0f;

    UPROPERTY()
    bool StartCharged = false;

    FMars_Countdown_Spec() {}

    // Field order: the spawn-params generator emits a subclass's changed `default Countdown.*` as this positional call.
    FMars_Countdown_Spec(int32 InSteps, float32 InSecondsPerStep, bool InStartCharged)
    {
        Steps = InSteps;
        SecondsPerStep = InSecondsPerStep;
        StartCharged = InStartCharged;
    }
}

// At least one step, each lasting a positive time.
mixin FMars_Validation Validate(const FMars_Countdown_Spec& Self)
{
    if (Self.Steps < 1)
    { return FMars_Validation(f"Steps [{Self.Steps}] must be at least 1"); }

    if (Self.SecondsPerStep <= 0.0f)
    { return FMars_Validation(f"SecondsPerStep [{Self.SecondsPerStep}] must be positive"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Countdown_Params
{
    UPROPERTY()
    int32 Steps = 4;

    UPROPERTY()
    float32 SecondsPerStep = 2.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the Countdown processors and utils_countdown::Add.
struct FMars_Fragment_Countdown
{
    // Steps still charged, Steps..0.
    UPROPERTY()
    int32 Remaining = 0;

    // Seconds into the current step.
    UPROPERTY()
    float32 StepElapsed = 0.0f;
}

// Present while Remaining > 0; gates UMars_Processor_Countdown_Tick.
struct FMars_Tag_Countdown_Running {}

struct FMars_Tag_Countdown_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Countdown_OnRemainingChanged(FCk_Handle_Countdown InCountdown, int32 InRemaining);
event void FMars_Delegate_Countdown_OnRemainingChanged_MC(FCk_Handle_Countdown InCountdown, int32 InRemaining);

struct FMars_Fragment_Countdown_Signals
{
    FMars_Delegate_Countdown_OnRemainingChanged_MC OnRemainingChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Refills every step and restarts the current one. AngelScript rejects a TArray of an empty struct, so it carries one
// placeholder field.
struct FMars_Request_Countdown_Charge
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Countdown_Charge() {}
}

struct FMars_Fragment_Countdown_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Countdown_Charge> ChargeRequests;
}
