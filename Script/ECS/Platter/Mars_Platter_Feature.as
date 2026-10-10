//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PlatterHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Platter";
    RequiredFragments.Add(FMars_Feature_Platter);
    Description = "A tray of food: a ledger of FoodPiece handles dropped between its walls, settled with physics and frozen into a pile that rides the platter root";
}
struct FMars_Feature_Platter {}

//--------------------------------------------------------------------------------------------------------------------------
// Vocabulary
//--------------------------------------------------------------------------------------------------------------------------

// Why a Load left the piece off the platter. Cutting and Failed are the piece's own states (a slice in flight would resolve
// on a piece the ledger no longer tracks; a failed import has no geometry to drop).
enum EMars_Platter_LoadRefusal
{
    Full,
    AlreadyHeld,
    HeldElsewhere,
    // Destroyed before the platter drained the request.
    Gone,
    Cutting,
    Failed
}

// Why a piece is moving on the platter: its first landing (OnLoaded fires when it freezes) or a pile re-settling under it
// after another piece left (it freezes again silently: it was loaded already).
enum EMars_Platter_SettleReason
{
    Load,
    Resettle
}

// Why a settling piece was frozen: it came to rest, or it was still moving at Settle.MaxSeconds.
enum EMars_Platter_FreezeCause
{
    Settled,
    TimedOut
}

namespace constants_platter
{
    // The root counts as still between two passes while it moves less than this and turns less than k_StillDegrees: a tray
    // in a hand or on its way to a dock drops nothing.
    const float64 k_StillCm = 0.5;
    const float64 k_StillDegrees = 1.0;

    // The walls: kinematic boxes this thick, lifted this far off the floor so they never touch the tray's own body, in a
    // profile that blocks every body but a pawn's (the operator walks through them; the interaction trace sees no world
    // body at all).
    const float64 k_WallThicknessCm = 2.0;
    const float64 k_WallLiftCm = 0.2;
    const FName k_WallCollisionProfile = n"IgnoreOnlyPawn";
    const float32 k_WallFriction = 0.3f;
    const float32 k_WallRestitution = 0.0f;
    const float32 k_WallMassKg = 1.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// In the platter root's frame, whose origin is the centre of the inner floor (+Z up).
struct FMars_Platter_Bounds
{
    // Half the floor the pile may cover: the walls stand centred on its edges.
    UPROPERTY()
    FVector2D InnerHalfExtents = FVector2D(10.0, 10.0);

    UPROPERTY()
    float32 WallHeight = 40.0f;

    // How far above the floor a dropped piece's bottom starts.
    UPROPERTY()
    float32 DropHeight = 25.0f;

    FMars_Platter_Bounds() {}

    FMars_Platter_Bounds(FVector2D InInnerHalfExtents, float32 InWallHeight, float32 InDropHeight)
    {
        InnerHalfExtents = InInnerHalfExtents;
        WallHeight = InWallHeight;
        DropHeight = InDropHeight;
    }
}

// The drift watchdog: Jolt never puts a flat or thin piece to sleep, so a piece also counts as settled once its position has
// stayed within DriftCm for DwellSeconds, sampled every SampleSeconds.
struct FMars_Platter_SettleTuners
{
    // One queued piece drops per cadence, and only while the root is still.
    UPROPERTY()
    float32 DropCadenceSeconds = 0.2f;

    UPROPERTY()
    float32 SampleSeconds = 0.15f;

    UPROPERTY()
    float32 DriftCm = 0.5f;

    UPROPERTY()
    float32 DwellSeconds = 0.4f;

    // A piece still moving this long after its drop is frozen where it is.
    UPROPERTY()
    float32 MaxSeconds = 3.0f;
}

struct FMars_Platter_Spec
{
    UPROPERTY()
    int32 Capacity = 4;

    UPROPERTY()
    FMars_Platter_Bounds Bounds;

    UPROPERTY()
    FMars_Platter_SettleTuners Settle;

    FMars_Platter_Spec() {}

    FMars_Platter_Spec(int32 InCapacity, const FMars_Platter_Bounds& InBounds)
    {
        Capacity = InCapacity;
        Bounds = InBounds;
    }
}

// No room is no platter; the walls and the drop need a finite, positive floor and heights; a watchdog tuner of zero never
// samples or never lets go, and a piece must get its dwell before the timeout. The Transform the platter needs is checked
// by Add.
mixin FMars_Validation Validate(const FMars_Platter_Spec& Self)
{
    if (Self.Capacity < 1)
    { return FMars_Validation(f"Platter has a Capacity [{Self.Capacity}] below 1"); }

    const auto Half = Self.Bounds.InnerHalfExtents;
    if (Math::IsFinite(Half.X) == false || Math::IsFinite(Half.Y) == false || Half.X <= 0.0 || Half.Y <= 0.0)
    { return FMars_Validation(f"Platter has a non-positive or non-finite InnerHalfExtents [{Half}]"); }

    if (Math::IsFinite(Self.Bounds.WallHeight) == false || Self.Bounds.WallHeight <= 0.0f)
    { return FMars_Validation(f"Platter has a non-positive or non-finite WallHeight [{Self.Bounds.WallHeight}]"); }

    if (Math::IsFinite(Self.Bounds.DropHeight) == false || Self.Bounds.DropHeight <= 0.0f)
    { return FMars_Validation(f"Platter has a non-positive or non-finite DropHeight [{Self.Bounds.DropHeight}]"); }

    const auto& Settle = Self.Settle;
    TArray<float32> Tuners;
    Tuners.Add(Settle.DropCadenceSeconds);
    Tuners.Add(Settle.SampleSeconds);
    Tuners.Add(Settle.DriftCm);
    Tuners.Add(Settle.DwellSeconds);
    Tuners.Add(Settle.MaxSeconds);
    for (const auto Tuner : Tuners)
    {
        if (Math::IsFinite(Tuner) == false || Tuner <= 0.0f)
        { return FMars_Validation(f"Platter has a non-positive or non-finite settle tuner [{Tuner}]"); }
    }

    if (Settle.MaxSeconds <= Settle.DwellSeconds)
    { return FMars_Validation(f"Platter's Settle.MaxSeconds [{Settle.MaxSeconds}] is not above its DwellSeconds [{Settle.DwellSeconds}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Platter_Params
{
    UPROPERTY()
    FMars_Platter_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// A piece dropped (or re-settling) between the walls, Dynamic, watched until it rests.
struct FMars_Platter_Settling
{
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    UPROPERTY()
    EMars_Platter_SettleReason Reason = EMars_Platter_SettleReason::Load;

    // The watchdog's anchor, in the root's frame (a pile riding a carried tray settles too): where the piece was when it
    // last moved more than DriftCm.
    UPROPERTY()
    FVector LastSample;

    UPROPERTY()
    float32 StillSeconds = 0.0f;

    UPROPERTY()
    float32 SinceSample = 0.0f;

    // Since the drop or the re-settle.
    UPROPERTY()
    float32 Seconds = 0.0f;

    // Re-drops after an escape: one, then a piece is accepted where it lies.
    UPROPERTY()
    int32 Redrops = 0;

    // Set once Kinematic was asked for: the attach waits for the body's mirror to read it.
    UPROPERTY()
    TOptional<EMars_Platter_FreezeCause> Freeze;

    FMars_Platter_Settling() {}

    FMars_Platter_Settling(FCk_Handle_FoodPiece InPiece, EMars_Platter_SettleReason InReason, FVector InLastSample)
    {
        Piece = InPiece;
        Reason = InReason;
        LastSample = InLastSample;
    }
}

// Written only by the Platter processors (and Add). A ledger, not an owner: every piece belongs to the world's transient
// entity; the platter ends the pieces it holds (Clear, its own destruction). A piece is in exactly one of Held, Settling
// and Queue.
struct FMars_Fragment_Platter
{
    // Frozen, Kinematic, scene-node children of the root, in freeze order: the top of the pile last.
    UPROPERTY()
    TArray<FCk_Handle_FoodPiece> Held;

    // Accepted loads waiting to drop, oldest first.
    UPROPERTY()
    TArray<FCk_Handle_FoodPiece> Queue;

    UPROPERTY()
    TArray<FMars_Platter_Settling> Settling;

    // Built by Add: kinematic boxes on the floor's four edges, riding the root.
    UPROPERTY()
    TArray<FCk_Handle_JoltBody> Walls;

    // The root's world transform at the last pass; unset before the first.
    UPROPERTY()
    TOptional<FTransform> RootLast;

    // Seconds the root has been still since the last drop.
    UPROPERTY()
    float32 SinceDrop = 0.0f;
}

// On every piece the platter holds (held, settling or queued); written only by the Platter processors. Removed on Unload,
// Clear, refusal and when Reconcile finds the piece gone.
struct FMars_Fragment_Platter_Membership
{
    UPROPERTY()
    FCk_Handle_Platter Platter;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// A loaded piece froze into the pile (once per Load; a re-settle is silent).
delegate void FMars_Delegate_Platter_OnLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_Platter_OnLoaded_MC(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece);

delegate void FMars_Delegate_Platter_OnLoadRefused(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal);
event void FMars_Delegate_Platter_OnLoadRefused_MC(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal);

// A loaded piece left: unloaded, taken off the root by something else, or destroyed (Reconcile).
delegate void FMars_Delegate_Platter_OnUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_Platter_OnUnloaded_MC(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece);

// Once per drain holding a Clear, an empty platter included.
delegate void FMars_Delegate_Platter_OnCleared(FCk_Handle_Platter InPlatter);
event void FMars_Delegate_Platter_OnCleared_MC(FCk_Handle_Platter InPlatter);

struct FMars_Fragment_Platter_Signals
{
    FMars_Delegate_Platter_OnLoaded_MC OnLoaded;
    FMars_Delegate_Platter_OnLoadRefused_MC OnLoadRefused;
    FMars_Delegate_Platter_OnUnloaded_MC OnUnloaded;
    FMars_Delegate_Platter_OnCleared_MC OnCleared;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Put Piece on the platter. Refused at the drain (never deferred) Full / AlreadyHeld / HeldElsewhere / Gone / Cutting /
// Failed with OnLoadRefused; accepted, it queues. A queued piece drops once it is Ready (one whose import fails is refused
// Failed then) and the root is still, settles with physics and freezes into the pile (OnLoaded).
struct FMars_Request_Platter_Load
{
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    FMars_Request_Platter_Load() {}

    FMars_Request_Platter_Load(FCk_Handle_FoodPiece InPiece)
    {
        Piece = InPiece;
    }
}

// Take Piece off at its current world pose, its body Kinematic; the rest of the pile re-settles. A queued piece, or one
// dropping for its first landing, is dropped without a signal (it never landed); a landed one leaves with OnUnloaded.
// Several Unloads of one piece in a drain are one: two controls may each ask for the same piece across a state change. A
// piece this platter does not hold is a caller defect (ensure, nothing else).
struct FMars_Request_Platter_Unload
{
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    FMars_Request_Platter_Unload() {}

    FMars_Request_Platter_Unload(FCk_Handle_FoodPiece InPiece)
    {
        Piece = InPiece;
    }
}

// Destroy every piece: held, settling and queued; the platter is empty. Several in one drain are one.
// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Platter_Clear
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Platter_Clear() {}
}

// Applied Clear -> Unload -> Load: a clear and the next load can share a drain, and an unload never races a load of the
// same piece.
struct FMars_Fragment_Platter_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Platter_Clear> ClearRequests;

    UPROPERTY()
    TArray<FMars_Request_Platter_Unload> UnloadRequests;

    UPROPERTY()
    TArray<FMars_Request_Platter_Load> LoadRequests;
}
