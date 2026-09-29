//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_SwitchHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Switch";
    RequiredFragments.Add(FMars_Feature_Switch);
    Description = "An entity with a momentary push switch that auto-releases after a hold time";
}
struct FMars_Feature_Switch {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Switch_Spec
{
    // Button node local offset while pressed.
    UPROPERTY()
    FVector PressOffset = FVector(0.0, 0.0, -6.0);

    UPROPERTY()
    float32 MoveDuration = 0.15f;

    // Re-pressing while held restarts the countdown.
    UPROPERTY()
    float32 HoldSeconds = 1.0f;
}

struct FMars_Tag_Switch_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Switch_Params
{
    UPROPERTY()
    FVector PressOffset = FVector(0.0, 0.0, -6.0);

    UPROPERTY()
    float32 MoveDuration = 0.15f;

    UPROPERTY()
    float32 HoldSeconds = 1.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Switch
{
    UPROPERTY()
    bool IsPressed = false;

    UPROPERTY()
    FCk_Handle_SceneNode ButtonNode;

    UPROPERTY()
    FCk_Handle_Tween MoveTween;

    UPROPERTY()
    FCk_Handle_Timer HoldTimer;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Switch_OnPressedChanged(FCk_Handle_Switch InSwitch, bool InPressed);
event void FMars_Delegate_Switch_OnPressedChanged_MC(FCk_Handle_Switch InSwitch, bool InPressed);

struct FMars_Fragment_Switch_Signals
{
    FMars_Delegate_Switch_OnPressedChanged_MC OnPressedChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Switch_Press {}

struct FMars_Request_Switch_Release {}

// Presence = requested. A press in the same frame as a release wins (it re-arms the hold).
struct FMars_Fragment_Switch_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_Switch_Press> PressRequest;

    UPROPERTY()
    TOptional<FMars_Request_Switch_Release> ReleaseRequest;
}
