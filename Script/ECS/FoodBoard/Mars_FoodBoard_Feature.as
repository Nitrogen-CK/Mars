//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_FoodBoardHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_FoodBoard";
    RequiredFragments.Add(FMars_Feature_FoodBoard);
    Description = "The food a station holds: a ledger of FoodPiece handles that a chop cuts within a budget and a sweep releases as physics bodies";
}
struct FMars_Feature_FoodBoard {}

//--------------------------------------------------------------------------------------------------------------------------
// Vocabulary
//--------------------------------------------------------------------------------------------------------------------------

// Why a Place left the piece off the board. Never deferred.
enum EMars_FoodBoard_PlaceRefusal
{
    // The board already holds MaxHeldPieces, counting the second half of every cut it has in flight.
    Full,
    AlreadyHeld,
    HeldElsewhere,
    // Its body reads Dynamic: a piece the physics moves is not the board's to pose. A piece with no body, or a Kinematic one
    // (a piece taken off a platter keeps the body it dropped with), can be placed.
    Loose,
    // Destroyed before the board drained the request.
    Gone
}

// Why a Release handed nothing off.
enum EMars_FoodBoard_ReleaseRefusal
{
    // The release was capped at zero pieces: no tray docked, or a full one.
    NoRoom,
    // No held piece is Ready and not cutting.
    NothingFree
}

// What one Cut request did. Issued 0 is a knock: nothing straddled the plane, or the board had no room for another half.
struct FMars_FoodBoard_CutIssue
{
    // Held pieces, Ready and not cutting, whose bounds the plane crosses.
    UPROPERTY()
    int32 Straddling = 0;

    // MaxCutsPerChop, less whatever MaxHeldPieces leaves no room for.
    UPROPERTY()
    int32 Budget = 0;

    // Cuts submitted, nearest straddling piece first.
    UPROPERTY()
    int32 Issued = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_FoodBoard_Tuners
{
    UPROPERTY()
    int32 MaxHeldPieces = 12;

    // RuntimeMesh slices two per frame from one world-wide queue of 16, so a chop fans out to a few pieces at most.
    UPROPERTY()
    int32 MaxCutsPerChop = 2;

    // Every committed cut parts the board along its plane: each held piece moves SeparationCm / 2 away from the plane on
    // its own side, so the new cut opens a gap of SeparationCm and every earlier gap keeps its width. The board parts once
    // it is quiet (no cut it submitted still in flight), once per distinct plane, so a chop whose cuts commit over several
    // frames parts once and no in-flight piece moves under its blade.
    UPROPERTY()
    float32 SeparationCm = 0.3f;
}

struct FMars_FoodBoard_Spec
{
    UPROPERTY()
    FMars_FoodBoard_Tuners Tuners;

    // Where the food lies on the board (its top, under the blade), built by the station's assembly: a placed piece is posed
    // on it in its food's layout, and a turn yaws the held pieces about it. Not a UPROPERTY: the spawn params never carry
    // handles.
    FCk_Handle_Transform PileNode;

    FMars_FoodBoard_Spec() {}

    FMars_FoodBoard_Spec(FMars_FoodBoard_Tuners InTuners, FCk_Handle_Transform InPileNode)
    {
        Tuners = InTuners;
        PileNode = InPileNode;
    }
}

// A board that can hold nothing, a chop that cuts nothing or more than the slice queue serves, or a negative parting each
// make the ledger unsound. The Transform and the pile node the board needs are checked by Add.
mixin FMars_Validation Validate(const FMars_FoodBoard_Spec& Self)
{
    const auto Tuners = Self.Tuners;

    if (Tuners.MaxHeldPieces < 1)
    { return FMars_Validation(f"FoodBoard has Tuners.MaxHeldPieces [{Tuners.MaxHeldPieces}] below 1"); }

    if (Tuners.MaxCutsPerChop < 1 || Tuners.MaxCutsPerChop > utils_foodboard::k_MaxCutsPerChop)
    { return FMars_Validation(f"FoodBoard has Tuners.MaxCutsPerChop [{Tuners.MaxCutsPerChop}] outside [1, {utils_foodboard::k_MaxCutsPerChop}]"); }

    if (Math::IsFinite(Tuners.SeparationCm) == false || Tuners.SeparationCm < 0.0f)
    { return FMars_Validation(f"FoodBoard has a negative or non-finite Tuners.SeparationCm [{Tuners.SeparationCm}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_FoodBoard_Params
{
    UPROPERTY()
    FMars_FoodBoard_Tuners Tuners;

    UPROPERTY()
    FCk_Handle_Transform PileNode;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_FoodBoard_OpKind
{
    Cut,
    Turn,
    Release
}

// One entry of the board's queue: the request of its Kind, and its place in arrival order.
struct FMars_FoodBoard_Op
{
    UPROPERTY()
    int32 Sequence = 0;

    UPROPERTY()
    EMars_FoodBoard_OpKind Kind = EMars_FoodBoard_OpKind::Cut;

    UPROPERTY()
    FMars_Request_FoodBoard_Cut Cut;

    UPROPERTY()
    FMars_Request_FoodBoard_Turn Turn;

    UPROPERTY()
    FMars_Request_FoodBoard_Release Release;
}

// Written only by the FoodBoard processor (and Add). A ledger, not an owner: every piece belongs to the world's transient
// entity; the board ends the pieces it holds when it is destroyed. A piece handed off is no longer in the ledger. The board
// stamps every piece it holds with the holder fact (FMars_Fragment_FoodPiece_Holder) and removes it when it lets go.
struct FMars_Fragment_FoodBoard
{
    // A cut source's halves take its index, positive half first.
    UPROPERTY()
    TArray<FCk_Handle_FoodPiece> Held;

    // The planes of committed cuts the board has not parted along yet (one per distinct plane): they wait until no cut the
    // board submitted is in flight.
    UPROPERTY()
    TArray<FMars_FoodPiece_WorldPlane> Unparted;

    // The board's cuts, turns and releases in arrival order, oldest first, applied from the head and blocked at it (Drain
    // order on FMars_Fragment_FoodBoard_Requests): a chop never overtakes a turn or a sweep queued before it, nor they it.
    // (Held here rather than re-queued every pass, which would spin the scheduler's pump while a cut is in flight. A held
    // piece destroyed elsewhere mid-cut answers nothing: the queue then waits for the board's next request.)
    UPROPERTY()
    TArray<FMars_FoodBoard_Op> Queue;
}

// On every held piece; written only by the FoodBoard processor. PendingCutPlane (world, unit normal) is the plane of the cut
// the board submitted, set until that cut resolves; it is what parts the board once the cut commits and the board is
// quiet. Removed when the piece is released.
struct FMars_Fragment_FoodBoard_Membership
{
    UPROPERTY()
    FCk_Handle_FoodBoard Board;

    UPROPERTY()
    TOptional<FMars_FoodPiece_WorldPlane> PendingCutPlane;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_FoodBoard_OnPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_FoodBoard_OnPlaced_MC(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece);

delegate void FMars_Delegate_FoodBoard_OnPlaceRefused(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece, EMars_FoodBoard_PlaceRefusal InRefusal);
event void FMars_Delegate_FoodBoard_OnPlaceRefused_MC(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece, EMars_FoodBoard_PlaceRefusal InRefusal);

// Once per Cut request, as soon as its cuts are submitted (they resolve later, each as an OnPieceCut or not at all).
delegate void FMars_Delegate_FoodBoard_OnCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue);
event void FMars_Delegate_FoodBoard_OnCutIssued_MC(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue);

// A held piece was cut: its halves hold its place and InSource is being destroyed. The halves are already Ready (a cut
// half is born Ready): compose on them here rather than waiting for their OnReady.
delegate void FMars_Delegate_FoodBoard_OnPieceCut(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative);
event void FMars_Delegate_FoodBoard_OnPieceCut_MC(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InSource, FCk_Handle_FoodPiece InPositive, FCk_Handle_FoodPiece InNegative);

// The piece is no longer the board's to cut: it lies where the board left it, with whatever body it had, until its new
// holder takes it.
delegate void FMars_Delegate_FoodBoard_OnReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_FoodBoard_OnReleased_MC(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece);

// A Release that handed nothing off, and why: judged when the release is applied, so one waiting behind cuts in flight is
// refused only then.
delegate void FMars_Delegate_FoodBoard_OnReleaseRefused(FCk_Handle_FoodBoard InBoard, EMars_FoodBoard_ReleaseRefusal InRefusal);
event void FMars_Delegate_FoodBoard_OnReleaseRefused_MC(FCk_Handle_FoodBoard InBoard, EMars_FoodBoard_ReleaseRefusal InRefusal);

// Once per applied Turn, an empty board's included.
delegate void FMars_Delegate_FoodBoard_OnTurned(FCk_Handle_FoodBoard InBoard, float32 InYawDegrees);
event void FMars_Delegate_FoodBoard_OnTurned_MC(FCk_Handle_FoodBoard InBoard, float32 InYawDegrees);

struct FMars_Fragment_FoodBoard_Signals
{
    FMars_Delegate_FoodBoard_OnPlaced_MC OnPlaced;
    FMars_Delegate_FoodBoard_OnPlaceRefused_MC OnPlaceRefused;
    FMars_Delegate_FoodBoard_OnCutIssued_MC OnCutIssued;
    FMars_Delegate_FoodBoard_OnPieceCut_MC OnPieceCut;
    FMars_Delegate_FoodBoard_OnReleased_MC OnReleased;
    FMars_Delegate_FoodBoard_OnReleaseRefused_MC OnReleaseRefused;
    FMars_Delegate_FoodBoard_OnTurned_MC OnTurned;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Issued only by the board's own handler, once per resolved cut of a held piece. A Cut's halves take Source's place, or are
// destroyed when Source is no longer held; any other outcome leaves Source held and whole. Either way the drain learns the
// board may be quiet, which is when it parts.
struct FMars_Request_FoodBoard_ResolveCut
{
    UPROPERTY()
    FCk_Handle_FoodPiece Source;

    UPROPERTY()
    EMars_FoodPiece_CutOutcome Outcome = EMars_FoodPiece_CutOutcome::Failed;

    // Valid only for a Cut.
    UPROPERTY()
    FCk_Handle_FoodPiece Positive;

    UPROPERTY()
    FCk_Handle_FoodPiece Negative;

    // The board's cut plane (unit normal toward Positive); unset when the cut was not the board's (no parting).
    UPROPERTY()
    TOptional<FMars_FoodPiece_WorldPlane> Plane;

    FMars_Request_FoodBoard_ResolveCut() {}

    FMars_Request_FoodBoard_ResolveCut(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult, TOptional<FMars_FoodPiece_WorldPlane> InPlane)
    {
        Source = InSource;
        Outcome = InResult.Outcome;
        Positive = InResult.Positive;
        Negative = InResult.Negative;
        Plane = InPlane;
    }
}

// Hold Piece (Pending pieces included), its pickup's Ledger claim held while the board holds it; refused, never deferred,
// with OnPlaceRefused (another ledger's piece by its holder fact). A Place still queued when the board is destroyed never
// drains (a dying entity is skipped): that piece stays the caller's to end. A release in the station's admission inbox is
// placed the same way, posed on the pile node in its food's layout, and answered on the station's OnAdmission.
struct FMars_Request_FoodBoard_Place
{
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    FMars_Request_FoodBoard_Place() {}

    FMars_Request_FoodBoard_Place(FCk_Handle_FoodPiece InPiece)
    {
        Piece = InPiece;
    }
}

// Cut the held pieces Plane crosses, within the chop's budget.
struct FMars_Request_FoodBoard_Cut
{
    UPROPERTY()
    FMars_FoodPiece_WorldPlane Plane;

    // Its place among the drain's cuts, turns and releases; stamped by Request_Cut.
    UPROPERTY()
    int32 Sequence = 0;

    FMars_Request_FoodBoard_Cut() {}

    FMars_Request_FoodBoard_Cut(FMars_FoodPiece_WorldPlane InPlane)
    {
        Plane = InPlane;
    }
}

// Hand off the held pieces that are Ready and not cutting: each is let go where it lies and the board forgets it. Without a
// Tray it is whoever asked for it to hold it (the board never ends it) and its pickup's Ledger claim goes; with one, the
// board loads it onto Tray, keeps the claim until it lands and places it back on the board when the tray refuses it (the
// station's take-out contract, FMars_Request_StationTakeOut, arrives as this). A piece still cutting stays held. Several in
// one drain apply in order, each with its own cap. Default: every free piece. A release that hands off nothing is refused
// with OnReleaseRefused (NoRoom when MaxPieces is set and at most 0, else NothingFree), judged when it is applied: one
// waiting behind cuts in flight is refused only then.
struct FMars_Request_FoodBoard_Release
{
    // Set: at most this many pieces leave, held order; unset: every free piece.
    UPROPERTY()
    TOptional<int32> MaxPieces;

    // Valid: where every piece let go lands (an invalid one: let go where it lies).
    UPROPERTY()
    FCk_Handle_Platter Tray;

    // Its place among the drain's cuts, turns and releases; stamped by Request_Release.
    UPROPERTY()
    int32 Sequence = 0;

    FMars_Request_FoodBoard_Release() {}

    FMars_Request_FoodBoard_Release(TOptional<int32> InMaxPieces)
    {
        MaxPieces = InMaxPieces;
    }

    FMars_Request_FoodBoard_Release(TOptional<int32> InMaxPieces, FCk_Handle_Platter InTray)
    {
        MaxPieces = InMaxPieces;
        Tray = InTray;
    }
}

// Yaw every held piece DeltaDegrees about the board's pile node, on the world's vertical axis: each piece's location and
// rotation turn together, so the food turns as one on the board. An offset, not a heading: turns that reach the head of the
// queue together apply as one yaw of their sum.
struct FMars_Request_FoodBoard_Turn
{
    UPROPERTY()
    float32 DeltaDegrees = 0.0f;

    // Its place among the drain's cuts, turns and releases; stamped by Request_Turn.
    UPROPERTY()
    int32 Sequence = 0;

    FMars_Request_FoodBoard_Turn() {}

    FMars_Request_FoodBoard_Turn(float32 InDeltaDegrees)
    {
        DeltaDegrees = InDeltaDegrees;
    }
}

// A non-finite yaw would write non-finite poses onto every held piece.
mixin FMars_Validation Validate(const FMars_Request_FoodBoard_Turn& Self)
{
    if (Math::IsFinite(Self.DeltaDegrees) == false)
    { return FMars_Validation(f"FoodBoard Turn has a non-finite DeltaDegrees [{Self.DeltaDegrees}]"); }

    return FMars_Validation();
}

// Applied ResolveCut -> (parting) -> Place (the station inbox's releases after) -> the queue: this drain's cuts, turns and
// releases join it in arrival order (Sequence; the station's take-outs after them), and it applies from its head until an
// entry must wait. A cut waits while the board owes a parting (it cuts the parted poses) and in a drain that moved the
// pieces; a turn waits while any cut is in flight (it turns the halves, never a source) and in a drain that moved the
// pieces; a release never waits on its own. Whatever is behind a waiting entry waits with it.
struct FMars_Fragment_FoodBoard_Requests
{
    UPROPERTY()
    TArray<FMars_Request_FoodBoard_ResolveCut> ResolveCutRequests;

    UPROPERTY()
    TArray<FMars_Request_FoodBoard_Place> PlaceRequests;

    UPROPERTY()
    TArray<FMars_Request_FoodBoard_Cut> CutRequests;

    UPROPERTY()
    TArray<FMars_Request_FoodBoard_Turn> TurnRequests;

    UPROPERTY()
    TArray<FMars_Request_FoodBoard_Release> ReleaseRequests;

    // The next Sequence the request mixins stamp.
    UPROPERTY()
    int32 NextSequence = 0;
}
