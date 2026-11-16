// Stance A. FMars_Fragment_Gate (the state: closed, open, close deferred) is the replicated ledger, written by the
// authority's request drain; the threshold is decided there. The moving node and threshold handles stay local in
// Params (built identically on every machine). A client mirrors the ledger: it moves its own Mover (stance D) and
// broadcasts OnOpenChanged from what replicated after the state its copy was born into.

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

enum EMars_Gate_Position
{
    Closed,
    Open
}

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

    // Unset = the gate closes as soon as it is told to. Set = a doorway trigger with this spec on the gate's root: a close
    // waits while anything it detects is inside, and goes through once the last of them leaves.
    UPROPERTY()
    TOptional<FMars_Trigger_Spec> Threshold;
}

// A leaf that moves, in non-negative time, and a valid threshold when one is set.
mixin FMars_Validation Validate(const FMars_Gate_Spec& Self)
{
    if (Self.OpenOffset.IsNearlyZero())
    { return FMars_Validation("OpenOffset must move the leaf"); }

    if (Self.MoveDuration < 0.0f)
    { return FMars_Validation(f"MoveDuration [{Self.MoveDuration}] must not be negative"); }

    if (Self.Threshold.IsSet())
    {
        const auto ThresholdValidation = Self.Threshold.GetValue().Validate();
        if (ThresholdValidation.IsValid() == false)
        { return FMars_Validation(f"Threshold: {ThresholdValidation.Get_Error()}"); }
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Gate_State
{
    Closed,
    Open,
    // Told to close while the threshold was occupied: still open, and closes once the threshold clears.
    CloseDeferred
}

struct FMars_Fragment_Gate
{
    UPROPERTY()
    EMars_Gate_State State = EMars_Gate_State::Closed;
}

// Set once by Add, the same on every machine; never replicated (scene nodes and triggers do not cross the wire).
struct FMars_Fragment_Gate_Params
{
    // Carries the Mover that slides the leaf.
    UPROPERTY()
    FCk_Handle_SceneNode MovingNode;

    // Invalid when the spec set no Threshold.
    UPROPERTY()
    FCk_Handle_Trigger Threshold;
}

// Non-authority only (the authority's setup removes it).
struct FMars_Fragment_Gate_Mirror
{
    // The ledger as this machine last reconciled it, seeded with the ledger this machine composed, so a standing open
    // gate is announced once.
    UPROPERTY()
    FMars_Fragment_Gate Last;

    // Whether this copy has taken the state it was born into.
    UPROPERTY()
    EMars_Net_InitialState InitialState = EMars_Net_InitialState::Awaited;
}

struct FMars_Tag_Gate_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Gate_OnOpenChanged(FCk_Handle_Gate InGate, EMars_Gate_Position InPosition);
event void FMars_Delegate_Gate_OnOpenChanged_MC(FCk_Handle_Gate InGate, EMars_Gate_Position InPosition);

struct FMars_Fragment_Gate_Signals
{
    FMars_Delegate_Gate_OnOpenChanged_MC OnOpenChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Gate_SetPosition
{
    UPROPERTY()
    EMars_Gate_Position Position = EMars_Gate_Position::Closed;

    FMars_Request_Gate_SetPosition() {}

    FMars_Request_Gate_SetPosition(EMars_Gate_Position InPosition)
    {
        Position = InPosition;
    }
}

// Retries a deferred close once the threshold has cleared; does nothing when no close is waiting. AngelScript rejects a
// TArray of an empty struct, so it carries one placeholder field.
struct FMars_Request_Gate_RetryClose
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Gate_RetryClose() {}
}

// SetPosition is absolute: the latest one wins.
struct FMars_Fragment_Gate_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Gate_SetPosition> SetPositionRequests;

    UPROPERTY()
    TArray<FMars_Request_Gate_RetryClose> RetryCloseRequests;
}
