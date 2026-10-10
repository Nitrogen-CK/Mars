//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_CuttingHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Cutting";
    RequiredFragments.Add(FMars_Feature_Cutting);
    Description = "A cutting station's cleaver: the operator's hand slides it along the board and strikes it down onto the board";
}
struct FMars_Feature_Cutting {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Board frame: the hand (and the cleaver under it) slides along the station's local Y about the board centre. The cleaver's
// Mover has one Duration for both directions (the entity script sets it to ChopDownSeconds), so the recover takes as long
// as the strike.
struct FMars_Cutting_Spec
{
    // The hand's lateral travel each side of the board centre (uu).
    UPROPERTY()
    float32 BoardHalfWidth = 40.0f;

    // uu of hand travel per degree of look yaw.
    UPROPERTY()
    float32 LateralPerDegree = 1.5f;

    // The cleaver's strike (and, through the Mover's single Duration, its recover) in seconds.
    UPROPERTY()
    float32 ChopDownSeconds = 0.10f;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Cutting_Nodes Nodes;

    FMars_Cutting_Spec() {}

    FMars_Cutting_Spec(float32 InBoardHalfWidth, float32 InLateralPerDegree, float32 InChopDownSeconds)
    {
        BoardHalfWidth = InBoardHalfWidth;
        LateralPerDegree = InLateralPerDegree;
        ChopDownSeconds = InChopDownSeconds;
    }
}

// A board with no width has nowhere for the hand to go, a look that moves nothing cannot steer it, and a zero-length strike
// is no motion at all.
mixin FMars_Validation Validate(const FMars_Cutting_Spec& Self)
{
    if (Self.BoardHalfWidth <= 0.0f)
    { return FMars_Validation(f"Cutting has a non-positive BoardHalfWidth [{Self.BoardHalfWidth}]"); }

    if (Self.LateralPerDegree <= 0.0f)
    { return FMars_Validation(f"Cutting has a non-positive LateralPerDegree [{Self.LateralPerDegree}]"); }

    if (Self.ChopDownSeconds <= 0.0f)
    { return FMars_Validation(f"Cutting has a non-positive ChopDownSeconds [{Self.ChopDownSeconds}]"); }

    return FMars_Validation();
}

// The nodes the placing script builds for the feature: the lateral node the hand slides (its offset Y is the hand), and
// the Mover on the cleaver node under it (start = raised, end = contact with the board).
struct FMars_Cutting_Nodes
{
    UPROPERTY()
    FCk_Handle_SceneNode LateralNode;

    UPROPERTY()
    FCk_Handle_Mover ChopMover;

    FMars_Cutting_Nodes() {}

    FMars_Cutting_Nodes(FCk_Handle_SceneNode InLateralNode, FCk_Handle_Mover InChopMover)
    {
        LateralNode = InLateralNode;
        ChopMover = InChopMover;
    }
}

struct FMars_Tag_Cutting_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Cutting_Params
{
    UPROPERTY()
    FMars_Cutting_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the Cutting processors (and Add). The station SM and the operator only issue requests.
struct FMars_Fragment_Cutting
{
    // uu, clamped to +-BoardHalfWidth.
    UPROPERTY()
    float32 HandLateral = 0.0f;

    // One press = one chop: true from the chop request until the cleaver is back up; chops meanwhile are ignored.
    UPROPERTY()
    bool IsChopping = false;
}

// On the cleaver's Mover entity: the Cutting feature it strikes for (its OnArrived handler lands the chop through it).
// Written only by Add.
struct FMars_Fragment_Cutting_ChopLink
{
    UPROPERTY()
    FCk_Handle_Cutting Cutting;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Broadcast at the cleaver's contact with the board, as it starts back up. Whether the blade met food is the board's answer
// to the cut the control issues on it (FoodBoard OnCutIssued, Straddling > 0).
delegate void FMars_Delegate_Cutting_OnChopLanded(FCk_Handle_Cutting InCutting);
event void FMars_Delegate_Cutting_OnChopLanded_MC(FCk_Handle_Cutting InCutting);

delegate void FMars_Delegate_Cutting_OnHandMoved(FCk_Handle_Cutting InCutting, float32 InLateral);
event void FMars_Delegate_Cutting_OnHandMoved_MC(FCk_Handle_Cutting InCutting, float32 InLateral);

// A Reset put the hand back at the board centre for the next operator.
delegate void FMars_Delegate_Cutting_OnReset(FCk_Handle_Cutting InCutting);
event void FMars_Delegate_Cutting_OnReset_MC(FCk_Handle_Cutting InCutting);

struct FMars_Fragment_Cutting_Signals
{
    FMars_Delegate_Cutting_OnChopLanded_MC OnChopLanded;
    FMars_Delegate_Cutting_OnHandMoved_MC OnHandMoved;
    FMars_Delegate_Cutting_OnReset_MC OnReset;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Degrees of look yaw; positive slides the hand toward the board's +Y. Summed per drain.
struct FMars_Request_Cutting_Nudge
{
    UPROPERTY()
    float32 LateralDegrees = 0.0f;

    FMars_Request_Cutting_Nudge() {}

    FMars_Request_Cutting_Nudge(float32 InLateralDegrees)
    {
        LateralDegrees = InLateralDegrees;
    }
}

// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Cutting_Chop
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Cutting_Chop() {}
}

// The hand back at the board centre. A chop in flight still lands. Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Cutting_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Cutting_Reset() {}
}

// Applied Reset -> Nudge -> Chop, so a reset and the first nudge or chop of a new session can share a drain.
struct FMars_Fragment_Cutting_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Cutting_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Cutting_Nudge> NudgeRequests;

    UPROPERTY()
    TArray<FMars_Request_Cutting_Chop> ChopRequests;
}
