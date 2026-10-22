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
    // The detent nearest Angle.
    UPROPERTY()
    int32 Index = 0;

    // Where the pointer stands, degrees in [0, 360): Index * 360 / Positions at rest, anywhere between while turned.
    UPROPERTY()
    float32 Angle = 0.0f;

    UPROPERTY()
    bool Locked = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Dial_OnIndexChanged(FCk_Handle_Dial InDial, int32 InIndex);
event void FMars_Delegate_Dial_OnIndexChanged_MC(FCk_Handle_Dial InDial, int32 InIndex);

// Once per drain that moved the pointer: where it stands now and how many detents it passed on the way (steps count each
// detent; a turn counts each half-detent line it crossed; a settle crosses none).
delegate void FMars_Delegate_Dial_OnAngleChanged(FCk_Handle_Dial InDial, float32 InAngle, int32 InDetentsCrossed);
event void FMars_Delegate_Dial_OnAngleChanged_MC(FCk_Handle_Dial InDial, float32 InAngle, int32 InDetentsCrossed);

struct FMars_Fragment_Dial_Signals
{
    FMars_Delegate_Dial_OnIndexChanged_MC OnIndexChanged;
    FMars_Delegate_Dial_OnAngleChanged_MC OnAngleChanged;
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

// Degrees of free turn: the pointer follows, positive forward (toward higher indices), and Index becomes the detent nearest
// it. Summed per drain.
struct FMars_Request_Dial_Turn
{
    UPROPERTY()
    float32 Degrees = 0.0f;

    FMars_Request_Dial_Turn() {}

    FMars_Request_Dial_Turn(float32 InDegrees)
    {
        Degrees = InDegrees;
    }
}

// Snaps the pointer onto the detent nearest it (a let-go knob).
struct FMars_Request_Dial_Settle
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Dial_Settle() {}
}

// The last lock request applies first (a locked dial drops everything else), then the steps in arrival order, then the
// summed turn, then a settle: a step or a turn queued beside a lock is judged against it, and a settle in the same drain as
// a turn lands on the detent the turn ended nearest.
struct FMars_Fragment_Dial_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Dial_SetLocked> LockRequests;

    UPROPERTY()
    TArray<FMars_Request_Dial_Step> StepRequests;

    UPROPERTY()
    TArray<FMars_Request_Dial_Turn> TurnRequests;

    UPROPERTY()
    TArray<FMars_Request_Dial_Settle> SettleRequests;
}
