//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_DicingHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Dicing";
    RequiredFragments.Add(FMars_Feature_Dicing);
    Description = "A dicing minigame on a station: the pile's material state, the highlighted band on the board and the cleaver the operator's hand slides and chops with";
}
struct FMars_Feature_Dicing {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The pile's material, in processing order. More useful chops than the requested state over-process it.
enum EMars_Dicing_State
{
    WholeLeaves,
    CoarseChop,
    FineFlecks,
    GreenPaste
}

// Board frame: the hand (and the cleaver under it) slides along the station's local Y about the board centre. A chop is
// aligned when the hand is within BandHalfWidth of the band's centre. The cleaver's Mover has one Duration for both
// directions (the entity script sets it to ChopDownSeconds), so the recover takes as long as the strike.
struct FMars_Dicing_Spec
{
    // The hand's lateral travel each side of the board centre (uu).
    UPROPERTY()
    float32 BoardHalfWidth = 40.0f;

    // Aligned when |Hand - Band| <= this (uu).
    UPROPERTY()
    float32 BandHalfWidth = 12.0f;

    // Useful (aligned) chops that advance the pile one state.
    UPROPERTY()
    int32 ChopsPerState = 4;

    // The texture the recipe asks for; OnRequestedStateReached fires when the pile reaches it.
    UPROPERTY()
    EMars_Dicing_State RequestedState = EMars_Dicing_State::FineFlecks;

    // uu of hand travel per degree of look yaw.
    UPROPERTY()
    float32 LateralPerDegree = 1.5f;

    // The cleaver's strike (and, through the Mover's single Duration, its recover) in seconds.
    UPROPERTY()
    float32 ChopDownSeconds = 0.10f;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Dicing_Nodes Nodes;

    FMars_Dicing_Spec() {}

    FMars_Dicing_Spec(
        float32 InBoardHalfWidth,
        float32 InBandHalfWidth,
        int32 InChopsPerState,
        EMars_Dicing_State InRequestedState,
        float32 InLateralPerDegree,
        float32 InChopDownSeconds)
    {
        BoardHalfWidth = InBoardHalfWidth;
        BandHalfWidth = InBandHalfWidth;
        ChopsPerState = InChopsPerState;
        RequestedState = InRequestedState;
        LateralPerDegree = InLateralPerDegree;
        ChopDownSeconds = InChopDownSeconds;
    }
}

// A board or band with no width has nowhere to aim, a band as wide as the board is always aligned, zero chops per state
// would advance without chopping, a zero-length strike is no motion at all, and the pile starts as whole leaves, so the
// requested texture must take at least one chop.
mixin FMars_Validation Validate(const FMars_Dicing_Spec& Self)
{
    if (Self.BoardHalfWidth <= 0.0f)
    { return FMars_Validation(f"Dicing has a non-positive BoardHalfWidth [{Self.BoardHalfWidth}]"); }

    if (Self.BandHalfWidth <= 0.0f)
    { return FMars_Validation(f"Dicing has a non-positive BandHalfWidth [{Self.BandHalfWidth}]"); }

    if (Self.BandHalfWidth >= Self.BoardHalfWidth)
    { return FMars_Validation(f"Dicing has BandHalfWidth [{Self.BandHalfWidth}] not below BoardHalfWidth [{Self.BoardHalfWidth}]"); }

    if (Self.ChopsPerState < 1)
    { return FMars_Validation(f"Dicing has ChopsPerState [{Self.ChopsPerState}] below 1"); }

    if (Self.LateralPerDegree <= 0.0f)
    { return FMars_Validation(f"Dicing has a non-positive LateralPerDegree [{Self.LateralPerDegree}]"); }

    if (Self.ChopDownSeconds <= 0.0f)
    { return FMars_Validation(f"Dicing has a non-positive ChopDownSeconds [{Self.ChopDownSeconds}]"); }

    if (Self.RequestedState == EMars_Dicing_State::WholeLeaves)
    { return FMars_Validation("Dicing has RequestedState WholeLeaves: the requested texture must take at least one chop"); }

    return FMars_Validation();
}

// The nodes the placing script builds for the feature: the lateral node the hand slides (its offset Y is the hand), and
// the Mover on the cleaver node under it (start = raised, end = contact with the board).
struct FMars_Dicing_Nodes
{
    UPROPERTY()
    FCk_Handle_SceneNode LateralNode;

    UPROPERTY()
    FCk_Handle_Mover ChopMover;

    FMars_Dicing_Nodes() {}

    FMars_Dicing_Nodes(FCk_Handle_SceneNode InLateralNode, FCk_Handle_Mover InChopMover)
    {
        LateralNode = InLateralNode;
        ChopMover = InChopMover;
    }
}

struct FMars_Tag_Dicing_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Dicing_Params
{
    UPROPERTY()
    FMars_Dicing_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The pile's material: a reset restores the default.
struct FMars_Dicing_Pile
{
    UPROPERTY()
    EMars_Dicing_State MaterialState = EMars_Dicing_State::WholeLeaves;

    // Useful chops since the last state change.
    UPROPERTY()
    int32 ChopsInState = 0;

    // Useful chops since the last reset.
    UPROPERTY()
    int32 UsefulChops = 0;
}

// Written only by the Dicing processors (and Add). The station SM and the operator only issue requests.
struct FMars_Fragment_Dicing
{
    UPROPERTY()
    FMars_Dicing_Pile Pile;

    // uu, clamped to +-BoardHalfWidth.
    UPROPERTY()
    float32 HandLateral = 0.0f;

    // The band table entry the band sits on; its centre is utils_dicing::Get_BandCenterAt(Spec, BandIndex).
    UPROPERTY()
    int32 BandIndex = 0;

    // One press = one chop: true from the chop request until the cleaver is back up; chops meanwhile are ignored.
    UPROPERTY()
    bool IsChopping = false;
}

// On the cleaver's Mover entity: the Dicing feature it strikes for (its OnArrived handler resolves the chop through it).
// Written only by Add.
struct FMars_Fragment_Dicing_ChopLink
{
    UPROPERTY()
    FCk_Handle_Dicing Dicing;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Dicing_ChopResult
{
    // The hand was within BandHalfWidth of the band: the chop counts.
    Aligned,
    OffTheBand
}

// Broadcast at the cleaver's contact with the board, after the chop's state, chop counts and band moved.
delegate void FMars_Delegate_Dicing_OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult);
event void FMars_Delegate_Dicing_OnChopResolved_MC(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult);

delegate void FMars_Delegate_Dicing_OnStateChanged(FCk_Handle_Dicing InDicing, EMars_Dicing_State InState);
event void FMars_Delegate_Dicing_OnStateChanged_MC(FCk_Handle_Dicing InDicing, EMars_Dicing_State InState);

delegate void FMars_Delegate_Dicing_OnBandMoved(FCk_Handle_Dicing InDicing, float32 InCenter);
event void FMars_Delegate_Dicing_OnBandMoved_MC(FCk_Handle_Dicing InDicing, float32 InCenter);

delegate void FMars_Delegate_Dicing_OnHandMoved(FCk_Handle_Dicing InDicing, float32 InLateral);
event void FMars_Delegate_Dicing_OnHandMoved_MC(FCk_Handle_Dicing InDicing, float32 InLateral);

// The pile entered exactly the requested state (once per reset; later states over-process it).
delegate void FMars_Delegate_Dicing_OnRequestedStateReached(FCk_Handle_Dicing InDicing);
event void FMars_Delegate_Dicing_OnRequestedStateReached_MC(FCk_Handle_Dicing InDicing);

// A Reset put a fresh pile on the board (broadcast even when the state was already WholeLeaves: the chops so far are
// undone whether or not they had changed the texture).
delegate void FMars_Delegate_Dicing_OnReset(FCk_Handle_Dicing InDicing);
event void FMars_Delegate_Dicing_OnReset_MC(FCk_Handle_Dicing InDicing);

struct FMars_Fragment_Dicing_Signals
{
    FMars_Delegate_Dicing_OnChopResolved_MC OnChopResolved;
    FMars_Delegate_Dicing_OnStateChanged_MC OnStateChanged;
    FMars_Delegate_Dicing_OnBandMoved_MC OnBandMoved;
    FMars_Delegate_Dicing_OnHandMoved_MC OnHandMoved;
    FMars_Delegate_Dicing_OnRequestedStateReached_MC OnRequestedStateReached;
    FMars_Delegate_Dicing_OnReset_MC OnReset;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Degrees of look yaw; positive slides the hand toward the board's +Y. Summed per drain.
struct FMars_Request_Dicing_Nudge
{
    UPROPERTY()
    float32 LateralDegrees = 0.0f;

    FMars_Request_Dicing_Nudge() {}

    FMars_Request_Dicing_Nudge(float32 InLateralDegrees)
    {
        LateralDegrees = InLateralDegrees;
    }
}

// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Dicing_Chop
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Dicing_Chop() {}
}

// A fresh pile: WholeLeaves, no chops, the band back on table entry 0 and the hand at the board centre. A chop in flight
// still resolves (against the fresh pile). Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Dicing_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Dicing_Reset() {}
}

// Applied Reset -> Nudge -> Chop, so a reset and the first nudge or chop of a new session can share a drain.
struct FMars_Fragment_Dicing_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Dicing_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Dicing_Nudge> NudgeRequests;

    UPROPERTY()
    TArray<FMars_Request_Dicing_Chop> ChopRequests;
}
