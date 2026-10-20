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

// Idle -> Reach -> Grasp -> Carry -> AwaitAdmission -> Return -> Idle. Busy = anything but Idle. AwaitAdmission ends when the
// cooking kernel answers, or as a rejection once Timing.AdmissionBudgetSeconds pass without an answer.
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
    // The hand is not at rest, or the source's pile is settling (no piece frozen to reach for yet).
    Busy,
    // No source, or nothing on it.
    Empty,
    NoRelease,
    // The station's own gate refused the press before the feed took it: a tumbler's shut hatch, a cutting board that
    // holds a joint.
    StationGate
}

// What the station's own gate said about an add-food press.
enum EMars_CookingFeed_StationGate
{
    Open,
    Shut
}

// What utils_cooking_feed::Return_Piece did with a piece the feed took.
enum EMars_CookingFeed_PieceReturn
{
    // It stays where it is: gone, never off the source, taken by someone else, or another ledger holds it.
    Kept,
    // Loaded back onto a platter.
    Returned,
    // Released where it lies, detached and its body Dynamic: no platter is left to take it back.
    LetGo
}

// Why a heat kernel's TakeOut handed nothing back. Here because both heat kernels share the feed's piece types.
enum EMars_CookingFeed_TakeOutRefusal
{
    // The take-out was capped at zero pieces: no tray docked, or a full one.
    NoRoom,
    // Nothing in play is takeable now.
    NothingReady
}

// What a receiving kernel does with a piece it handed back and its tray refused (utils_cooking_feed::Get_ReadoptGate).
enum EMars_CookingFeed_ReadoptGate
{
    // Back on the kernel's books.
    Readopt,
    // Gone or going: nothing is left to take back.
    Gone,
    // Another ledger holds it by now: its pickup's Ledger claim is that ledger's.
    HeldElsewhere,
    // Attached somewhere: it stays there, and the kernel releases its pickup's Ledger claim.
    Attached
}

// Where an adopted piece is on its way to its release pose (utils_cooking_feed::Get_ArrivalVerdict).
enum EMars_CookingFeed_Arrival
{
    // Not there yet, and still within the arrival timeout: nothing judges it.
    OnItsWay,
    Arrived,
    // Past the arrival timeout without getting there: it is judged where it is.
    Overdue
}

// One piece's identity: the attempt it belongs to (bumped by every Reset and SetSource) and the transfer that reserved it
// within that attempt (TransferIndex: 0, 1, 2, ... in reservation order, never reused, so a source refilled between two
// transfers cannot hand the same id out twice). A piece from an older generation is stale.
struct FMars_CookingFeed_PieceId
{
    UPROPERTY()
    int32 Generation = 0;

    UPROPERTY()
    int32 TransferIndex = -1;

    FMars_CookingFeed_PieceId() {}

    FMars_CookingFeed_PieceId(int32 InGeneration, int32 InTransferIndex)
    {
        Generation = InGeneration;
        TransferIndex = InTransferIndex;
    }
}

mixin bool Get_IsSame(const FMars_CookingFeed_PieceId& Self, const FMars_CookingFeed_PieceId& InOther)
{
    return Self.Generation == InOther.Generation && Self.TransferIndex == InOther.TransferIndex;
}

// Where the reserved piece is, from the press to the admission answer. The feed takes it off the source itself at the grasp.
enum EMars_CookingFeed_PieceHold
{
    // On the source platter, where the hand reaches for it.
    OnSource,
    // Asked off the source at the grasp; not yet off it (or its body not yet Kinematic).
    Unloading,
    // Under Nodes.Hand, riding the glove.
    InHand,
    // Let go at the release (detached at its world pose) and handed to the receiving kernel; the feed still returns it unless
    // that kernel admits it.
    Released
}

// The one transfer in flight: its identity, the piece it names, the platter that piece was reserved from and where it is.
struct FMars_CookingFeed_Reservation
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    // The source when the transfer began: a piece the feed took and has to give back goes back here first.
    UPROPERTY()
    FCk_Handle_Platter From;

    UPROPERTY()
    EMars_CookingFeed_PieceHold Hold = EMars_CookingFeed_PieceHold::OnSource;

    // InHand: the piece's offset under the hand when it was attached (where the grasp lerps from).
    UPROPERTY()
    FTransform HeldFrom;

    FMars_CookingFeed_Reservation() {}

    FMars_CookingFeed_Reservation(FMars_CookingFeed_PieceId InId, FCk_Handle_FoodPiece InPiece, FCk_Handle_Platter InFrom)
    {
        Id = InId;
        Piece = InPiece;
        From = InFrom;
    }
}

// The one payload a station's admission inbox carries to its receiving kernel: who, which piece, where (world) and how
// fast.
struct FMars_CookingFeed_Release
{
    UPROPERTY()
    FMars_CookingFeed_PieceId PieceId;

    // The reserved piece; invalid for a release built by hand. Set by the feed at the release, not by the ctor.
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    // The carried piece's own pose where the hand let it go; the release node's pose when no piece rode the hand (a release
    // built by hand, or a piece whose unload had not landed by the release).
    UPROPERTY()
    FTransform WorldTransform;

    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocity = FVector::ZeroVector;

    FMars_CookingFeed_Release() {}

    FMars_CookingFeed_Release(FMars_CookingFeed_PieceId InPieceId, FTransform InWorldTransform, FVector InLinearVelocity)
    {
        PieceId = InPieceId;
        WorldTransform = InWorldTransform;
        LinearVelocity = InLinearVelocity;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Seconds per timed phase. A zero-length phase passes through in the frame it starts, its boundary still crossed once.
// AdmissionBudgetSeconds bounds AwaitAdmission: a release no kernel has answered by then settles Rejected and its piece goes
// back. 0 = no bound (the wait ends only on an answer or a SetSource).
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

    UPROPERTY()
    float32 AdmissionBudgetSeconds = 2.0f;

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
// release node's own measured world velocity (the pan is moving). HeldOffset is the pose a carried piece sits at under
// Nodes.Hand: its bounds centre at HeldOffset's location, its rotation HeldOffset's; the grasp lerps the piece there.
struct FMars_CookingFeed_MotionSpec
{
    UPROPERTY()
    FVector ReleaseVelocityLocal = FVector(0.0, 0.0, -20.0);

    UPROPERTY()
    float32 VelocityInheritance = 0.5f;

    UPROPERTY()
    FTransform HeldOffset = FTransform::Identity;

    FMars_CookingFeed_MotionSpec() {}

    FMars_CookingFeed_MotionSpec(FVector InReleaseVelocityLocal, float32 InVelocityInheritance)
    {
        ReleaseVelocityLocal = InReleaseVelocityLocal;
        VelocityInheritance = InVelocityInheritance;
    }
}

// Built by the placing script: the node whose world pose is sampled at release (on the searing station a child of the pan
// mesh node above the rim; on the fryer a node over the oil), and the glove's carry node the reserved piece rides from the
// grasp to the release (a scene node: the feed moves it when its spec carries hand geometry, the station otherwise).
struct FMars_CookingFeed_Nodes
{
    UPROPERTY()
    FCk_Handle_Transform Release;

    UPROPERTY()
    FCk_Handle_Transform Hand;

    FMars_CookingFeed_Nodes() {}

    FMars_CookingFeed_Nodes(FCk_Handle_Transform InRelease, FCk_Handle_Transform InHand)
    {
        Release = InRelease;
        Hand = InHand;
    }
}

// Where the feed moves its hand node through a transfer, in the node's parent frame (the station's). The hand rests at
// RestLocal, reaches in an arc ClearanceCm high to GraspLocal off the reserved piece's middle (where that piece last lay on
// its own; RestLocal's location until then), lifts ClearanceCm straight up through the grasp, carries in an arc CarryArcCm
// high to ReleaseLocal off the release node (sampled every frame: the pan moves), waits there for the answer and returns to
// rest in an arc ClearanceCm high; each leg eases in and out over its phase, and the rotation turns with the location
// between the poses it leaves and reaches. Grasp and Release are offsets: their locations add to the piece's middle and to
// the release node, their rotations are the hand's there.
struct FMars_CookingFeed_HandGeometry
{
    UPROPERTY()
    FTransform RestLocal;

    UPROPERTY()
    FTransform GraspLocal;

    UPROPERTY()
    FTransform ReleaseLocal;

    UPROPERTY()
    float32 ClearanceCm = 6.0f;

    UPROPERTY()
    float32 CarryArcCm = 10.0f;
}

struct FMars_CookingFeed_Spec
{
    UPROPERTY()
    FMars_CookingFeed_TimingSpec Timing;

    UPROPERTY()
    FMars_CookingFeed_MotionSpec Motion;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_CookingFeed_Nodes Nodes;

    // Built by the placing script from its geometry (Motion.HeldOffset is its held piece's pose under the hand). Set, the
    // feed moves Nodes.Hand through every transfer; unset, whoever built the node moves it. Not a UPROPERTY.
    TOptional<FMars_CookingFeed_HandGeometry> Hand;

    FMars_CookingFeed_Spec() {}

    FMars_CookingFeed_Spec(FMars_CookingFeed_TimingSpec InTiming, FMars_CookingFeed_MotionSpec InMotion)
    {
        Timing = InTiming;
        Motion = InMotion;
    }
}

// A negative or non-finite phase length or admission budget, an inheritance outside [0, 1], or a negative or non-finite hand
// height makes the clock, the release or the hand unsound. The nodes are checked by Add (a missing Release or Hand node, or
// a Hand that is no scene node under a parent while the spec carries hand geometry, ensures there).
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

    if (utils_cooking_feed::Get_IsValidSeconds(Self.Timing.AdmissionBudgetSeconds) == false)
    { return FMars_Validation(f"CookingFeed has a negative or non-finite Timing.AdmissionBudgetSeconds [{Self.Timing.AdmissionBudgetSeconds}]"); }

    if (Self.Motion.VelocityInheritance < 0.0f || Self.Motion.VelocityInheritance > 1.0f)
    { return FMars_Validation(f"CookingFeed has Motion.VelocityInheritance [{Self.Motion.VelocityInheritance}] outside [0, 1]"); }

    if (Self.Hand.IsSet() == false)
    { return FMars_Validation(); }

    const auto Hand = Self.Hand.GetValue();
    if (Math::IsFinite(Hand.ClearanceCm) == false || Hand.ClearanceCm < 0.0f)
    { return FMars_Validation(f"CookingFeed has a negative or non-finite Hand.ClearanceCm [{Hand.ClearanceCm}]"); }

    if (Math::IsFinite(Hand.CarryArcCm) == false || Hand.CarryArcCm < 0.0f)
    { return FMars_Validation(f"CookingFeed has a negative or non-finite Hand.CarryArcCm [{Hand.CarryArcCm}]"); }

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
// derived from the source; Admitted counts admissions since the last SetSource or honoured Reset.
struct FMars_Fragment_CookingFeed
{
    // The attempt every PieceId carries; bumped by Reset and SetSource before anything is cleared.
    UPROPERTY()
    int32 Generation = 1;

    // The TransferIndex the next reservation gets; zeroed whenever the generation moves.
    UPROPERTY()
    int32 NextTransferIndex = 0;

    UPROPERTY()
    EMars_CookingFeed_Phase Phase = EMars_CookingFeed_Phase::Idle;

    // Seconds into the current timed phase (carried over across a boundary), and into AwaitAdmission against its budget.
    UPROPERTY()
    float32 PhaseSeconds = 0.0f;

    // The platter the stock is drawn from; invalid = none. The feed unloads the reserved piece at its grasp and gives back
    // every piece it took and nobody admitted (utils_cooking_feed::Return_Piece).
    UPROPERTY()
    FCk_Handle_Platter Source;

    // The one reservation, from BeginTransfer until the admission answer (or a Cancel / Reset before the grasp, a SetSource,
    // or the admission budget running out).
    UPROPERTY()
    TOptional<FMars_CookingFeed_Reservation> Active;

    // Spent since the last SetSource or honoured Reset: pieces a cooking kernel accepted.
    UPROPERTY()
    int32 Admitted = 0;

    // The stock last broadcast: the source changes under the feed without a request, so the Tick compares every frame.
    UPROPERTY()
    int32 LastStockAvailable = 0;

    UPROPERTY()
    int32 LastStockAdmitted = 0;

    // Whether the source's pile was settling at the last broadcast (stock, but nothing frozen to reach for).
    UPROPERTY()
    bool LastStockSettling = false;

    // The sample broadcast at Carry's end, kept through AwaitAdmission.
    UPROPERTY()
    FMars_CookingFeed_Release PendingRelease;

    // The release node's world pose on the last positive-dt frame (the velocity estimate).
    UPROPERTY()
    TOptional<FTransform> ReleasePrevWorld;

    // World, measured in the Tick (positive dt only).
    UPROPERTY()
    FVector ReleaseVelocity = FVector::ZeroVector;

    // With hand geometry: the reserved piece's middle in the hand node's parent frame where it last lay on its own (on the
    // source or coming off it, Ready), sampled every frame until it rides the hand; unset while idle.
    UPROPERTY()
    TOptional<FVector> GraspPoint;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Edges only, seen by the Tick: a reservation, an admission, a reset, and anything that changes what the source holds.
delegate void FMars_Delegate_CookingFeed_OnStockChanged(FCk_Handle_CookingFeed InFeed, int32 InAvailable, int32 InAdmitted);
event void FMars_Delegate_CookingFeed_OnStockChanged_MC(FCk_Handle_CookingFeed InFeed, int32 InAvailable, int32 InAdmitted);

delegate void FMars_Delegate_CookingFeed_OnPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase);
event void FMars_Delegate_CookingFeed_OnPhaseChanged_MC(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase);

// Once per transfer, at Carry's end: the station's bridge puts it in the station's admission inbox
// (utils_cooking_feed::Request_Admit) and hands the kernel's answer (OnAdmission) back with Request_ResolveAdmission.
delegate void FMars_Delegate_CookingFeed_OnReleaseRequested(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease);
event void FMars_Delegate_CookingFeed_OnReleaseRequested_MC(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease);

// How the transfer ended. Only tests bind it today: the feed's test-pinned contract, kept for the assembly.
delegate void FMars_Delegate_CookingFeed_OnTransferSettled(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle);
event void FMars_Delegate_CookingFeed_OnTransferSettled_MC(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle);

// A press that did nothing (busy, empty, no release node, or the station's own gate shut): never deferred.
delegate void FMars_Delegate_CookingFeed_OnTransferRefused(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal);
event void FMars_Delegate_CookingFeed_OnTransferRefused_MC(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal);

// A piece the feed took is let go where it lies, Dynamic and detached, because no platter is left to take it back.
delegate void FMars_Delegate_CookingFeed_OnPieceLetGo(FCk_Handle_CookingFeed InFeed, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_CookingFeed_OnPieceLetGo_MC(FCk_Handle_CookingFeed InFeed, FCk_Handle_FoodPiece InPiece);

struct FMars_Fragment_CookingFeed_Signals
{
    FMars_Delegate_CookingFeed_OnStockChanged_MC OnStockChanged;
    FMars_Delegate_CookingFeed_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_CookingFeed_OnReleaseRequested_MC OnReleaseRequested;
    FMars_Delegate_CookingFeed_OnTransferSettled_MC OnTransferSettled;
    FMars_Delegate_CookingFeed_OnTransferRefused_MC OnTransferRefused;
    FMars_Delegate_CookingFeed_OnPieceLetGo_MC OnPieceLetGo;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Reserve the top of the source's frozen pile and start the hand; refused (never deferred) while busy, without a source or
// anything on it, or without a release node. Gate is the station's own say on the press: a Shut gate is refused StationGate
// and starts nothing.
struct FMars_Request_CookingFeed_BeginTransfer
{
    UPROPERTY()
    EMars_CookingFeed_StationGate Gate = EMars_CookingFeed_StationGate::Open;

    FMars_Request_CookingFeed_BeginTransfer() {}

    FMars_Request_CookingFeed_BeginTransfer(EMars_CookingFeed_StationGate InGate)
    {
        Gate = InGate;
    }
}

// Abandon the transfer while the hand still reaches for or grasps its piece: the reservation is dropped, the hand is idle at
// once and a piece the feed already took off the source goes back onto it. A transfer past its grasp is committed (Carry,
// AwaitAdmission) and a returning hand finishes its return: there, and while idle, a Cancel is a no-op.
struct FMars_Request_CookingFeed_Cancel
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_CookingFeed_Cancel() {}
}

// A new attempt: the generation is bumped first (every older PieceId goes stale), Admitted is zeroed, and a transfer still
// reaching or grasping is dropped as a Cancel drops it. A committed transfer (Carry, AwaitAdmission) makes the Reset a
// no-op; a returning hand finishes its return under the new attempt. Nothing else is refilled: the source platter is the
// stock.
struct FMars_Request_CookingFeed_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_CookingFeed_Reset() {}
}

// Draw from Source (invalid = none). The stock changed under the hand, so a transfer in flight is cancelled in any phase
// (its piece goes back to the platter it came from), the generation moves on and Admitted is zeroed; the same platter again
// is a no-op.
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

// The cooking kernel's answer to a release. Honoured only while awaiting admission for exactly this PieceId; a rejected
// piece goes back to the platter it came from. Reason is the kernel's own words for a rejection: debug text, logged when
// the rejection is honoured, never shown to the player.
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

//--------------------------------------------------------------------------------------------------------------------------
// The station contract: what a station's control sends to whichever kernel receives its food (Searing, Fry, FoodBoard),
// declared here, by the sender, so the control never names the kernel.
//--------------------------------------------------------------------------------------------------------------------------

// The station's admission inbox, composed by the receiving kernel's Add on the station entity (its presence is what makes
// the station a receiver). utils_cooking_feed::Request_Admit puts a release in; the kernel's own HandleRequests drains it in
// place of an add request of its own and answers each release once on OnAdmission.
struct FMars_Fragment_StationAdmission
{
    UPROPERTY()
    TArray<FMars_CookingFeed_Release> Inbox;
}

// The answer to one release from the inbox: Accepted (the kernel holds the piece now) or Rejected with a reason (the piece is
// left as it was, for the feed to give back).
delegate void FMars_Delegate_StationAdmission_OnAdmission(FCk_Handle InStation, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);
event void FMars_Delegate_StationAdmission_OnAdmission_MC(FCk_Handle InStation, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);

// The station queued something for its receiving kernel (a release in the inbox, a take-out): the kernel's processor wakes
// its own drain on it.
delegate void FMars_Delegate_StationAdmission_OnQueued(FCk_Handle InStation);
event void FMars_Delegate_StationAdmission_OnQueued_MC(FCk_Handle InStation);

// One answer, as the receiving kernel broadcasts it (utils_cooking_feed::Broadcast_Admission).
struct FMars_CookingFeed_AdmissionAnswer
{
    UPROPERTY()
    FMars_CookingFeed_PieceId PieceId;

    UPROPERTY()
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;

    UPROPERTY()
    FString Reason;

    FMars_CookingFeed_AdmissionAnswer() {}

    FMars_CookingFeed_AdmissionAnswer(FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        PieceId = InPieceId;
        Admission = InAdmission;
        Reason = InReason;
    }
}

struct FMars_Fragment_StationAdmission_Signals
{
    FMars_Delegate_StationAdmission_OnAdmission_MC OnAdmission;
    FMars_Delegate_StationAdmission_OnQueued_MC OnQueued;
}

// What a take-out would hand back now, in the order it would: composed by the Add of a kernel that hands pieces back
// (Searing, Fry), written only by that kernel's Tick. The take-out row reads it.
struct FMars_Fragment_StationTakeOut
{
    UPROPERTY()
    TArray<FCk_Handle_FoodPiece> Takeable;
}

// Hand every takeable piece to Tray, at most MaxPieces of them (the tray's room when the press was read). The kernel takes
// each off its ledger, loads it onto the tray and takes back the ones the tray refuses (a heat kernel readopts them, the
// board places them again). A take-out that hands nothing back is refused by the kernel (NoRoom when MaxPieces is at most 0
// or there is no tray, else nothing was takeable).
struct FMars_Request_StationTakeOut
{
    UPROPERTY()
    int32 MaxPieces = 0;

    UPROPERTY()
    FCk_Handle_Platter Tray;

    FMars_Request_StationTakeOut() {}

    FMars_Request_StationTakeOut(int32 InMaxPieces, FCk_Handle_Platter InTray)
    {
        MaxPieces = InMaxPieces;
        Tray = InTray;
    }
}

// One piece a receiving kernel's take-out handed back (Searing, Fry, Batter), broadcast after the kernel's whole drain
// applied.
struct FMars_CookingFeed_TakeOutResult
{
    FMars_CookingFeed_PieceId Id;
    FCk_Handle_FoodPiece Piece;

    FMars_CookingFeed_TakeOutResult() {}

    FMars_CookingFeed_TakeOutResult(FMars_CookingFeed_PieceId InId, FCk_Handle_FoodPiece InPiece)
    {
        Id = InId;
        Piece = InPiece;
    }
}

// The surface of the body a heat kernel gives a piece that arrives without one (its shape is the piece's own mesh, its mass
// the piece's own): utils_cooking_feed::Adopt_Body.
struct FMars_CookingFeed_BodySurface
{
    float32 Friction = 0.5f;
    float32 Restitution = 0.1f;
    float32 LinearDamping = 0.05f;
    float32 AngularDamping = 0.05f;
    float32 GravityFactor = 1.0f;
}

// What utils_cooking_feed::Get_ArrivalVerdict judges: the adopted piece's body and entity, where it was released and how
// long it has been on its way.
struct FMars_CookingFeed_ArrivalQuery
{
    FCk_Handle_JoltBody Body;
    FCk_Handle Entity;
    FVector ReleaseLocation = FVector::ZeroVector;
    float32 Seconds = 0.0f;

    FMars_CookingFeed_ArrivalQuery() {}

    FMars_CookingFeed_ArrivalQuery(FCk_Handle_JoltBody InBody, FCk_Handle InEntity, FVector InReleaseLocation, float32 InSeconds)
    {
        Body = InBody;
        Entity = InEntity;
        ReleaseLocation = InReleaseLocation;
        Seconds = InSeconds;
    }
}

// Queued on the station by utils_cooking_feed::Request_StationTakeOut; drained (and removed) by the receiving kernel's
// HandleRequests.
struct FMars_Fragment_StationTakeOut_Requests
{
    UPROPERTY()
    TArray<FMars_Request_StationTakeOut> TakeOutRequests;
}

// On a piece a station's kernel handed to a tray, from the load until the tray answers: which station sent it, under which
// id, onto which tray. Written only by that kernel's processor (utils_cooking_feed::Send_ToTray, Clear_Landing): the tray's
// answer names only the tray and the piece, and this is how the kernel finds its own.
struct FMars_Fragment_StationLanding
{
    UPROPERTY()
    FCk_Handle Station;

    UPROPERTY()
    FMars_CookingFeed_PieceId PieceId;

    UPROPERTY()
    FCk_Handle_Platter Tray;

    FMars_Fragment_StationLanding() {}

    FMars_Fragment_StationLanding(FCk_Handle InStation, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_Platter InTray)
    {
        Station = InStation;
        PieceId = InPieceId;
        Tray = InTray;
    }
}
