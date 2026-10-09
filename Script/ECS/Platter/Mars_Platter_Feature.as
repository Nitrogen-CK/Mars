//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PlatterHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Platter";
    RequiredFragments.Add(FMars_Feature_Platter);
    Description = "A carried tray of food: a ledger of FoodPiece handles riding the platter root as scene-node children, one per slot";
}
struct FMars_Feature_Platter {}

//--------------------------------------------------------------------------------------------------------------------------
// Vocabulary
//--------------------------------------------------------------------------------------------------------------------------

// Why a Load left the piece off the platter. Cutting and Failed are the piece's own states (a slice in flight would resolve
// on a piece the ledger no longer tracks; a failed import has no geometry to pose).
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

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Platter_Spec
{
    // Slot poses in the platter root's frame; capacity = Num(). A loaded piece's bounds centre sits over the slot and its
    // bounds bottom on the slot's Z, in the slot's rotation.
    UPROPERTY()
    TArray<FTransform> SlotsLocal;

    // Seconds a loaded piece lerps from where it was to its slot. 0 snaps.
    UPROPERTY()
    float32 ArriveSeconds = 0.25f;

    FMars_Platter_Spec() {}

    FMars_Platter_Spec(TArray<FTransform> InSlotsLocal, float32 InArriveSeconds)
    {
        SlotsLocal = InSlotsLocal;
        ArriveSeconds = InArriveSeconds;
    }
}

// No slot is no platter; a non-finite slot or a negative arrival makes the pose or the lerp unsound, and a scaled slot would
// scale its piece (a piece is cut and given a body only at unit scale). The Transform the platter needs is checked by Add.
mixin FMars_Validation Validate(const FMars_Platter_Spec& Self)
{
    if (Self.SlotsLocal.Num() < 1)
    { return FMars_Validation("Platter has no SlotsLocal"); }

    for (int32 Index = 0; Index < Self.SlotsLocal.Num(); ++Index)
    {
        const auto& Slot = Self.SlotsLocal[Index];
        if (Slot.ContainsNaN())
        { return FMars_Validation(f"Platter slot [{Index}] is not a finite transform"); }

        if (Slot.GetScale3D().Equals(FVector::OneVector, utils_foodpiece::k_UnitScaleTolerance) == false)
        { return FMars_Validation(f"Platter slot [{Index}] has scale [{Slot.GetScale3D()}]: a piece rides its slot unscaled"); }
    }

    if (Math::IsFinite(Self.ArriveSeconds) == false || Self.ArriveSeconds < 0.0f)
    { return FMars_Validation(f"Platter has a negative or non-finite ArriveSeconds [{Self.ArriveSeconds}]"); }

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

// One accepted Load the commit still waits on: the piece must be Ready (a joint still importing) and its body, if any, must
// read Kinematic (the attach would fight a Dynamic body's writeback). The slot is reserved from the drain.
struct FMars_Platter_PendingLoad
{
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    UPROPERTY()
    int32 Slot = -1;

    // Where the piece visually was at the request; unset = it appears at the slot.
    UPROPERTY()
    TOptional<FTransform> ArriveFrom;

    FMars_Platter_PendingLoad() {}

    FMars_Platter_PendingLoad(FCk_Handle_FoodPiece InPiece, int32 InSlot, TOptional<FTransform> InArriveFrom)
    {
        Piece = InPiece;
        Slot = InSlot;
        ArriveFrom = InArriveFrom;
    }
}

// Written only by the Platter processors (and Add). A ledger, not an owner: every piece belongs to the world's transient
// entity; the platter ends the pieces it holds (Clear, its own destruction).
struct FMars_Fragment_Platter
{
    // SlotsLocal.Num() entries; invalid = empty. A slot with a pending load reads invalid here and taken in Pending.
    UPROPERTY()
    TArray<FCk_Handle_FoodPiece> Slots;

    UPROPERTY()
    TArray<FMars_Platter_PendingLoad> Pending;
}

// On every held piece (pending included); written only by the Platter processors. Removed on Unload, Clear and refusal.
struct FMars_Fragment_Platter_Membership
{
    UPROPERTY()
    FCk_Handle_Platter Platter;

    UPROPERTY()
    int32 Slot = -1;
}

// On a piece whose load committed with an ArriveFrom: the scene-node offset lerps FromOffset -> ToOffset over Duration
// (OutCubic, as a world item arrives). Written by the Load processor, drained by the Arrive processor.
struct FMars_Fragment_Platter_Arrival
{
    UPROPERTY()
    FTransform FromOffset;

    UPROPERTY()
    FTransform ToOffset;

    UPROPERTY()
    float32 Duration = 0.0f;

    UPROPERTY()
    float32 Elapsed = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Platter_OnLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, int32 InSlot);
event void FMars_Delegate_Platter_OnLoaded_MC(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, int32 InSlot);

delegate void FMars_Delegate_Platter_OnLoadRefused(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal);
event void FMars_Delegate_Platter_OnLoadRefused_MC(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal);

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

// Hold Piece in the lowest free slot. Refused (never deferred) Full / AlreadyHeld / HeldElsewhere / Gone / Cutting with
// OnLoadRefused; accepted, it is pending until the piece is Ready and its body (if any) reads Kinematic, then committed
// (OnLoaded) or, if the import fails meanwhile, refused Failed.
struct FMars_Request_Platter_Load
{
    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    UPROPERTY()
    TOptional<FTransform> ArriveFrom;

    FMars_Request_Platter_Load() {}

    FMars_Request_Platter_Load(FCk_Handle_FoodPiece InPiece)
    {
        Piece = InPiece;
    }

    FMars_Request_Platter_Load(FCk_Handle_FoodPiece InPiece, const FTransform& InArriveFrom)
    {
        Piece = InPiece;
        ArriveFrom = TOptional<FTransform>(InArriveFrom);
    }
}

// Detach Piece at its current world pose and free its slot. A pending load of Piece is dropped (no OnLoaded, no OnUnloaded:
// it never landed). Several Unloads of one piece in a drain are one (one OnUnloaded): two controls may each ask for the
// same piece across a state change. A piece this platter does not hold is a caller defect (ensure, nothing else).
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

// Destroy every held piece, pending ones included; the platter is empty. Several in one drain are one.
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
