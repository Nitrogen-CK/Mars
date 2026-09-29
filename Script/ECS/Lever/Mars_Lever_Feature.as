//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_LeverHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Lever";
    RequiredFragments.Add(FMars_Feature_Lever);
    Description = "An entity with a two-state lever whose handle node rotates when pulled";
}
struct FMars_Feature_Lever {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Lever_Spec
{
    // Pitch of the handle node when pulled. Keep within (-90, 90): the tween restarts from the node's current
    // pitch, read back through a rotator.
    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.35f;

    UPROPERTY()
    bool StartPulled = false;
}

struct FMars_Tag_Lever_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Lever_Params
{
    UPROPERTY()
    float32 PulledAngle = 70.0f;

    UPROPERTY()
    float32 MoveDuration = 0.35f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Lever
{
    UPROPERTY()
    bool IsPulled = false;

    UPROPERTY()
    FCk_Handle_SceneNode HandleNode;

    UPROPERTY()
    FCk_Handle_Tween MoveTween;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Lever_OnPulledChanged(FCk_Handle_Lever InLever, bool InPulled);
event void FMars_Delegate_Lever_OnPulledChanged_MC(FCk_Handle_Lever InLever, bool InPulled);

struct FMars_Fragment_Lever_Signals
{
    FMars_Delegate_Lever_OnPulledChanged_MC OnPulledChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Lever_SetPulled
{
    UPROPERTY()
    bool Pulled = false;

    FMars_Request_Lever_SetPulled() {}

    FMars_Request_Lever_SetPulled(bool InPulled)
    {
        Pulled = InPulled;
    }
}

// Absolute; the latest request in a frame wins.
struct FMars_Fragment_Lever_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_Lever_SetPulled> SetPulledRequest;
}
