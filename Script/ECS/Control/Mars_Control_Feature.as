//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_ControlHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Control";
    RequiredFragments.Add(FMars_Feature_Control);
    Description = "An entity whose interaction toggles or pulses an active state (lever, switch, hand wheel, seal)";
}
struct FMars_Feature_Control {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Control_Interaction
{
    Instant,
    // Hold to complete, through CkInteraction's Timed completion.
    Timed
}

enum EMars_Control_Behavior
{
    Toggle,
    // Activates on engage and releases ActiveSeconds later; engaging again restarts the countdown.
    Momentary
}

struct FMars_Control_Spec
{
    UPROPERTY()
    EMars_Control_Interaction Interaction = EMars_Control_Interaction::Instant;

    // Timed only.
    UPROPERTY()
    float32 HoldSeconds = 1.5f;

    UPROPERTY()
    EMars_Control_Behavior Behavior = EMars_Control_Behavior::Toggle;

    // Momentary only.
    UPROPERTY()
    float32 ActiveSeconds = 1.0f;

    UPROPERTY()
    bool StartActive = false;

    // Field order: the spawn-params generator emits a class whose `default Control.*` differs from these defaults as
    // this positional call (Switch, Seal, HandWheel).
    FMars_Control_Spec(
        EMars_Control_Interaction InInteraction,
        float32 InHoldSeconds,
        EMars_Control_Behavior InBehavior,
        float32 InActiveSeconds,
        bool InStartActive)
    {
        Interaction = InInteraction;
        HoldSeconds = InHoldSeconds;
        Behavior = InBehavior;
        ActiveSeconds = InActiveSeconds;
        StartActive = InStartActive;
    }
}

struct FMars_Tag_Control_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Control_Params
{
    UPROPERTY()
    EMars_Control_Behavior Behavior = EMars_Control_Behavior::Toggle;

    UPROPERTY()
    float32 ActiveSeconds = 1.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Control
{
    UPROPERTY()
    bool IsActive = false;

    UPROPERTY()
    FCk_Handle_Timer ReleaseTimer;

    // Invalid when the control moves nothing.
    UPROPERTY()
    FCk_Handle_Mover Mover;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Control_OnActiveChanged(FCk_Handle_Control InControl, bool InActive);
event void FMars_Delegate_Control_OnActiveChanged_MC(FCk_Handle_Control InControl, bool InActive);

// Every accepted use, including one that does not change IsActive (a Momentary re-engage).
delegate void FMars_Delegate_Control_OnEngaged(FCk_Handle_Control InControl);
event void FMars_Delegate_Control_OnEngaged_MC(FCk_Handle_Control InControl);

struct FMars_Fragment_Control_Signals
{
    FMars_Delegate_Control_OnActiveChanged_MC OnActiveChanged;
    FMars_Delegate_Control_OnEngaged_MC OnEngaged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Control_Engage {}

struct FMars_Request_Control_SetActive
{
    UPROPERTY()
    bool Active = false;

    FMars_Request_Control_SetActive(bool InActive)
    {
        Active = InActive;
    }
}

// Presence = requested; SetActive is latest-wins. SetActive applies before Engage, so an engage in the same frame as
// a Momentary release re-arms it.
struct FMars_Fragment_Control_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_Control_Engage> EngageRequest;

    UPROPERTY()
    TOptional<FMars_Request_Control_SetActive> SetActiveRequest;
}
