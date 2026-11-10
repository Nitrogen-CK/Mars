// Stance A. The run state, phase index and phase-entry count (FMars_Fragment_Cycle) are the replicated ledger, written
// by the authority's request drain; the phase timer is the authority's clock and lives in the local
// FMars_Fragment_Cycle_Local. A client mirrors the ledger and broadcasts OnPhaseChanged / OnRunningChanged from it.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_CycleHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Cycle";
    RequiredFragments.Add(FMars_Feature_Cycle);
    Description = "An entity that steps through a timed table of gameplay-tagged phases, optionally looping";
}
struct FMars_Feature_Cycle {}

enum EMars_Cycle_RunState
{
    Stopped,
    Running
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_CyclePhase
{
    UPROPERTY(meta = (Categories = "Mechanism.Phase"))
    FGameplayTag Phase;

    UPROPERTY()
    float32 Duration = 1.0f;

    FMars_CyclePhase(FGameplayTag InPhase, float32 InDuration)
    {
        Phase = InPhase;
        Duration = InDuration;
    }
}

struct FMars_Cycle_Spec
{
    UPROPERTY()
    TArray<FMars_CyclePhase> Phases;

    UPROPERTY()
    bool Loop = true;

    UPROPERTY()
    bool StartRunning = true;
}

// At least one phase, each tagged and lasting a positive time.
mixin FMars_Validation Validate(const FMars_Cycle_Spec& Self)
{
    if (Self.Phases.Num() == 0)
    { return FMars_Validation("Phases must list at least one phase"); }

    for (int32 Index = 0; Index < Self.Phases.Num(); ++Index)
    {
        const auto& Phase = Self.Phases[Index];
        if (Phase.Phase.IsValid() == false)
        { return FMars_Validation(f"Phases[{Index}] has no Phase tag"); }

        if (Phase.Duration <= 0.0f)
        { return FMars_Validation(f"Phases[{Index}] [{Phase.Phase.ToString()}] Duration [{Phase.Duration}] must be positive"); }
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Cycle_Params
{
    UPROPERTY()
    TArray<FMars_CyclePhase> Phases;

    UPROPERTY()
    bool Loop = true;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Cycle
{
    UPROPERTY()
    EMars_Cycle_RunState RunState = EMars_Cycle_RunState::Stopped;

    // Kept while stopped; a start re-enters phase 0 regardless.
    UPROPERTY()
    int32 PhaseIndex = 0;

    // Every phase entry, counted: a looping one-phase cycle re-enters the same index, which a client could not tell
    // from no entry at all.
    UPROPERTY()
    int32 PhaseEntries = 0;
}

// The authority's clock, never replicated (its request drain arms and destroys the timer).
struct FMars_Fragment_Cycle_Local
{
    UPROPERTY()
    FCk_Handle_Timer PhaseTimer;
}

// Non-authority only (the authority's setup removes it): the ledger as this machine last broadcast it, seeded with the
// ledger as Add composed it, so a value that replicated before the setup ran still broadcasts.
struct FMars_Fragment_Cycle_Mirror
{
    UPROPERTY()
    FMars_Fragment_Cycle Last;
}

struct FMars_Tag_Cycle_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Cycle_OnPhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex);
event void FMars_Delegate_Cycle_OnPhaseChanged_MC(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex);

delegate void FMars_Delegate_Cycle_OnRunningChanged(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState);
event void FMars_Delegate_Cycle_OnRunningChanged_MC(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState);

struct FMars_Fragment_Cycle_Signals
{
    FMars_Delegate_Cycle_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_Cycle_OnRunningChanged_MC OnRunningChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Cycle_SetRunning
{
    UPROPERTY()
    EMars_Cycle_RunState RunState = EMars_Cycle_RunState::Stopped;

    FMars_Request_Cycle_SetRunning() {}

    FMars_Request_Cycle_SetRunning(EMars_Cycle_RunState InRunState)
    {
        RunState = InRunState;
    }
}

// Enqueued only by the processor's own phase timer.
struct FMars_Request_Cycle_Advance
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Cycle_Advance() {}
}

// SetRunning is absolute: the latest one wins. Any number of advances in one drain act once.
struct FMars_Fragment_Cycle_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Cycle_SetRunning> SetRunningRequests;

    UPROPERTY()
    TArray<FMars_Request_Cycle_Advance> AdvanceRequests;
}
