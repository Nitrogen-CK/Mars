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

    UPROPERTY()
    bool IsBound = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Occupancy_OnCountChanged(FCk_Handle_Occupancy InOccupancy, int32 InCount);
event void FMars_Delegate_Occupancy_OnCountChanged_MC(FCk_Handle_Occupancy InOccupancy, int32 InCount);

delegate void FMars_Delegate_Occupancy_OnActiveChanged(FCk_Handle_Occupancy InOccupancy, bool InActive);
event void FMars_Delegate_Occupancy_OnActiveChanged_MC(FCk_Handle_Occupancy InOccupancy, bool InActive);

struct FMars_Fragment_Occupancy_Signals
{
    FMars_Delegate_Occupancy_OnCountChanged_MC OnCountChanged;
    FMars_Delegate_Occupancy_OnActiveChanged_MC OnActiveChanged;
}
