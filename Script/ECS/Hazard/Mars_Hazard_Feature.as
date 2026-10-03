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

// Whether a hazard hits what is inside its trigger.
enum EMars_Hazard_Arming
{
    Disarmed,
    Armed
}

// Spawn params of the placeable mechanism scripts: per-instance values live in saved maps.
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
    FMars_Hazard_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Hazard
{
    UPROPERTY()
    EMars_Hazard_Arming Arming = EMars_Hazard_Arming::Disarmed;

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

delegate void FMars_Delegate_Hazard_OnArmedChanged(FCk_Handle_Hazard InHazard, EMars_Hazard_Arming InArming);
event void FMars_Delegate_Hazard_OnArmedChanged_MC(FCk_Handle_Hazard InHazard, EMars_Hazard_Arming InArming);

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
    EMars_Hazard_Arming Arming = EMars_Hazard_Arming::Armed;

    FMars_Request_Hazard_SetArmed() {}

    FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming InArming)
    {
        Arming = InArming;
    }
}

// Absolute: the drain applies only the last request, and only a change broadcasts.
struct FMars_Fragment_Hazard_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Hazard_SetArmed> SetArmedRequests;
}
