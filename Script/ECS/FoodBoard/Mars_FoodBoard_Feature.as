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
    // Its body reads Dynamic: a released piece stays loose. A piece with no body, or a Kinematic one (a piece taken off a
    // platter keeps the body it dropped with), can be placed.
    Loose,
    // Destroyed before the board drained the request.
    Gone
}

// Loose turns each released piece Dynamic (its own body if it has one, a new body otherwise) and keeps it in the Released
// ring; Handoff gives no body and forgets the piece: it is whoever asked for it to hold (a platter) and the board never
// ends it.
enum EMars_FoodBoard_ReleaseMode
{
    Loose,
    Handoff
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

// The body a sweep gives each released piece. VelocityLocal is in the board's frame, rotated by the board's world rotation at
// the release.
struct FMars_FoodBoard_ReleaseTuners
{
    UPROPERTY()
    FName CollisionProfileName = n"PhysicsActor";

    UPROPERTY()
    float32 Friction = 0.6f;

    UPROPERTY()
    float32 Restitution = 0.1f;

    UPROPERTY()
    FVector VelocityLocal = FVector::ZeroVector;

    FMars_FoodBoard_ReleaseTuners() {}

    FMars_FoodBoard_ReleaseTuners(FName InCollisionProfileName, float32 InFriction, float32 InRestitution, FVector InVelocityLocal)
    {
        CollisionProfileName = InCollisionProfileName;
        Friction = InFriction;
        Restitution = InRestitution;
        VelocityLocal = InVelocityLocal;
    }
}

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

    // Past it the oldest released piece is destroyed with its body, so released pieces stay bounded.
    UPROPERTY()
    int32 MaxReleasedPieces = 24;

    UPROPERTY()
    FMars_FoodBoard_ReleaseTuners Release;
}

struct FMars_FoodBoard_Spec
{
    UPROPERTY()
    FMars_FoodBoard_Tuners Tuners;

    FMars_FoodBoard_Spec() {}

    FMars_FoodBoard_Spec(FMars_FoodBoard_Tuners InTuners)
    {
        Tuners = InTuners;
    }
}

// A board that can hold nothing, a chop that cuts nothing or more than the slice queue serves, a negative parting, an
// unbounded release ring, or a body Jolt would refuse (no profile, negative friction, restitution outside [0, 1], a
// non-finite velocity) each make the ledger or the release unsound. The Transform the board needs is checked by Add.
mixin FMars_Validation Validate(const FMars_FoodBoard_Spec& Self)
{
    const auto Tuners = Self.Tuners;

    if (Tuners.MaxHeldPieces < 1)
    { return FMars_Validation(f"FoodBoard has Tuners.MaxHeldPieces [{Tuners.MaxHeldPieces}] below 1"); }

    if (Tuners.MaxCutsPerChop < 1 || Tuners.MaxCutsPerChop > utils_foodboard::k_MaxCutsPerChop)
    { return FMars_Validation(f"FoodBoard has Tuners.MaxCutsPerChop [{Tuners.MaxCutsPerChop}] outside [1, {utils_foodboard::k_MaxCutsPerChop}]"); }

    if (Math::IsFinite(Tuners.SeparationCm) == false || Tuners.SeparationCm < 0.0f)
    { return FMars_Validation(f"FoodBoard has a negative or non-finite Tuners.SeparationCm [{Tuners.SeparationCm}]"); }

    if (Tuners.MaxReleasedPieces < 1)
    { return FMars_Validation(f"FoodBoard has Tuners.MaxReleasedPieces [{Tuners.MaxReleasedPieces}] below 1"); }

    if (Tuners.Release.CollisionProfileName.IsNone())
    { return FMars_Validation("FoodBoard has no Tuners.Release.CollisionProfileName"); }

    if (Math::IsFinite(Tuners.Release.Friction) == false || Tuners.Release.Friction < 0.0f)
    { return FMars_Validation(f"FoodBoard has a negative or non-finite Tuners.Release.Friction [{Tuners.Release.Friction}]"); }

    if (Math::IsFinite(Tuners.Release.Restitution) == false || Tuners.Release.Restitution < 0.0f || Tuners.Release.Restitution > 1.0f)
    { return FMars_Validation(f"FoodBoard has Tuners.Release.Restitution [{Tuners.Release.Restitution}] outside [0, 1]"); }

    if (utils_foodboard::Get_IsFinite(Tuners.Release.VelocityLocal) == false)
    { return FMars_Validation(f"FoodBoard has a non-finite Tuners.Release.VelocityLocal [{Tuners.Release.VelocityLocal}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_FoodBoard_Params
{
    UPROPERTY()
    FMars_FoodBoard_Tuners Tuners;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the FoodBoard processor (and Add). A ledger, not an owner: every piece belongs to the world's transient
// entity; the board ends the pieces it holds (Clear, its own destruction) and the oldest released past the ring. A piece
// handed off is in neither list.
//
// IsUntouched is true from Add and from every Clear; a placement sets it to whether the board was empty, and a committed cut
// or a release that releases anything sets it false. So it is true exactly while the board holds nothing it was not handed
// whole onto an empty board: control clears only a touched or empty board, and an untouched joint is never rebuilt.
struct FMars_Fragment_FoodBoard
{
    // A cut source's halves take its index, positive half first.
    UPROPERTY()
    TArray<FCk_Handle_FoodPiece> Held;

    // Oldest first.
    UPROPERTY()
    TArray<FCk_Handle_FoodPiece> Released;

    UPROPERTY()
    bool IsUntouched = true;

    // The planes of committed cuts the board has not parted along yet (one per distinct plane): they wait until no cut the
    // board submitted is in flight. A Clear empties them.
    UPROPERTY()
    TArray<FMars_FoodPiece_WorldPlane> Unparted;

    // Chops that arrived while a parting was owed, oldest first, and the sweeps waiting behind them: the drain that parts
    // re-queues them ahead of anything newer, so they cut the parted poses and a sweep never overtakes a chop. A Clear turns
    // the chops into knocks and drops the sweeps. (Held here rather than re-queued every pass, which would spin the
    // scheduler's pump while a cut is in flight. A held piece destroyed elsewhere mid-cut answers nothing: the backlog then
    // waits for the board's next request.)
    UPROPERTY()
    TArray<FMars_Request_FoodBoard_Cut> WaitingCuts;

    UPROPERTY()
    TArray<FMars_Request_FoodBoard_Release> WaitingReleases;

    // Turns that arrived while a cut was in flight, oldest first: they move every held piece, so they wait until the board
    // is quiet and go after the parting, ahead of the releases behind them. A Clear drops them.
    UPROPERTY()
    TArray<FMars_Request_FoodBoard_Turn> WaitingTurns;

    // Pieces a Loose release turned Dynamic on the body they already had, waiting for the mirror to read Dynamic before they
    // take the release velocity (a velocity sent beside the switch reaches a Kinematic body and is lost).
    UPROPERTY()
    TArray<FMars_FoodBoard_PendingLoosen> PendingLoosens;
}

// A released piece whose own body is switching to Dynamic, and the velocity it takes once it reads Dynamic.
struct FMars_FoodBoard_PendingLoosen
{
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    UPROPERTY()
    FVector VelocityWorld;

    FMars_FoodBoard_PendingLoosen() {}

    FMars_FoodBoard_PendingLoosen(FCk_Handle_FoodPiece InPiece, FVector InVelocityWorld)
    {
        Piece = InPiece;
        VelocityWorld = InVelocityWorld;
    }
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

// The piece is no longer the board's to cut or clear. Loose: it has its body (setup may still be pending); Handoff: it has
// none and lies where the board left it until its new holder takes it.
delegate void FMars_Delegate_FoodBoard_OnReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_FoodBoard_OnReleased_MC(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece);

// Once per drain holding a Clear, an already empty board included.
delegate void FMars_Delegate_FoodBoard_OnCleared(FCk_Handle_FoodBoard InBoard);
event void FMars_Delegate_FoodBoard_OnCleared_MC(FCk_Handle_FoodBoard InBoard);

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
    FMars_Delegate_FoodBoard_OnCleared_MC OnCleared;
    FMars_Delegate_FoodBoard_OnTurned_MC OnTurned;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Destroy every held piece (released ones are untouched): the board is empty and untouched. Several in one drain are one.
// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_FoodBoard_Clear
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_FoodBoard_Clear() {}
}

// Issued only by the board's own handler, once per resolved cut of a held piece. A Cut's halves take Source's place, or are
// destroyed when Source is no longer held (cleared meanwhile); any other outcome leaves Source held and whole. Either way the
// drain learns the board may be quiet, which is when it parts.
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

// Hold Piece (Pending pieces included); refused, never deferred, with OnPlaceRefused. A Place still queued when the board
// is destroyed never drains (a dying entity is skipped): that piece stays the caller's to end.
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

    FMars_Request_FoodBoard_Cut() {}

    FMars_Request_FoodBoard_Cut(FMars_FoodPiece_WorldPlane InPlane)
    {
        Plane = InPlane;
    }
}

// Release the held pieces that are Ready and not cutting; a piece still cutting stays held. Several in one drain apply in
// order, each with its own mode and cap. Default: Loose, every free piece.
struct FMars_Request_FoodBoard_Release
{
    UPROPERTY()
    EMars_FoodBoard_ReleaseMode Mode = EMars_FoodBoard_ReleaseMode::Loose;

    // Set: at most this many pieces leave, held order; unset: every free piece.
    UPROPERTY()
    TOptional<int32> MaxPieces;

    FMars_Request_FoodBoard_Release() {}

    FMars_Request_FoodBoard_Release(EMars_FoodBoard_ReleaseMode InMode, TOptional<int32> InMaxPieces)
    {
        Mode = InMode;
        MaxPieces = InMaxPieces;
    }
}

// Yaw every held piece YawDegrees about PivotWorld's location, on the world's vertical axis: each piece's location and
// rotation turn together, so the food turns as one on the board.
struct FMars_Request_FoodBoard_Turn
{
    UPROPERTY()
    FTransform PivotWorld;

    UPROPERTY()
    float32 YawDegrees = 0.0f;

    FMars_Request_FoodBoard_Turn() {}

    FMars_Request_FoodBoard_Turn(FTransform InPivotWorld, float32 InYawDegrees)
    {
        PivotWorld = InPivotWorld;
        YawDegrees = InYawDegrees;
    }
}

// A non-finite pivot or yaw would write non-finite poses onto every held piece.
mixin FMars_Validation Validate(const FMars_Request_FoodBoard_Turn& Self)
{
    if (Math::IsFinite(Self.YawDegrees) == false)
    { return FMars_Validation(f"FoodBoard Turn has a non-finite YawDegrees [{Self.YawDegrees}]"); }

    if (utils_foodboard::Get_IsFinite(Self.PivotWorld.GetLocation()) == false)
    { return FMars_Validation(f"FoodBoard Turn has a non-finite pivot [{Self.PivotWorld.GetLocation()}]"); }

    return FMars_Validation();
}

// Applied Clear -> ResolveCut -> (parting) -> Place -> Cut -> Turn -> Release: a clear and the next joint's placement can
// share a drain, a cut that committed before the clear never reaches the next joint, and a chop sees the halves of every
// committed cut. Cut and Release wait (whole, in order) while the board owes a parting, so a chop always cuts the parted
// poses; a Turn (and every Release behind it) waits while any cut is in flight, so it turns the halves, never a source.
struct FMars_Fragment_FoodBoard_Requests
{
    UPROPERTY()
    TArray<FMars_Request_FoodBoard_Clear> ClearRequests;

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
}
