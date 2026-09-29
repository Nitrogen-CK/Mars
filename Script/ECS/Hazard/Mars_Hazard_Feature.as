//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HazardHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Hazard";
    RequiredFragments.Add(FMars_Feature_Hazard);
    Description = "An entity that, while armed, hits whatever is inside its trigger and optionally pushes characters";
}
struct FMars_Feature_Hazard {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Hazard_Spec
{
    UPROPERTY()
    bool StartArmed = false;

    // Launch velocity applied to characters that are hit. Zero pushes nothing.
    UPROPERTY()
    FVector PushImpulse = FVector::ZeroVector;

    // Rotates PushImpulse by the hazard entity's world transform.
    UPROPERTY()
    bool PushIsRelative = true;
}

struct FMars_Tag_Hazard_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Hazard_Params
{
    UPROPERTY()
    FVector PushImpulse = FVector::ZeroVector;

    UPROPERTY()
    bool PushIsRelative = true;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Hazard
{
    UPROPERTY()
    bool IsArmed = false;

    UPROPERTY()
    FCk_Handle_Trigger Trigger;
}

// Lives on the trigger entity: trigger signals carry only the trigger, so this is how they find their hazards.
struct FMars_Fragment_Hazard_TriggerLink
{
    UPROPERTY()
    TArray<FCk_Handle_Hazard> Hazards;

    UPROPERTY()
    bool IsBound = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Hazard_OnHit(FCk_Handle_Hazard InHazard, FCk_Handle InEntity);
event void FMars_Delegate_Hazard_OnHit_MC(FCk_Handle_Hazard InHazard, FCk_Handle InEntity);

delegate void FMars_Delegate_Hazard_OnArmedChanged(FCk_Handle_Hazard InHazard, bool InArmed);
event void FMars_Delegate_Hazard_OnArmedChanged_MC(FCk_Handle_Hazard InHazard, bool InArmed);

struct FMars_Fragment_Hazard_Signals
{
    FMars_Delegate_Hazard_OnHit_MC OnHit;
    FMars_Delegate_Hazard_OnArmedChanged_MC OnArmedChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Hazard_SetArmed
{
    UPROPERTY()
    bool Armed = false;

    FMars_Request_Hazard_SetArmed(bool InArmed)
    {
        Armed = InArmed;
    }
}

// Absolute and latest-wins, so the fragment holds a single pending request; its presence means pending.
struct FMars_Fragment_Hazard_Requests
{
    UPROPERTY()
    FMars_Request_Hazard_SetArmed SetArmed;
}
