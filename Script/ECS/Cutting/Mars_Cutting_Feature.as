// Stance A, following its host. FMars_Fragment_Cutting (the hand, the chops started, the chops landed) is the replicated
// ledger, written only by the authority's drain and chop clock and by utils_cutting::Add; on a host with no replication
// driver it is local. The chop clock and the operator's requests run only with authority. The clock's progress, the
// mirror's last ledger and a predicted hand (FMars_Fragment_Cutting_Local) are each machine's own. A client mirrors the
// ledger (UMars_Processor_Cutting_Mirror): it slides its own lateral node and raises the chop signals the authority raised.
// The operating machine predicts its own hand (PredictHand, applied on every machine) and a remote operator chops through
// Cue.Mars.Cutting.Chop (utils_cutting::Request_ChopFor), carrying the aim it saw.

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

// Board frame: the hand (and the cleaver under it) slides along the station's local Y about the board centre. A chop is
// the kernel's own clock: a strike of ChopSeconds, the landing, then a recover of ChopSeconds; whatever draws the cleaver
// follows OnChopStarted and OnChopLanded.
struct FMars_Cutting_Spec
{
    // The hand's lateral travel each side of the board centre (cm).
    UPROPERTY()
    float32 BoardHalfWidth = 40.0f;

    // The cleaver's strike in seconds; its recover takes as long.
    UPROPERTY()
    float32 ChopSeconds = 0.10f;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Cutting_Nodes Nodes;

    FMars_Cutting_Spec() {}

    FMars_Cutting_Spec(float32 InBoardHalfWidth, float32 InChopSeconds)
    {
        BoardHalfWidth = InBoardHalfWidth;
        ChopSeconds = InChopSeconds;
    }
}

// A board with no width has nowhere for the hand to go, and a zero-length strike is no chop at all.
mixin FMars_Validation Validate(const FMars_Cutting_Spec& Self)
{
    if (Math::IsFinite(Self.BoardHalfWidth) == false || Self.BoardHalfWidth <= 0.0f)
    { return FMars_Validation(f"Cutting has a non-positive BoardHalfWidth [{Self.BoardHalfWidth}]"); }

    if (Math::IsFinite(Self.ChopSeconds) == false || Self.ChopSeconds <= 0.0f)
    { return FMars_Validation(f"Cutting has a non-positive ChopSeconds [{Self.ChopSeconds}]"); }

    return FMars_Validation();
}

// The node the placing script builds for the feature: the lateral node the hand slides (its offset Y is the hand).
struct FMars_Cutting_Nodes
{
    UPROPERTY()
    FCk_Handle_SceneNode LateralNode;

    FMars_Cutting_Nodes() {}

    FMars_Cutting_Nodes(FCk_Handle_SceneNode InLateralNode)
    {
        LateralNode = InLateralNode;
    }
}

// Where a chop is: the cleaver up and ready, on its way down, or on its way back up.
enum EMars_Cutting_ChopPhase
{
    Idle,
    Striking,
    Recovering
}

// On the Cutting entity while a chop runs: the chop clock's Tick runs only then.
struct FMars_Tag_Cutting_Chopping {}

// Added by utils_cutting::Add, dropped by UMars_Processor_Cutting_Mirror once it has bound the ledger's rep-notify.
struct FMars_Tag_Cutting_NeedsMirror {}

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

// The replicated ledger. Written only by the authority's Cutting processors (and Add). The station SM and the operator only
// issue requests.
struct FMars_Fragment_Cutting
{
    // cm, clamped to +-BoardHalfWidth.
    UPROPERTY()
    float32 HandLateral = 0.0f;

    // Chops started: one per OnChopStarted the authority raised.
    UPROPERTY()
    int32 ChopSerial = 0;

    // Chops landed: one per OnChopLanded the authority raised.
    UPROPERTY()
    int32 LandSerial = 0;
}

// Each machine's own: the chop clock (advanced only with authority), the ledger the mirror last reconciled, and the hand
// this machine's operator predicts.
struct FMars_Fragment_Cutting_Local
{
    // One press = one chop: a chop request starts a chop only while Idle.
    UPROPERTY()
    EMars_Cutting_ChopPhase ChopPhase = EMars_Cutting_ChopPhase::Idle;

    // Seconds left in the current phase of the chop (Spec.ChopSeconds at each phase's start); 0 while Idle.
    UPROPERTY()
    float32 ChopSecondsLeft = 0.0f;

    // The ledger the mirror last reconciled; unset with authority.
    UPROPERTY()
    TOptional<FMars_Fragment_Cutting> Last;

    // While set, the lateral node shows this instead of the ledger's hand (cm).
    UPROPERTY()
    TOptional<float32> PredictedHand;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Broadcast as a chop starts: the cleaver leaves its raised pose for the board, reaching it ChopSeconds later.
delegate void FMars_Delegate_Cutting_OnChopStarted(FCk_Handle_Cutting InCutting);
event void FMars_Delegate_Cutting_OnChopStarted_MC(FCk_Handle_Cutting InCutting);

// Broadcast at the cleaver's contact with the board, as it starts back up. Whether the blade met food is the board's answer
// to the cut the control issues on it (FoodBoard OnCutIssued, Straddling > 0).
delegate void FMars_Delegate_Cutting_OnChopLanded(FCk_Handle_Cutting InCutting);
event void FMars_Delegate_Cutting_OnChopLanded_MC(FCk_Handle_Cutting InCutting);

struct FMars_Fragment_Cutting_Signals
{
    FMars_Delegate_Cutting_OnChopStarted_MC OnChopStarted;
    FMars_Delegate_Cutting_OnChopLanded_MC OnChopLanded;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Centimetres along the board; positive slides the hand toward the board's +Y. Summed per drain.
struct FMars_Request_Cutting_Nudge
{
    UPROPERTY()
    float32 LateralCm = 0.0f;

    FMars_Request_Cutting_Nudge() {}

    FMars_Request_Cutting_Nudge(float32 InLateralCm)
    {
        LateralCm = InLateralCm;
    }
}

// A chop. LateralCm, when set, is where the hand stands as the chop starts (clamped to the board): a remote operator's aim.
// Unset leaves the hand where it is.
struct FMars_Request_Cutting_Chop
{
    UPROPERTY()
    TOptional<float32> LateralCm;

    FMars_Request_Cutting_Chop() {}

    FMars_Request_Cutting_Chop(float32 InLateralCm)
    {
        LateralCm = TOptional<float32>(InLateralCm);
    }
}

// Presentation, applied on every machine: this machine's lateral node shows LateralCm (cm, as given) until the prediction
// is cleared, and the ledger's hand no longer moves it.
struct FMars_Request_Cutting_PredictHand
{
    UPROPERTY()
    float32 LateralCm = 0.0f;

    FMars_Request_Cutting_PredictHand() {}

    FMars_Request_Cutting_PredictHand(float32 InLateralCm)
    {
        LateralCm = InLateralCm;
    }
}

// Presentation, applied on every machine: the prediction ends and the lateral node returns to the ledger's hand.
// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Cutting_ClearPrediction
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Cutting_ClearPrediction() {}
}

// The hand back at the board centre. A chop in flight still lands. Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Cutting_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Cutting_Reset() {}
}

// PredictHand / ClearPrediction apply first, on every machine; then, with authority only, Reset -> Nudge -> Chop, so a
// reset and the first nudge or chop of a new session can share a drain.
struct FMars_Fragment_Cutting_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Cutting_PredictHand> PredictHandRequests;

    UPROPERTY()
    TArray<FMars_Request_Cutting_ClearPrediction> ClearPredictionRequests;

    UPROPERTY()
    TArray<FMars_Request_Cutting_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Cutting_Nudge> NudgeRequests;

    UPROPERTY()
    TArray<FMars_Request_Cutting_Chop> ChopRequests;
}
