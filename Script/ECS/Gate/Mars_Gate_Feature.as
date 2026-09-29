//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_GateHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Gate";
    RequiredFragments.Add(FMars_Feature_Gate);
    Description = "An entity with a gate whose moving node slides between closed and open offsets";
}
struct FMars_Feature_Gate {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Gate_Spec
{
    // Local offset of the moving node when open.
    UPROPERTY()
    FVector OpenOffset = FVector(0.0, 0.0, 220.0);

    UPROPERTY()
    float32 MoveDuration = 0.8f;

    UPROPERTY()
    ECk_TweenEasing Easing = ECk_TweenEasing::InOutSine;

    UPROPERTY()
    bool StartOpen = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Gate_Params
{
    UPROPERTY()
    FVector OpenOffset = FVector(0.0, 0.0, 220.0);

    UPROPERTY()
    float32 MoveDuration = 0.8f;

    UPROPERTY()
    ECk_TweenEasing Easing = ECk_TweenEasing::InOutSine;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Gate
{
    UPROPERTY()
    bool IsOpen = false;

    UPROPERTY()
    FCk_Handle_SceneNode MovingNode;

    UPROPERTY()
    FCk_Handle_Tween MoveTween;
}

struct FMars_Tag_Gate_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Gate_OnOpenChanged(FCk_Handle_Gate InGate, bool InOpen);
event void FMars_Delegate_Gate_OnOpenChanged_MC(FCk_Handle_Gate InGate, bool InOpen);

struct FMars_Fragment_Gate_Signals
{
    FMars_Delegate_Gate_OnOpenChanged_MC OnOpenChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Gate_SetOpen
{
    UPROPERTY()
    bool Open = false;

    FMars_Request_Gate_SetOpen(bool InOpen)
    {
        Open = InOpen;
    }
}

// Absolute and latest-wins: one pending value, overwritten by each new request.
struct FMars_Fragment_Gate_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_Gate_SetOpen> SetOpenRequest;
}
