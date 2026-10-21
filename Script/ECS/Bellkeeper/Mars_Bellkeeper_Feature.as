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
}

// Dials to judge with one answer each, on the ring, none starting on it; a reward to keep; a vent pulse that runs.
mixin FMars_Validation Validate(const FMars_Bellkeeper_Spec& Self)
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

    for (int32 Index = 0; Index < Self.Rewards.Num(); ++Index)
    {
        if (Self.Rewards[Index].Definition.IsNull())
        { return FMars_Validation(f"Rewards[{Index}] has no item definition"); }
    }

    if (Self.VentPulseSeconds <= 0.0f)
    { return FMars_Validation(f"VentPulseSeconds [{Self.VentPulseSeconds}] must be positive"); }

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
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

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
}

struct FMars_Tag_Bellkeeper_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Bellkeeper_OnCommitFailed(FCk_Handle_Bellkeeper InBellkeeper, int32 InRemainingRewards);
event void FMars_Delegate_Bellkeeper_OnCommitFailed_MC(FCk_Handle_Bellkeeper InBellkeeper, int32 InRemainingRewards);

delegate void FMars_Delegate_Bellkeeper_OnSolved(FCk_Handle_Bellkeeper InBellkeeper);
event void FMars_Delegate_Bellkeeper_OnSolved_MC(FCk_Handle_Bellkeeper InBellkeeper);

struct FMars_Fragment_Bellkeeper_Signals
{
    FMars_Delegate_Bellkeeper_OnCommitFailed_MC OnCommitFailed;
    FMars_Delegate_Bellkeeper_OnSolved_MC OnSolved;
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

// Ended pulses apply first, then the commit. At most one commit is judged per drain, so a doubled edge cannot cost two
// rewards.
struct FMars_Fragment_Bellkeeper_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Bellkeeper_EndVent> EndVentRequests;

    UPROPERTY()
    TArray<FMars_Request_Bellkeeper_Commit> CommitRequests;
}
