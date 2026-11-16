// The lock is the authority's: only the machine with authority over it judges a commit. The failed commits, the lock
// and each dial's index replicate in one ledger on the lock's entity; the vent's handshake, its clock and the reward
// handles are the authority's alone.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_BellkeeperHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Bellkeeper";
    RequiredFragments.Add(FMars_Feature_Bellkeeper);
    Description = "A dial lock judged on commit: a wrong commit vents and costs a reward, the right one opens and pays out what is left";
}
struct FMars_Feature_Bellkeeper {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// One reward the lock pays out, as a World-mode item at Transform.
struct FMars_Bellkeeper_Reward
{
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;

    UPROPERTY()
    FTransform Transform = FTransform::Identity;

    FMars_Bellkeeper_Reward() {}

    FMars_Bellkeeper_Reward(TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, FTransform InTransform)
    {
        Definition = InDefinition;
        Transform = InTransform;
    }
}

struct FMars_Bellkeeper_Spec
{
    // Construction input: the dials the assembly built, in panel order.
    TArray<FCk_Handle_Dial> Dials;

    // The index each dial must point at, one per dial.
    UPROPERTY()
    TArray<int32> Answer;

    // Lost from the front, one per wrong commit; the last is always paid out.
    UPROPERTY()
    TArray<FMars_Bellkeeper_Reward> Rewards;

    // Construction input, optional: asserted for VentPulseSeconds after every wrong commit. Invalid = no vent.
    FCk_Handle_MechanismSource VentSource;

    UPROPERTY()
    float32 VentPulseSeconds = 2.0f;

    // Optional dedicated, directly owned child Cycle with no MechanismSink. Bellkeeper alone controls its restarts.
    // Omitted preserves the legacy source-only pulse contract, which cannot restart an already-powered external vent.
    FCk_Handle_Cycle VentCycle;
}

// What a copy without authority needs of a spec: dials to judge with one answer each, on the ring, none starting on it,
// and a reward to count. The rewards' definitions and the vent are the authority's.
mixin FMars_Validation Validate_Shown(const FMars_Bellkeeper_Spec& Self)
{
    if (Self.Dials.Num() == 0)
    { return FMars_Validation("Dials must list at least one dial"); }

    if (Self.Answer.Num() != Self.Dials.Num())
    { return FMars_Validation(f"Answer has [{Self.Answer.Num()}] entries for [{Self.Dials.Num()}] dials"); }

    for (int32 Index = 0; Index < Self.Dials.Num(); ++Index)
    {
        const auto& Dial = Self.Dials[Index];
        if (ck::Is_NOT_Valid(Dial))
        { return FMars_Validation(f"Dials[{Index}] is not a valid dial"); }

        if (Self.Answer[Index] < 0 || Self.Answer[Index] >= Dial.Get_Positions())
        { return FMars_Validation(f"Answer[{Index}] [{Self.Answer[Index]}] is off its dial's [{Dial.Get_Positions()}] positions"); }

        if (Dial.Get_Index() == Self.Answer[Index])
        { return FMars_Validation(f"Dials[{Index}] starts on its answer [{Self.Answer[Index]}]: the lock starts part-solved"); }
    }

    if (Self.Rewards.Num() == 0)
    { return FMars_Validation("Rewards must list at least one reward: the last is the one a lock always pays"); }

    return FMars_Validation();
}

// What the authority needs as well: every reward's definition, a vent pulse that runs, a vent cycle it alone controls.
mixin FMars_Validation Validate(const FMars_Bellkeeper_Spec& Self)
{
    const auto Shown = Self.Validate_Shown();
    if (Shown.IsValid() == false)
    { return Shown; }

    for (int32 Index = 0; Index < Self.Rewards.Num(); ++Index)
    {
        if (Self.Rewards[Index].Definition.IsNull())
        { return FMars_Validation(f"Rewards[{Index}] has no item definition"); }
    }

    if (Self.VentPulseSeconds <= 0.0f)
    { return FMars_Validation(f"VentPulseSeconds [{Self.VentPulseSeconds}] must be positive"); }

    if (ck::IsValid(Self.VentCycle))
    {
        if (Self.VentCycle.Has_Fragment(FMars_Feature_MechanismSink))
        { return FMars_Validation("VentCycle must have no MechanismSink: Bellkeeper is its sole controller"); }

        if (utils_entity_lifetime::Get_LifetimeOwner(Self.VentCycle) != utils_entity_lifetime::Get_LifetimeOwner(Self.Dials[0]))
        { return FMars_Validation("VentCycle must be a directly owned sibling of the dials"); }
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Bellkeeper_Params
{
    UPROPERTY()
    TArray<FCk_Handle_Dial> Dials;

    UPROPERTY()
    TArray<int32> Answer;

    UPROPERTY()
    TArray<FMars_Bellkeeper_Reward> Rewards;

    UPROPERTY()
    FCk_Handle_MechanismSource VentSource;

    UPROPERTY()
    float32 VentPulseSeconds = 2.0f;

    UPROPERTY()
    FCk_Handle_Cycle VentCycle;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Bellkeeper_VentTransition
{
    Idle,
    AwaitStopped,
    AwaitRunning,
    Active
}

// Written only by UMars_Processor_Bellkeeper_HandleRequests and utils_bellkeeper::Add.
struct FMars_Fragment_Bellkeeper
{
    // Uncapped; the rewards lost stop at all but the last.
    UPROPERTY()
    int32 FailedCommits = 0;

    UPROPERTY()
    bool Solved = false;

    UPROPERTY()
    TArray<FCk_Handle> RewardHandles;

    // Valid while the vent source is asserted.
    UPROPERTY()
    FCk_Handle_Timer VentTimer;

    UPROPERTY()
    EMars_Bellkeeper_VentTransition VentTransition = EMars_Bellkeeper_VentTransition::Idle;
}

struct FMars_Tag_Bellkeeper_NeedsSetup {}

enum EMars_Bellkeeper_Lock
{
    Sealed,
    Solved
}

// Replicated. Written only by utils_bellkeeper::Publish; DialIndices in panel order.
struct FMars_Fragment_Bellkeeper_Net
{
    UPROPERTY()
    int32 FailedCommits = 0;

    UPROPERTY()
    EMars_Bellkeeper_Lock Lock = EMars_Bellkeeper_Lock::Sealed;

    UPROPERTY()
    TArray<int32> DialIndices;
}

// Non-authority only (the authority's setup removes it).
struct FMars_Fragment_Bellkeeper_Mirror
{
    // The ledger as this machine last reconciled it, seeded with the ledger this machine composed, so a standing
    // verdict is shown once and no failure is raised twice.
    UPROPERTY()
    FMars_Fragment_Bellkeeper_Net Last;

    // Whether this copy has taken the state it was born into.
    UPROPERTY()
    EMars_Net_InitialState InitialState = EMars_Net_InitialState::Awaited;
}

// Local: put on each of a lock's dials by the authority's setup, so a dial's index change finds its lock.
struct FMars_Fragment_Bellkeeper_DialLink
{
    UPROPERTY()
    FCk_Handle_Bellkeeper Lock;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Raised once per failure, never for one that came before a copy existed.
delegate void FMars_Delegate_Bellkeeper_OnCommitFailed(FCk_Handle_Bellkeeper InBellkeeper, int32 InRemainingRewards);
event void FMars_Delegate_Bellkeeper_OnCommitFailed_MC(FCk_Handle_Bellkeeper InBellkeeper, int32 InRemainingRewards);

// Raised once for the solve, never on a copy born after it.
delegate void FMars_Delegate_Bellkeeper_OnSolved(FCk_Handle_Bellkeeper InBellkeeper);
event void FMars_Delegate_Bellkeeper_OnSolved_MC(FCk_Handle_Bellkeeper InBellkeeper);

// A level: the failures counted or the lock differ from what this machine last showed. Raised with every verdict and
// when a copy takes or receives one.
delegate void FMars_Delegate_Bellkeeper_OnStateChanged(FCk_Handle_Bellkeeper InBellkeeper);
event void FMars_Delegate_Bellkeeper_OnStateChanged_MC(FCk_Handle_Bellkeeper InBellkeeper);

struct FMars_Fragment_Bellkeeper_Signals
{
    FMars_Delegate_Bellkeeper_OnCommitFailed_MC OnCommitFailed;
    FMars_Delegate_Bellkeeper_OnSolved_MC OnSolved;
    FMars_Delegate_Bellkeeper_OnStateChanged_MC OnStateChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// A commit: judge the dials as they stand.
struct FMars_Request_Bellkeeper_Commit
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Bellkeeper_Commit() {}
}

// The vent pulse that Timer timed has run out. Ignored when a newer wrong commit has restarted the pulse.
struct FMars_Request_Bellkeeper_EndVent
{
    UPROPERTY()
    FCk_Handle_Timer Timer;

    FMars_Request_Bellkeeper_EndVent() {}

    FMars_Request_Bellkeeper_EndVent(FCk_Handle_Timer InTimer)
    {
        Timer = InTimer;
    }
}

// A real transition acknowledgement, not an instruction to change the Cycle. Identity/current-state checks reject stale
// callbacks; only an acknowledged stop allows a restart, and only an acknowledged start arms its pulse clock.
struct FMars_Request_Bellkeeper_VentCycleChanged
{
    UPROPERTY()
    FCk_Handle_Cycle Cycle;

    UPROPERTY()
    EMars_Cycle_RunState RunState = EMars_Cycle_RunState::Stopped;

    FMars_Request_Bellkeeper_VentCycleChanged() {}

    FMars_Request_Bellkeeper_VentCycleChanged(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState)
    {
        Cycle = InCycle;
        RunState = InRunState;
    }
}

struct FMars_Request_Bellkeeper_DialMoved
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Bellkeeper_DialMoved() {}
}

// Ended pulses apply first, then the commit. At most one commit is judged per drain, so a doubled edge cannot cost two
// rewards.
struct FMars_Fragment_Bellkeeper_Requests
{
    // A dial of this lock changed its index; the drain publishes.
    UPROPERTY()
    TArray<FMars_Request_Bellkeeper_DialMoved> DialMovedRequests;

    UPROPERTY()
    TArray<FMars_Request_Bellkeeper_EndVent> EndVentRequests;

    UPROPERTY()
    TArray<FMars_Request_Bellkeeper_VentCycleChanged> VentCycleChanges;

    UPROPERTY()
    TArray<FMars_Request_Bellkeeper_Commit> CommitRequests;
}
