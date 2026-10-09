//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_CookingFeedHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_CookingFeed";
    RequiredFragments.Add(FMars_Feature_CookingFeed);
    Description = "A transfer hand between a docked platter and a cooking vessel: one left-hand transfer at a time, reserved from the platter, released, then admitted by the cooking kernel";
}
struct FMars_Feature_CookingFeed {}

//--------------------------------------------------------------------------------------------------------------------------
// Vocabulary
//--------------------------------------------------------------------------------------------------------------------------

// Idle -> Reach -> Grasp -> Carry -> AwaitAdmission -> Return -> Idle. Busy = anything but Idle. AwaitAdmission has no clock:
// it ends when the cooking kernel answers.
enum EMars_CookingFeed_Phase
{
    Idle,
    Reach,
    Grasp,
    Carry,
    AwaitAdmission,
    Return
}

// A cooking kernel's answer to one released piece.
enum EMars_CookingFeed_Admission
{
    Accepted,
    Rejected
}

// How the active transfer ended.
enum EMars_CookingFeed_Settle
{
    Admitted,
    Rejected,
    Cancelled
}

// Why a BeginTransfer did nothing.
enum EMars_CookingFeed_Refusal
{
    Busy,
    // No source, or nothing on it.
    Empty,
    NoRelease
}

// One piece's identity: the attempt it belongs to (bumped by every Reset and SetSource) and the platter slot the piece was
// reserved from (StockIndex). An array index is never identity; a piece from an older generation is stale.
struct FMars_CookingFeed_PieceId
{
    UPROPERTY()
    int32 Generation = 0;

    UPROPERTY()
    int32 StockIndex = -1;

    FMars_CookingFeed_PieceId() {}

    FMars_CookingFeed_PieceId(int32 InGeneration, int32 InStockIndex)
    {
        Generation = InGeneration;
        StockIndex = InStockIndex;
    }
}

mixin bool Get_IsSame(const FMars_CookingFeed_PieceId& Self, const FMars_CookingFeed_PieceId& InOther)
{
    return Self.Generation == InOther.Generation && Self.StockIndex == InOther.StockIndex;
}

// The one transfer in flight: its identity and the piece it names on the source platter.
struct FMars_CookingFeed_Reservation
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    FMars_CookingFeed_Reservation() {}

    FMars_CookingFeed_Reservation(FMars_CookingFeed_PieceId InId, FCk_Handle_FoodPiece InPiece)
    {
        Id = InId;
        Piece = InPiece;
    }
}

// The one payload every cooking kernel's AddPiece wraps: who, which piece, where (world), how fast, and which mesh variant.
struct FMars_CookingFeed_Release
{
    UPROPERTY()
    FMars_CookingFeed_PieceId PieceId;

    // The reserved piece; invalid for a release built by hand. Set by the feed at the release, not by the ctor.
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    UPROPERTY()
    FTransform WorldTransform;

    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocity = FVector::ZeroVector;

    UPROPERTY()
    int32 PresetIndex = 0;

    FMars_CookingFeed_Release() {}

    FMars_CookingFeed_Release(FMars_CookingFeed_PieceId InPieceId, FTransform InWorldTransform, FVector InLinearVelocity, int32 InPresetIndex)
    {
        PieceId = InPieceId;
        WorldTransform = InWorldTransform;
        LinearVelocity = InLinearVelocity;
        PresetIndex = InPresetIndex;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Seconds per timed phase. A zero-length phase passes through in the frame it starts, its boundary still crossed once.
struct FMars_CookingFeed_TimingSpec
{
    UPROPERTY()
    float32 ReachSeconds = 0.20f;

    UPROPERTY()
    float32 GraspSeconds = 0.08f;

    UPROPERTY()
    float32 CarrySeconds = 0.25f;

    UPROPERTY()
    float32 ReturnSeconds = 0.20f;

    FMars_CookingFeed_TimingSpec() {}

    FMars_CookingFeed_TimingSpec(float32 InReachSeconds, float32 InGraspSeconds, float32 InCarrySeconds, float32 InReturnSeconds)
    {
        ReachSeconds = InReachSeconds;
        GraspSeconds = InGraspSeconds;
        CarrySeconds = InCarrySeconds;
        ReturnSeconds = InReturnSeconds;
    }
}

// Release-node frame. The sampled release velocity = ReleaseVelocityLocal (rotated to world) + VelocityInheritance x the
// release node's own measured world velocity (the pan is moving).
struct FMars_CookingFeed_MotionSpec
{
    UPROPERTY()
    FVector ReleaseVelocityLocal = FVector(0.0, 0.0, -20.0);

    UPROPERTY()
    float32 VelocityInheritance = 0.5f;

    FMars_CookingFeed_MotionSpec() {}

    FMars_CookingFeed_MotionSpec(FVector InReleaseVelocityLocal, float32 InVelocityInheritance)
    {
        ReleaseVelocityLocal = InReleaseVelocityLocal;
        VelocityInheritance = InVelocityInheritance;
    }
}

// Built by the placing script: the node whose world pose is sampled at release (on the searing station a child of the pan
// mesh node above the rim; on the fryer a node over the oil).
struct FMars_CookingFeed_Nodes
{
    UPROPERTY()
    FCk_Handle_Transform Release;

    FMars_CookingFeed_Nodes() {}

    FMars_CookingFeed_Nodes(FCk_Handle_Transform InRelease)
    {
        Release = InRelease;
    }
}

struct FMars_CookingFeed_Spec
{
    UPROPERTY()
    FMars_CookingFeed_TimingSpec Timing;

    UPROPERTY()
    FMars_CookingFeed_MotionSpec Motion;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_CookingFeed_Nodes Nodes;

    FMars_CookingFeed_Spec() {}

    FMars_CookingFeed_Spec(FMars_CookingFeed_TimingSpec InTiming, FMars_CookingFeed_MotionSpec InMotion)
    {
        Timing = InTiming;
        Motion = InMotion;
    }
}

// A negative or non-finite phase length, or an inheritance outside [0, 1], makes the clock or the release unsound. The nodes
// are checked by Add (a missing Release node ensures there).
mixin FMars_Validation Validate(const FMars_CookingFeed_Spec& Self)
{
    if (utils_cooking_feed::Get_IsValidSeconds(Self.Timing.ReachSeconds) == false)
    { return FMars_Validation(f"CookingFeed has a negative or non-finite Timing.ReachSeconds [{Self.Timing.ReachSeconds}]"); }

    if (utils_cooking_feed::Get_IsValidSeconds(Self.Timing.GraspSeconds) == false)
    { return FMars_Validation(f"CookingFeed has a negative or non-finite Timing.GraspSeconds [{Self.Timing.GraspSeconds}]"); }

    if (utils_cooking_feed::Get_IsValidSeconds(Self.Timing.CarrySeconds) == false)
    { return FMars_Validation(f"CookingFeed has a negative or non-finite Timing.CarrySeconds [{Self.Timing.CarrySeconds}]"); }

    if (utils_cooking_feed::Get_IsValidSeconds(Self.Timing.ReturnSeconds) == false)
    { return FMars_Validation(f"CookingFeed has a negative or non-finite Timing.ReturnSeconds [{Self.Timing.ReturnSeconds}]"); }

    if (Self.Motion.VelocityInheritance < 0.0f || Self.Motion.VelocityInheritance > 1.0f)
    { return FMars_Validation(f"CookingFeed has Motion.VelocityInheritance [{Self.Motion.VelocityInheritance}] outside [0, 1]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_CookingFeed_Params
{
    UPROPERTY()
    FMars_CookingFeed_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the CookingFeed processors (and Add). The station's control layer only issues requests. Available is
// derived from the source; Admitted counts admissions since the last Reset.
struct FMars_Fragment_CookingFeed
{
    // The attempt every PieceId carries; bumped by Reset and SetSource before anything is cleared.
    UPROPERTY()
    int32 Generation = 1;

    UPROPERTY()
    EMars_CookingFeed_Phase Phase = EMars_CookingFeed_Phase::Idle;

    // Seconds into the current timed phase (carried over across a boundary).
    UPROPERTY()
    float32 PhaseSeconds = 0.0f;

    // The platter the stock is drawn from; invalid = none. The feed only reads it: control loads and unloads.
    UPROPERTY()
    FCk_Handle_Platter Source;

    // The one reservation, from BeginTransfer until the admission answer (or a Cancel / Reset / SetSource).
    UPROPERTY()
    TOptional<FMars_CookingFeed_Reservation> Active;

    // Spent since the last Reset: pieces a cooking kernel accepted.
    UPROPERTY()
    int32 Admitted = 0;

    // The stock last broadcast: the source changes under the feed without a request, so the Tick compares every frame.
    UPROPERTY()
    int32 LastStockAvailable = 0;

    UPROPERTY()
    int32 LastStockAdmitted = 0;

    // The sample broadcast at Carry's end, kept through AwaitAdmission.
    UPROPERTY()
    FMars_CookingFeed_Release PendingRelease;

    // The release node's world pose on the last positive-dt frame (the velocity estimate).
    UPROPERTY()
    TOptional<FTransform> ReleasePrevWorld;

    // World, measured in the Tick (positive dt only).
    UPROPERTY()
    FVector ReleaseVelocity = FVector::ZeroVector;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Edges only, seen by the Tick: a reservation, an admission, a reset, and anything that changes what the source holds.
delegate void FMars_Delegate_CookingFeed_OnStockChanged(FCk_Handle_CookingFeed InFeed, int32 InAvailable, int32 InAdmitted);
event void FMars_Delegate_CookingFeed_OnStockChanged_MC(FCk_Handle_CookingFeed InFeed, int32 InAvailable, int32 InAdmitted);

delegate void FMars_Delegate_CookingFeed_OnPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase);
event void FMars_Delegate_CookingFeed_OnPhaseChanged_MC(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase);

// Once per transfer, at Carry's end: the station's bridge forwards it to the cooking kernel, which answers with
// Request_ResolveAdmission.
delegate void FMars_Delegate_CookingFeed_OnReleaseRequested(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease);
event void FMars_Delegate_CookingFeed_OnReleaseRequested_MC(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease);

delegate void FMars_Delegate_CookingFeed_OnTransferSettled(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle);
event void FMars_Delegate_CookingFeed_OnTransferSettled_MC(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle);

// A press that did nothing (busy, empty, no release node): never deferred.
delegate void FMars_Delegate_CookingFeed_OnTransferRefused(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal);
event void FMars_Delegate_CookingFeed_OnTransferRefused_MC(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal);

struct FMars_Fragment_CookingFeed_Signals
{
    FMars_Delegate_CookingFeed_OnStockChanged_MC OnStockChanged;
    FMars_Delegate_CookingFeed_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_CookingFeed_OnReleaseRequested_MC OnReleaseRequested;
    FMars_Delegate_CookingFeed_OnTransferSettled_MC OnTransferSettled;
    FMars_Delegate_CookingFeed_OnTransferRefused_MC OnTransferRefused;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Reserve the source's lowest held piece and start the hand; refused (never deferred) while busy, without a source or
// anything on it, or without a release node. Payload-less: one placeholder field (request doctrine).
struct FMars_Request_CookingFeed_BeginTransfer
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_CookingFeed_BeginTransfer() {}
}

// Abandon the active transfer: the reservation is dropped and the hand is idle at once. A no-op while idle.
struct FMars_Request_CookingFeed_Cancel
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_CookingFeed_Cancel() {}
}

// A new attempt: the generation is bumped first (every older PieceId goes stale), then the transfer is dropped, the hand
// idles and Admitted is zeroed. Nothing is refilled: the source platter is the stock.
struct FMars_Request_CookingFeed_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_CookingFeed_Reset() {}
}

// Draw from Source (invalid = none). A transfer in flight is cancelled first and the generation moves on; the same
// platter again is a no-op.
struct FMars_Request_CookingFeed_SetSource
{
    UPROPERTY()
    FCk_Handle_Platter Source;

    FMars_Request_CookingFeed_SetSource() {}

    FMars_Request_CookingFeed_SetSource(FCk_Handle_Platter InSource)
    {
        Source = InSource;
    }
}

// The cooking kernel's answer to a release. Honoured only while awaiting admission for exactly this PieceId.
struct FMars_Request_CookingFeed_ResolveAdmission
{
    UPROPERTY()
    FMars_CookingFeed_PieceId PieceId;

    UPROPERTY()
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;

    UPROPERTY()
    FString Reason;

    FMars_Request_CookingFeed_ResolveAdmission() {}

    FMars_Request_CookingFeed_ResolveAdmission(FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        PieceId = InPieceId;
        Admission = InAdmission;
        Reason = InReason;
    }
}

// Applied Reset -> SetSource -> Cancel -> ResolveAdmission -> BeginTransfer, so a reset or a new source and the next
// attempt's first press can share a drain and no late answer reaches the next attempt.
struct FMars_Fragment_CookingFeed_Requests
{
    UPROPERTY()
    TArray<FMars_Request_CookingFeed_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_CookingFeed_SetSource> SetSourceRequests;

    UPROPERTY()
    TArray<FMars_Request_CookingFeed_Cancel> CancelRequests;

    UPROPERTY()
    TArray<FMars_Request_CookingFeed_ResolveAdmission> ResolveAdmissionRequests;

    UPROPERTY()
    TArray<FMars_Request_CookingFeed_BeginTransfer> BeginTransferRequests;
}
