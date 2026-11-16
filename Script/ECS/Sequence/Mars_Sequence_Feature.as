// Stance A. Progress and the rejection record (FMars_Fragment_Sequence) are the replicated ledger, judged and written by
// the authority's request drain; the step timer is the authority's clock and lives in the local
// FMars_Fragment_Sequence_Local. A client mirrors the ledger and broadcasts the same four signals from it, after the
// state its copy was born into.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_SequenceHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Sequence";
    RequiredFragments.Add(FMars_Feature_Sequence);
    Description = "A logic node that asserts its mechanism source once its sink's input channels rise in a set order";
}
struct FMars_Feature_Sequence {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Sequence_Spec
{
    // The combination: the order in which these input channels must rise.
    UPROPERTY(meta = (Categories = "Mechanism.Channel"))
    TArray<FGameplayTag> Steps;

    UPROPERTY()
    bool ResetOnWrongInput = true;

    // Unset = no timeout. Set, the next step must arrive within this many seconds of the previous one.
    UPROPERTY()
    TOptional<float32> StepTimeoutSeconds;

    // Latched: stays complete (and asserted) until Reset. Unlatched: resets after OutputPulseSeconds.
    UPROPERTY()
    bool Latch = true;

    // Unlatched only; 0 falls back to a short pulse.
    UPROPERTY()
    float32 OutputPulseSeconds = 0.0f;
}

// At least one step, each set; a timeout, when set, and a pulse that do not run backwards.
mixin FMars_Validation Validate(const FMars_Sequence_Spec& Self)
{
    if (Self.Steps.Num() == 0)
    { return FMars_Validation("Steps must list at least one channel: an empty combination never completes"); }

    for (int32 Index = 0; Index < Self.Steps.Num(); ++Index)
    {
        if (Self.Steps[Index].IsValid() == false)
        { return FMars_Validation(f"Steps[{Index}] is not set"); }
    }

    if (Self.StepTimeoutSeconds.IsSet() && Self.StepTimeoutSeconds.GetValue() <= 0.0f)
    { return FMars_Validation(f"StepTimeoutSeconds [{Self.StepTimeoutSeconds.GetValue()}] must be positive when set"); }

    if (Self.OutputPulseSeconds < 0.0f)
    { return FMars_Validation(f"OutputPulseSeconds [{Self.OutputPulseSeconds}] must not be negative"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Sequence_Params
{
    UPROPERTY()
    TArray<FGameplayTag> Steps;

    UPROPERTY()
    bool ResetOnWrongInput = true;

    UPROPERTY()
    TOptional<float32> StepTimeoutSeconds;

    UPROPERTY()
    bool Latch = true;

    UPROPERTY()
    float32 OutputPulseSeconds = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_Sequence_HandleRequests and utils_sequence::Add.
struct FMars_Fragment_Sequence
{
    // Steps accepted; complete once it reaches the step count.
    UPROPERTY()
    int32 Progress = 0;

    // Every rejected input, counted, and the channel of the latest: a client cannot tell a rejection from the progress.
    UPROPERTY()
    int32 Rejections = 0;

    UPROPERTY()
    FGameplayTag LastRejectedChannel;
}

// The authority's clock, never replicated (its request drain arms and destroys the timer).
struct FMars_Fragment_Sequence_Local
{
    // Step timeout while in progress; output pulse while complete and unlatched.
    UPROPERTY()
    FCk_Handle_Timer StepTimer;
}

// Non-authority only (the authority's setup removes it).
struct FMars_Fragment_Sequence_Mirror
{
    // The ledger as this machine last reconciled it, seeded with the ledger this machine composed, so standing steps
    // are announced once.
    UPROPERTY()
    FMars_Fragment_Sequence Last;

    // Whether this copy has taken the state it was born into.
    UPROPERTY()
    EMars_Net_InitialState InitialState = EMars_Net_InitialState::Awaited;
}

struct FMars_Tag_Sequence_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Sequence_OnStepAccepted(FCk_Handle_Sequence InSequence, int32 InIndex);
event void FMars_Delegate_Sequence_OnStepAccepted_MC(FCk_Handle_Sequence InSequence, int32 InIndex);

delegate void FMars_Delegate_Sequence_OnInputRejected(FCk_Handle_Sequence InSequence, FGameplayTag InChannel);
event void FMars_Delegate_Sequence_OnInputRejected_MC(FCk_Handle_Sequence InSequence, FGameplayTag InChannel);

delegate void FMars_Delegate_Sequence_OnCompleted(FCk_Handle_Sequence InSequence);
event void FMars_Delegate_Sequence_OnCompleted_MC(FCk_Handle_Sequence InSequence);

delegate void FMars_Delegate_Sequence_OnReset(FCk_Handle_Sequence InSequence);
event void FMars_Delegate_Sequence_OnReset_MC(FCk_Handle_Sequence InSequence);

struct FMars_Fragment_Sequence_Signals
{
    FMars_Delegate_Sequence_OnStepAccepted_MC OnStepAccepted;
    FMars_Delegate_Sequence_OnInputRejected_MC OnInputRejected;
    FMars_Delegate_Sequence_OnCompleted_MC OnCompleted;
    FMars_Delegate_Sequence_OnReset_MC OnReset;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Sequence_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Sequence_Reset() {}
}

// A rising edge on one of the sequence's input channels, forwarded from the sink on its entity in signal order.
struct FMars_Request_Sequence_Input
{
    UPROPERTY()
    FGameplayTag Channel;

    FMars_Request_Sequence_Input() {}

    FMars_Request_Sequence_Input(FGameplayTag InChannel)
    {
        Channel = InChannel;
    }
}

// A pending reset applies first, then the inputs in arrival order: an input after a wrong one in the same drain is
// judged against the progress the wrong one left.
struct FMars_Fragment_Sequence_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Sequence_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Sequence_Input> InputRequests;
}
