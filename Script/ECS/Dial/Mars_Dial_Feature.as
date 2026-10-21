//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_DialHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Dial";
    RequiredFragments.Add(FMars_Feature_Dial);
    Description = "A ring of detents and the index it points at; it turns one way or the other and can be locked";
}
struct FMars_Feature_Dial {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Dial_Spec
{
    UPROPERTY()
    int32 Positions = 6;

    UPROPERTY()
    int32 StartIndex = 0;
}

// At least two detents, and a start on one of them.
mixin FMars_Validation Validate(const FMars_Dial_Spec& Self)
{
    if (Self.Positions < 2)
    { return FMars_Validation(f"Positions [{Self.Positions}] must be at least 2: a one-detent dial never turns"); }

    if (Self.StartIndex < 0 || Self.StartIndex >= Self.Positions)
    { return FMars_Validation(f"StartIndex [{Self.StartIndex}] must be in [0, {Self.Positions})"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Dial_Params
{
    UPROPERTY()
    int32 Positions = 6;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_Dial_HandleRequests and utils_dial::Add.
struct FMars_Fragment_Dial
{
    UPROPERTY()
    int32 Index = 0;

    UPROPERTY()
    bool Locked = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Dial_OnIndexChanged(FCk_Handle_Dial InDial, int32 InIndex);
event void FMars_Delegate_Dial_OnIndexChanged_MC(FCk_Handle_Dial InDial, int32 InIndex);

struct FMars_Fragment_Dial_Signals
{
    FMars_Delegate_Dial_OnIndexChanged_MC OnIndexChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Positive turns forward, negative back; the dial wraps.
struct FMars_Request_Dial_Step
{
    UPROPERTY()
    int32 Detents = 1;

    FMars_Request_Dial_Step() {}

    FMars_Request_Dial_Step(int32 InDetents)
    {
        Detents = InDetents;
    }
}

struct FMars_Request_Dial_SetLocked
{
    UPROPERTY()
    bool Locked = true;

    FMars_Request_Dial_SetLocked() {}

    FMars_Request_Dial_SetLocked(bool InLocked)
    {
        Locked = InLocked;
    }
}

// The last lock request applies first, then the steps in arrival order: a step queued beside a lock is judged against it.
struct FMars_Fragment_Dial_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Dial_SetLocked> LockRequests;

    UPROPERTY()
    TArray<FMars_Request_Dial_Step> StepRequests;
}
