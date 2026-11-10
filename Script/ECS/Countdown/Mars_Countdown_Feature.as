// Stance A. Remaining and Hold (FMars_Fragment_Countdown) are the replicated ledger, written by the authority's request
// drain and tick; the step clock (FMars_Fragment_Countdown_Clock) is composed everywhere but ticked on the authority
// only. A client mirrors the ledger and broadcasts OnRemainingChanged from what replicated.

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

    // Set: while the MechanismSink on the countdown's entity is powered the countdown stays full and does not drain; it
    // drains once the sink loses power. Rising edges still charge it either way.
    UPROPERTY()
    bool HoldWhilePowered = false;

    FMars_Countdown_Spec() {}

    // Field order: the spawn-params generator emits a subclass's changed `default Countdown.*` as this positional call.
    FMars_Countdown_Spec(int32 InSteps, float32 InSecondsPerStep, bool InStartCharged, bool InHoldWhilePowered = false)
    {
        Steps = InSteps;
        SecondsPerStep = InSecondsPerStep;
        StartCharged = InStartCharged;
        HoldWhilePowered = InHoldWhilePowered;
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

    UPROPERTY()
    bool HoldWhilePowered = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Whether the powered sink holds the countdown full (HoldWhilePowered).
enum EMars_Countdown_Hold
{
    Released,
    Held
}

// Written only by the Countdown processors and utils_countdown::Add.
struct FMars_Fragment_Countdown
{
    // Steps still charged, Steps..0.
    UPROPERTY()
    int32 Remaining = 0;

    // Held full by its powered sink (HoldWhilePowered): it does not drain.
    UPROPERTY()
    EMars_Countdown_Hold Hold = EMars_Countdown_Hold::Released;
}

// The authority's clock, never replicated: clients receive Remaining, not the time into the step.
struct FMars_Fragment_Countdown_Clock
{
    // Seconds into the current step.
    UPROPERTY()
    float32 StepElapsed = 0.0f;
}

// Non-authority only (the authority's setup removes it): the ledger as this machine last broadcast it, seeded with the
// ledger as Add composed it, so a value that replicated before the setup ran still broadcasts.
struct FMars_Fragment_Countdown_Mirror
{
    UPROPERTY()
    FMars_Fragment_Countdown Last;
}

// Present while Remaining > 0 and not held; gates UMars_Processor_Countdown_Tick. On a client it is only ever the
// one Add composed: the client's tick touches nothing.
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

// Absolute: holds the countdown full (Held) or lets it drain (Released).
struct FMars_Request_Countdown_SetHeld
{
    UPROPERTY()
    EMars_Countdown_Hold Hold = EMars_Countdown_Hold::Released;

    FMars_Request_Countdown_SetHeld() {}

    FMars_Request_Countdown_SetHeld(EMars_Countdown_Hold InHold)
    {
        Hold = InHold;
    }
}

// The latest SetHeld wins and applies first; a charge then refills.
struct FMars_Fragment_Countdown_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Countdown_Charge> ChargeRequests;

    UPROPERTY()
    TArray<FMars_Request_Countdown_SetHeld> SetHeldRequests;
}
