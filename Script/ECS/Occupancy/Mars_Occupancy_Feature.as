//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_OccupancyHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Occupancy";
    RequiredFragments.Add(FMars_Feature_Occupancy);
    Description = "An entity that is active while enough entities are inside its trigger, releasing after a delay";
}
struct FMars_Feature_Occupancy {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Occupancy_Spec
{
    UPROPERTY()
    int32 RequiredCount = 1;

    // 0 releases as soon as the count drops below RequiredCount.
    UPROPERTY()
    float32 ReleaseDelaySeconds = 0.0f;
}

mixin FMars_Validation Validate(const FMars_Occupancy_Spec& Self)
{
    if (Self.RequiredCount < 1)
    { return FMars_Validation(f"RequiredCount [{Self.RequiredCount}] must be at least 1: an occupancy needing nobody is always active"); }

    if (Self.ReleaseDelaySeconds < 0.0f)
    { return FMars_Validation(f"ReleaseDelaySeconds [{Self.ReleaseDelaySeconds}] must not be negative"); }

    return FMars_Validation();
}

// The entities an occupancy works through, built by its owner before Add.
struct FMars_Occupancy_Parts
{
    // Counted for occupancy. Several occupancies may share one trigger.
    UPROPERTY()
    FCk_Handle_Trigger Trigger;

    // Optional: moved to its end pose while active and back to its start pose when released.
    UPROPERTY()
    FCk_Handle_Mover Mover;

    FMars_Occupancy_Parts() {}

    FMars_Occupancy_Parts(FCk_Handle_Trigger InTrigger, FCk_Handle_Mover InMover = FCk_Handle_Mover())
    {
        Trigger = InTrigger;
        Mover = InMover;
    }
}

mixin FMars_Validation Validate(const FMars_Occupancy_Parts& Self)
{
    if (ck::Is_NOT_Valid(Self.Trigger))
    { return FMars_Validation("Trigger must be set: an occupancy without one never counts anybody"); }

    return FMars_Validation();
}

struct FMars_Tag_Occupancy_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Occupancy_Params
{
    UPROPERTY()
    int32 RequiredCount = 1;

    UPROPERTY()
    float32 ReleaseDelaySeconds = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Occupancy
{
    UPROPERTY()
    int32 Count = 0;

    UPROPERTY()
    bool IsActive = false;

    UPROPERTY()
    FCk_Handle_Timer ReleaseTimer;

    UPROPERTY()
    FCk_Handle_Trigger Trigger;

    // Invalid when the occupancy moves nothing.
    UPROPERTY()
    FCk_Handle_Mover Mover;
}

// Lives on the trigger entity: trigger signals carry only the trigger, so this is how they find their occupancies.
struct FMars_Fragment_Occupancy_TriggerLink
{
    UPROPERTY()
    TArray<FCk_Handle_Occupancy> Occupancies;

    // Several occupancies may share a trigger; binding the setup processor twice to one event would double-fire.
    UPROPERTY()
    bool IsBound = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Occupancy_OnCountChanged(FCk_Handle_Occupancy InOccupancy, int32 InCount);
event void FMars_Delegate_Occupancy_OnCountChanged_MC(FCk_Handle_Occupancy InOccupancy, int32 InCount);

enum EMars_Occupancy_Activation
{
    Inactive,
    Active
}

delegate void FMars_Delegate_Occupancy_OnActiveChanged(FCk_Handle_Occupancy InOccupancy, EMars_Occupancy_Activation InActivation);
event void FMars_Delegate_Occupancy_OnActiveChanged_MC(FCk_Handle_Occupancy InOccupancy, EMars_Occupancy_Activation InActivation);

struct FMars_Fragment_Occupancy_Signals
{
    FMars_Delegate_Occupancy_OnCountChanged_MC OnCountChanged;
    FMars_Delegate_Occupancy_OnActiveChanged_MC OnActiveChanged;
}
