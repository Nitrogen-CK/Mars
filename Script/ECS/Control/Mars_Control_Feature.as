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

enum EMars_Control_Activation
{
    Inactive,
    Active
}

// Which way the next pull runs: toward the end pose (alpha 1), or back toward the start pose (alpha 0).
enum EMars_Control_PullDirection
{
    TowardEnd,
    TowardStart
}

// How a ManuallyCompleted control is pulled: the player grips it (Use) and swings the look input along PullAxis. The
// spawn-params generator emits a non-default value as the positional constructor call.
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

    // The spawn-params generator emits a non-default value as this positional call, Manipulation as a nested one.
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

// A grip in progress, from BeginManipulation to the end (threshold or EndManipulation).
struct FMars_Control_Manipulation
{
    // The ManuallyCompleted interaction the threshold ends; invalid once it was cancelled.
    UPROPERTY()
    FCk_Handle_Interaction Interaction;

    UPROPERTY()
    FCk_Handle Manipulator;

    // Handle position 0..1, seeded from the Mover's alpha on Begin, else from where the pull starts.
    UPROPERTY()
    float32 Alpha = 0.0f;

    // Where the grip has been pulled to, 0..1: the nudge integral, clamped.
    UPROPERTY()
    float32 Pull = 0.0f;

    // Alpha per second.
    UPROPERTY()
    float32 Velocity = 0.0f;
}

// Written only by the two Control processors.
struct FMars_Fragment_Control
{
    UPROPERTY()
    bool IsActive = false;

    UPROPERTY()
    FCk_Handle_Timer ReleaseTimer;

    // Invalid when the control moves nothing.
    UPROPERTY()
    FCk_Handle_Mover Mover;

    // Set while gripped.
    UPROPERTY()
    TOptional<FMars_Control_Manipulation> Manipulation;
}

// Present while Manipulation is set; gates UMars_Processor_Control_Tick.
struct FMars_Tag_Control_Manipulating {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Control_OnActiveChanged(FCk_Handle_Control InControl, EMars_Control_Activation InActivation);
event void FMars_Delegate_Control_OnActiveChanged_MC(FCk_Handle_Control InControl, EMars_Control_Activation InActivation);

// Every accepted use, including one that does not change IsActive (a Momentary re-engage).
delegate void FMars_Delegate_Control_OnEngaged(FCk_Handle_Control InControl);
event void FMars_Delegate_Control_OnEngaged_MC(FCk_Handle_Control InControl);

// Gripped when a manipulation begins; Released when it ends, at the threshold or on EndManipulation.
enum EMars_Control_Grip
{
    Released,
    Gripped
}

delegate void FMars_Delegate_Control_OnManipulationChanged(FCk_Handle_Control InControl, EMars_Control_Grip InGrip);
event void FMars_Delegate_Control_OnManipulationChanged_MC(FCk_Handle_Control InControl, EMars_Control_Grip InGrip);

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

// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Control_Engage
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Control_Engage() {}
}

// Activating a Momentary control arms its release timer, as an engage would.
struct FMars_Request_Control_SetActive
{
    UPROPERTY()
    EMars_Control_Activation Activation = EMars_Control_Activation::Inactive;

    FMars_Request_Control_SetActive() {}

    FMars_Request_Control_SetActive(EMars_Control_Activation InActivation)
    {
        Activation = InActivation;
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

// Payload-less: one placeholder field (request doctrine).
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
