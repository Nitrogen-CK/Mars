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
    bool IsRunning = false;

    UPROPERTY()
    int32 PhaseIndex = 0;

    UPROPERTY()
    FCk_Handle_Timer PhaseTimer;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Cycle_OnPhaseChanged(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex);
event void FMars_Delegate_Cycle_OnPhaseChanged_MC(FCk_Handle_Cycle InCycle, FGameplayTag InPhase, int32 InIndex);

delegate void FMars_Delegate_Cycle_OnRunningChanged(FCk_Handle_Cycle InCycle, bool InRunning);
event void FMars_Delegate_Cycle_OnRunningChanged_MC(FCk_Handle_Cycle InCycle, bool InRunning);

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
    bool Running = false;

    FMars_Request_Cycle_SetRunning(bool InRunning)
    {
        Running = InRunning;
    }
}

struct FMars_Request_Cycle_Restart {}

// SetRunning is absolute and latest-wins. Advance is enqueued only by the processor's own phase timer.
struct FMars_Fragment_Cycle_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_Cycle_SetRunning> SetRunningRequest;

    UPROPERTY()
    TOptional<FMars_Request_Cycle_Restart> RestartRequest;

    UPROPERTY()
    bool Advance = false;
}
