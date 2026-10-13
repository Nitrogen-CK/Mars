// A devourer takes one victim through a fixed run of timed phases - Seize, Lift, Blink, Grin, Bite, Swallowed - and then
// lets it go. The feature is only that clock and its ledger: who is held, which phase runs and how far into it. While a
// victim is held it carries FMars_Fragment_Devour_Victim, which is how the victim's own state machine knows it is not
// its own any more (utils_devour::TryGet_Devourer). What each phase looks like (the victim's view, the face that fills
// it, the devourer's body) belongs to whoever composes the feature.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_DevourHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Devour";
    RequiredFragments.Add(FMars_Feature_Devour);
    Description = "A devourer that seizes one victim and takes it through the timed phases of being eaten";
}
struct FMars_Feature_Devour {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// In the order they run. Idle holds no victim.
enum EMars_Devour_Phase
{
    Idle,
    // The victim loses its controls and its view turns to the devourer.
    Seize,
    // The victim is hauled up to the devourer's face.
    Lift,
    // The devourer's eyes shut: everything is black.
    Blink,
    // The eyes reopen and the mouth splits into a grin.
    Grin,
    // The eyes turn and the jaws swing wide, then shut.
    Bite,
    // Black, before the victim is let go.
    Swallowed
}

enum EMars_Devour_End
{
    // Every phase ran.
    Completed,
    // Cancelled by request, or the victim was gone.
    Cancelled
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// How long each phase lasts.
struct FMars_Devour_Timing
{
    UPROPERTY()
    float32 SeizeSeconds = 0.3f;

    UPROPERTY()
    float32 LiftSeconds = 0.8f;

    UPROPERTY()
    float32 BlinkSeconds = 0.25f;

    UPROPERTY()
    float32 GrinSeconds = 1.4f;

    UPROPERTY()
    float32 BiteSeconds = 0.6f;

    UPROPERTY()
    float32 SwallowedSeconds = 1.0f;
}

// The phase's duration; Idle has none (0).
mixin float32 Get_Seconds(const FMars_Devour_Timing& Self, EMars_Devour_Phase InPhase)
{
    if (InPhase == EMars_Devour_Phase::Seize)
    { return Self.SeizeSeconds; }
    if (InPhase == EMars_Devour_Phase::Lift)
    { return Self.LiftSeconds; }
    if (InPhase == EMars_Devour_Phase::Blink)
    { return Self.BlinkSeconds; }
    if (InPhase == EMars_Devour_Phase::Grin)
    { return Self.GrinSeconds; }
    if (InPhase == EMars_Devour_Phase::Bite)
    { return Self.BiteSeconds; }
    if (InPhase == EMars_Devour_Phase::Swallowed)
    { return Self.SwallowedSeconds; }
    return 0.0f;
}

// Every phase lasts a finite, positive time (a zero phase would never be seen and a NaN one would never end).
mixin FMars_Validation Validate(const FMars_Devour_Timing& Self)
{
    for (int32 Index = int32(EMars_Devour_Phase::Seize); Index <= int32(EMars_Devour_Phase::Swallowed); ++Index)
    {
        const auto Phase = EMars_Devour_Phase(Index);
        const auto Seconds = Self.Get_Seconds(Phase);
        if (Math::IsFinite(Seconds) == false)
        { return FMars_Validation(f"{Phase :n}Seconds [{Seconds}] is not finite"); }

        if (Seconds <= 0.0f)
        { return FMars_Validation(f"{Phase :n}Seconds [{Seconds}] must be positive"); }
    }

    return FMars_Validation();
}

struct FMars_Devour_Spec
{
    UPROPERTY()
    FMars_Devour_Timing Timing;

    // The node the victim's view is given to while it is held, built and moved by the caller. Invalid: the victim keeps
    // its own view.
    UPROPERTY()
    FCk_Handle_Transform View;
}

// All-or-nothing: reports the first failing rule, prefixed with its group.
mixin FMars_Validation Validate(const FMars_Devour_Spec& Self)
{
    const auto TimingValidation = Self.Timing.Validate();
    if (TimingValidation.IsValid() == false)
    { return FMars_Validation(f"Timing: {TimingValidation.Get_Error()}"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Devour_Params
{
    UPROPERTY()
    FMars_Devour_Timing Timing;

    UPROPERTY()
    FCk_Handle_Transform View;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the Devour processors and utils_devour::Add.
struct FMars_Fragment_Devour
{
    UPROPERTY()
    EMars_Devour_Phase Phase = EMars_Devour_Phase::Idle;

    // Seconds into Phase.
    UPROPERTY()
    float32 PhaseSeconds = 0.0f;

    // Invalid while Idle.
    UPROPERTY()
    FCk_Handle Victim;
}

// Present while a victim is held; gates UMars_Processor_Devour_Tick.
struct FMars_Tag_Devour_Running {}

// On the victim, for as long as it is held. Written only by the Devour processors.
struct FMars_Fragment_Devour_Victim
{
    UPROPERTY()
    FCk_Handle_Devour Devourer;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Every phase entered, in order, Seize first. Idle is never broadcast: OnEnded says the run is over.
delegate void FMars_Delegate_Devour_OnPhaseChanged(FCk_Handle_Devour InDevour, EMars_Devour_Phase InPhase);
event void FMars_Delegate_Devour_OnPhaseChanged_MC(FCk_Handle_Devour InDevour, EMars_Devour_Phase InPhase);

// The victim has been let go (it may be invalid: a victim that was destroyed cancels its run).
delegate void FMars_Delegate_Devour_OnEnded(FCk_Handle_Devour InDevour, FCk_Handle InVictim, EMars_Devour_End InEnd);
event void FMars_Delegate_Devour_OnEnded_MC(FCk_Handle_Devour InDevour, FCk_Handle InVictim, EMars_Devour_End InEnd);

struct FMars_Fragment_Devour_Signals
{
    FMars_Delegate_Devour_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_Devour_OnEnded_MC OnEnded;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Seizes InVictim. Ignored while a victim is held, and for a victim that is invalid, is the devourer itself or is already
// held by another devourer.
struct FMars_Request_Devour_Begin
{
    UPROPERTY()
    FCk_Handle Victim;

    FMars_Request_Devour_Begin() {}

    FMars_Request_Devour_Begin(const FCk_Handle& InVictim)
    {
        Victim = InVictim;
    }
}

// Lets the victim go at once. Ignored while Idle. AngelScript rejects a TArray of an empty struct, so it carries one
// placeholder field.
struct FMars_Request_Devour_Cancel
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Devour_Cancel() {}
}

// Drain order Cancel -> Begin (see UMars_Processor_Devour_HandleRequests).
struct FMars_Fragment_Devour_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Devour_Cancel> CancelRequests;

    UPROPERTY()
    TArray<FMars_Request_Devour_Begin> BeginRequests;
}
