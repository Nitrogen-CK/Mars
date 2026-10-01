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

enum EMars_Control_Behavior
{
    Toggle,
    // Activates on engage and releases ActiveSeconds later; engaging again restarts the countdown.
    Momentary
}

// How a ManuallyCompleted control is pulled: the player grips it (Use) and swings the look input along PullAxis.
// Field order is the positional constructor's order (the spawn-params generator emits it when a subclass changes
// a default).
struct FMars_Control_Manipulation_Spec
{
    // Direction the grip travels toward the end pose, in the control entity's own space (lever: local -X, the
    // handle top pitching over). Zero = no screen projection: raw pitch, mouse down pulls.
    UPROPERTY()
    FVector PullAxis = FVector::ZeroVector;

    // Alpha per degree of pull (0.02 = 50 degrees of would-be look for the full travel).
    UPROPERTY()
    float32 AlphaPerDegree = 0.02f;

    // Fraction of the travel toward the far pose that counts as pulled over (0, 1].
    UPROPERTY()
    float32 EngageAlpha = 0.85f;

    // The handle follows the pulled point through a damped spring: Alpha'' = Stiffness (Pull - Alpha) - Damping Alpha'.
    UPROPERTY()
    float32 Stiffness = 60.0f;

    UPROPERTY()
    float32 Damping = 12.0f;

    // On: the handle springs back to rest after every pull and every pull past EngageAlpha engages (a pull chain).
    // Off: the handle stays where the pull leaves it and follows IsActive, so the next pull runs the other way (a lever).
    UPROPERTY()
    bool ReturnsToRest = false;

    FMars_Control_Manipulation_Spec() {}

    FMars_Control_Manipulation_Spec(
        FVector InPullAxis,
        float32 InAlphaPerDegree,
        float32 InEngageAlpha,
        float32 InStiffness,
        float32 InDamping,
        bool InReturnsToRest)
    {
        PullAxis = InPullAxis;
        AlphaPerDegree = InAlphaPerDegree;
        EngageAlpha = InEngageAlpha;
        Stiffness = InStiffness;
        Damping = InDamping;
        ReturnsToRest = InReturnsToRest;
    }
}

struct FMars_Control_Spec
{
    // Instant completes on Use; Timed holds HoldSeconds; ManuallyCompleted is pulled per Manipulation.
    UPROPERTY()
    ECk_Interaction_CompletionPolicy Interaction = ECk_Interaction_CompletionPolicy::Instant;

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

    // ManuallyCompleted only.
    UPROPERTY()
    FMars_Control_Manipulation_Spec Manipulation;

    // Field order: the spawn-params generator emits a class whose `default Control.*` differs from these defaults as
    // this positional call (Switch, Seal, HandWheel, Lever), Manipulation as a nested positional call.
    FMars_Control_Spec(
        ECk_Interaction_CompletionPolicy InInteraction,
        float32 InHoldSeconds,
        EMars_Control_Behavior InBehavior,
        float32 InActiveSeconds,
        bool InStartActive,
        FMars_Control_Manipulation_Spec InManipulation)
    {
        Interaction = InInteraction;
        HoldSeconds = InHoldSeconds;
        Behavior = InBehavior;
        ActiveSeconds = InActiveSeconds;
        StartActive = InStartActive;
        Manipulation = InManipulation;
    }
}

// Timed holds for a positive time; ManuallyCompleted engages inside (0, 1], moves per degree and has a spring to move
// with that never feeds energy in (no negative damping); Momentary releases after a positive time.
mixin FMars_Validation Validate(const FMars_Control_Spec& Self)
{
    if (Self.Interaction == ECk_Interaction_CompletionPolicy::Timed && Self.HoldSeconds <= 0.0f)
    { return FMars_Validation(f"Timed control has a non-positive HoldSeconds [{Self.HoldSeconds}]"); }

    if (Self.Interaction == ECk_Interaction_CompletionPolicy::ManuallyCompleted)
    {
        const auto& Manipulation = Self.Manipulation;
        if (Manipulation.EngageAlpha <= 0.0f || Manipulation.EngageAlpha > 1.0f)
        { return FMars_Validation(f"ManuallyCompleted control has Manipulation.EngageAlpha [{Manipulation.EngageAlpha}] outside (0, 1]"); }

        if (Manipulation.AlphaPerDegree <= 0.0f)
        { return FMars_Validation(f"ManuallyCompleted control has a non-positive Manipulation.AlphaPerDegree [{Manipulation.AlphaPerDegree}]"); }

        if (Manipulation.Stiffness <= 0.0f)
        { return FMars_Validation(f"ManuallyCompleted control has a non-positive Manipulation.Stiffness [{Manipulation.Stiffness}]"); }

        if (Manipulation.Damping < 0.0f)
        { return FMars_Validation(f"ManuallyCompleted control has a negative Manipulation.Damping [{Manipulation.Damping}]"); }
    }

    if (Self.Behavior == EMars_Control_Behavior::Momentary && Self.ActiveSeconds <= 0.0f)
    { return FMars_Validation(f"Momentary control has a non-positive ActiveSeconds [{Self.ActiveSeconds}]"); }

    return FMars_Validation();
}

struct FMars_Tag_Control_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Control_Params
{
    UPROPERTY()
    ECk_Interaction_CompletionPolicy CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;

    UPROPERTY()
    float32 HoldSeconds = 1.5f;

    UPROPERTY()
    EMars_Control_Behavior Behavior = EMars_Control_Behavior::Toggle;

    UPROPERTY()
    float32 ActiveSeconds = 1.0f;

    // PullAxis normalised (or zero) by Add.
    UPROPERTY()
    FMars_Control_Manipulation_Spec Manipulation;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Live only between BeginManipulation and the end (threshold or EndManipulation). Written by the two Control processors.
struct FMars_Control_Manipulation
{
    UPROPERTY()
    bool IsActive = false;

    // The ManuallyCompleted interaction the threshold ends; may be invalid.
    UPROPERTY()
    FCk_Handle_Interaction Interaction;

    UPROPERTY()
    FCk_Handle Manipulator;

    // Handle position 0..1 (seeded from the Mover's alpha on Begin, else IsActive ? 1 : 0).
    UPROPERTY()
    float32 Alpha = 0.0f;

    // Where the grip has been pulled to, 0..1: the nudge integral, clamped.
    UPROPERTY()
    float32 Pull = 0.0f;

    // Alpha per second.
    UPROPERTY()
    float32 Velocity = 0.0f;
}

struct FMars_Fragment_Control
{
    UPROPERTY()
    bool IsActive = false;

    UPROPERTY()
    FCk_Handle_Timer ReleaseTimer;

    // Invalid when the control moves nothing.
    UPROPERTY()
    FCk_Handle_Mover Mover;

    UPROPERTY()
    FMars_Control_Manipulation Manipulation;
}

// Present while Manipulation.IsActive; gates UMars_Processor_Control_Tick.
struct FMars_Tag_Control_Manipulating {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Control_OnActiveChanged(FCk_Handle_Control InControl, bool InActive);
event void FMars_Delegate_Control_OnActiveChanged_MC(FCk_Handle_Control InControl, bool InActive);

// Every accepted use, including one that does not change IsActive (a Momentary re-engage).
delegate void FMars_Delegate_Control_OnEngaged(FCk_Handle_Control InControl);
event void FMars_Delegate_Control_OnEngaged_MC(FCk_Handle_Control InControl);

delegate void FMars_Delegate_Control_OnManipulationChanged(FCk_Handle_Control InControl, bool InManipulating);
event void FMars_Delegate_Control_OnManipulationChanged_MC(FCk_Handle_Control InControl, bool InManipulating);

// 0..1 toward EngageAlpha in the pull's direction, every manipulated frame; 0 when the manipulation ends.
delegate void FMars_Delegate_Control_OnManipulationProgress(FCk_Handle_Control InControl, float32 InProgress);
event void FMars_Delegate_Control_OnManipulationProgress_MC(FCk_Handle_Control InControl, float32 InProgress);

struct FMars_Fragment_Control_Signals
{
    FMars_Delegate_Control_OnActiveChanged_MC OnActiveChanged;
    FMars_Delegate_Control_OnEngaged_MC OnEngaged;
    FMars_Delegate_Control_OnManipulationChanged_MC OnManipulationChanged;
    FMars_Delegate_Control_OnManipulationProgress_MC OnManipulationProgress;
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

struct FMars_Request_Control_BeginManipulation
{
    // The live ManuallyCompleted interaction the threshold will end; may be invalid.
    UPROPERTY()
    FCk_Handle_Interaction Interaction;

    UPROPERTY()
    FCk_Handle Manipulator;

    FMars_Request_Control_BeginManipulation() {}

    FMars_Request_Control_BeginManipulation(FCk_Handle_Interaction InInteraction, FCk_Handle InManipulator)
    {
        Interaction = InInteraction;
        Manipulator = InManipulator;
    }
}

// Degrees of pull along PullAxis this frame; positive toward the end pose. Summed per drain.
struct FMars_Request_Control_Nudge
{
    UPROPERTY()
    float32 PullDegrees = 0.0f;

    FMars_Request_Control_Nudge() {}

    FMars_Request_Control_Nudge(float32 InPullDegrees)
    {
        PullDegrees = InPullDegrees;
    }
}

// AngelScript rejects an empty struct in a TOptional/TArray, so it carries one placeholder field.
struct FMars_Request_Control_EndManipulation
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Control_EndManipulation() {}
}

// Presence = requested; SetActive and the manipulation pair are latest-wins, nudges accumulate. Applied SetActive ->
// Engage -> EndManipulation -> BeginManipulation -> Nudges: an engage in the same frame as a Momentary release re-arms
// it, and an end and a re-grab in one frame leave the control gripped with the nudges on the new grip.
struct FMars_Fragment_Control_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_Control_Engage> EngageRequest;

    UPROPERTY()
    TOptional<FMars_Request_Control_SetActive> SetActiveRequest;

    UPROPERTY()
    TOptional<FMars_Request_Control_EndManipulation> EndManipulationRequest;

    UPROPERTY()
    TOptional<FMars_Request_Control_BeginManipulation> BeginManipulationRequest;

    UPROPERTY()
    TArray<FMars_Request_Control_Nudge> NudgeRequests;
}
