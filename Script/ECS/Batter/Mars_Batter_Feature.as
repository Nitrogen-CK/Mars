//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_BatterHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Batter";
    RequiredFragments.Add(FMars_Feature_Batter);
    Description = "A batter bowl on a station: the whole, batterable, unbattered food pieces the station admits sit in slots in the bowl; while the operator holds the bowl dipped each piece sinks under the batter and its coat clock runs, and a take-out hands every fully coated piece back battered onto a tray";
}
struct FMars_Feature_Batter {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// Resting: the pieces sit at their slots above the batter. Dipped: the operator holds them under it; their coat clocks run.
enum EMars_Batter_Bowl
{
    Resting,
    Dipped
}

// A piece's coat, quantized: Bare (0), Coating (on its way), Coated (1, takeable).
enum EMars_Batter_CoatStage
{
    Bare,
    Coating,
    Coated
}

// Why a release from the station's inbox was not admitted. Unavailable: no piece, not Ready, held by another ledger or still
// attached. Duplicate: the piece or its Id is already in the bowl. NotWhole: a cut piece (the bowl takes full ingredients
// only). NotBatterable: its food has no battered variant (or it is a bare piece with no food). AlreadyBattered: its ledger
// is battered already. Full: Bowl.Capacity pieces are in.
enum EMars_Batter_AdmissionRefusal
{
    Unavailable,
    Duplicate,
    NotWhole,
    NotBatterable,
    AlreadyBattered,
    Full
}

// Why a take-out handed nothing back. NoRoom: capped at zero pieces (no tray, or a full one). Empty: nothing in the bowl.
// StillInTheBatter: a piece is fully coated but not lifted back to rest yet. CoatIncomplete: pieces are in, none is fully
// coated yet.
enum EMars_Batter_TakeOutRefusal
{
    NoRoom,
    Empty,
    StillInTheBatter,
    CoatIncomplete
}

// Why the add-food press would not load a piece now. Full: Bowl.Capacity pieces are in. TransferInFlight: the station's
// feed is mid-transfer.
enum EMars_Batter_LoadRefusal
{
    Full,
    TransferInFlight
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The bowl's slots in the bowl node's frame (Z up): Capacity slots evenly round a ring of SlotRadius (one slot = the
// middle), each piece's bounds centre RestZ above the node at rest and DipDepthCm lower when fully dipped.
struct FMars_Batter_BowlSpec
{
    UPROPERTY()
    int32 Capacity = 3;

    UPROPERTY()
    float32 SlotRadius = 10.0f;

    UPROPERTY()
    float32 RestZ = 14.0f;

    UPROPERTY()
    float32 DipDepthCm = 9.0f;

    FMars_Batter_BowlSpec() {}

    FMars_Batter_BowlSpec(int32 InCapacity, float32 InSlotRadius, float32 InRestZ, float32 InDipDepthCm)
    {
        Capacity = InCapacity;
        SlotRadius = InSlotRadius;
        RestZ = InRestZ;
        DipDepthCm = InDipDepthCm;
    }
}

// A piece sinks from rest to fully dipped (and rises back) over DipSeconds (0 = at once); its coat grows from 0 to 1 over
// CoatSeconds of being fully under, and only then.
struct FMars_Batter_CoatSpec
{
    UPROPERTY()
    float32 CoatSeconds = 2.5f;

    UPROPERTY()
    float32 DipSeconds = 0.35f;

    FMars_Batter_CoatSpec() {}

    FMars_Batter_CoatSpec(float32 InCoatSeconds, float32 InDipSeconds)
    {
        CoatSeconds = InCoatSeconds;
        DipSeconds = InDipSeconds;
    }
}

// Built by the placing script before Add. Bowl is a node under the station (Z up, its origin the bowl's slot plane centre):
// the kernel attaches every piece it admits under it and writes the piece's offset.
struct FMars_Batter_Nodes
{
    UPROPERTY()
    FCk_Handle_Transform Bowl;

    FMars_Batter_Nodes() {}

    FMars_Batter_Nodes(FCk_Handle_Transform InBowl)
    {
        Bowl = InBowl;
    }
}

struct FMars_Batter_Spec
{
    UPROPERTY()
    FMars_Batter_BowlSpec Bowl;

    UPROPERTY()
    FMars_Batter_CoatSpec Coat;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Batter_Nodes Nodes;
}

// A bowl with no room, a ring with a negative radius, a non-finite rest height, a dip that does not sink, a coat that never
// grows or a negative dip time each make the station unplayable.
mixin FMars_Validation Validate(const FMars_Batter_Spec& Self)
{
    const auto& Bowl = Self.Bowl;
    if (Bowl.Capacity <= 0)
    { return FMars_Validation(f"Batter has a non-positive Bowl.Capacity [{Bowl.Capacity}]"); }

    if (Bowl.SlotRadius < 0.0f)
    { return FMars_Validation(f"Batter has a negative Bowl.SlotRadius [{Bowl.SlotRadius}]"); }

    if (Math::IsFinite(Bowl.RestZ) == false)
    { return FMars_Validation(f"Batter has a non-finite Bowl.RestZ [{Bowl.RestZ}]"); }

    if (Bowl.DipDepthCm <= 0.0f)
    { return FMars_Validation(f"Batter has a non-positive Bowl.DipDepthCm [{Bowl.DipDepthCm}]"); }

    if (Self.Coat.CoatSeconds <= 0.0f)
    { return FMars_Validation(f"Batter has a non-positive Coat.CoatSeconds [{Self.Coat.CoatSeconds}]"); }

    if (Self.Coat.DipSeconds < 0.0f)
    { return FMars_Validation(f"Batter has a negative Coat.DipSeconds [{Self.Coat.DipSeconds}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Batter_Params
{
    UPROPERTY()
    FMars_Batter_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// One admitted piece, keyed by the feed identity it arrived with (an array index is never identity). The piece is the bowl's
// guest: its own entity, attached under the bowl node at its slot (its body, if it has one, Kinematic); the kernel poses it.
struct FMars_Batter_PieceState
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    UPROPERTY()
    FCk_Handle Entity;

    // Its slot in the bowl, 0 .. Bowl.Capacity - 1.
    UPROPERTY()
    int32 Slot = 0;

    // 0 at rest .. 1 fully under the batter.
    UPROPERTY()
    float32 Immersion = 0.0f;

    // 0..1, never decreases while the piece is in the bowl.
    UPROPERTY()
    float32 Coat = 0.0f;

    // The stage OnCoatStage last reported.
    UPROPERTY()
    EMars_Batter_CoatStage Stage = EMars_Batter_CoatStage::Bare;
}

// Written only by the two Batter processors (and Add). The station SM, the feed bridge and the operator only issue requests.
struct FMars_Fragment_Batter
{
    UPROPERTY()
    EMars_Batter_Bowl Bowl = EMars_Batter_Bowl::Resting;

    // In admission order.
    UPROPERTY()
    TArray<FMars_Batter_PieceState> Pieces;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Batter_OnBowlChanged(FCk_Handle_Batter InBatter, EMars_Batter_Bowl InBowl);
event void FMars_Delegate_Batter_OnBowlChanged_MC(FCk_Handle_Batter InBatter, EMars_Batter_Bowl InBowl);

// A piece is in the bowl: one the station's inbox brought (right after the station's OnAdmission answered Accepted), or one
// readopted after its tray refused it. The placing script keeps its record here.
delegate void FMars_Delegate_Batter_OnPieceAdded(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);
event void FMars_Delegate_Batter_OnPieceAdded_MC(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);

// A release the bowl would not take (right after the station's OnAdmission answered Rejected), and why.
delegate void FMars_Delegate_Batter_OnAdmissionRefused(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_AdmissionRefusal InRefusal);
event void FMars_Delegate_Batter_OnAdmissionRefused_MC(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_AdmissionRefusal InRefusal);

// A piece's coat crossed into a new stage (once per crossing). Only tests bind it today: the kernel's test-pinned
// contract, kept for the assembly to bind.
delegate void FMars_Delegate_Batter_OnCoatStage(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_CoatStage InStage);
event void FMars_Delegate_Batter_OnCoatStage_MC(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_CoatStage InStage);

// A take-out handed the piece back (its ledger battered, detached), on its way onto the take-out's tray.
delegate void FMars_Delegate_Batter_OnPieceTakenOut(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_Batter_OnPieceTakenOut_MC(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece);

// A take-out that handed nothing back, and why.
delegate void FMars_Delegate_Batter_OnTakeOutRefused(FCk_Handle_Batter InBatter, EMars_Batter_TakeOutRefusal InRefusal);
event void FMars_Delegate_Batter_OnTakeOutRefused_MC(FCk_Handle_Batter InBatter, EMars_Batter_TakeOutRefusal InRefusal);

struct FMars_Fragment_Batter_Signals
{
    FMars_Delegate_Batter_OnBowlChanged_MC OnBowlChanged;
    FMars_Delegate_Batter_OnPieceAdded_MC OnPieceAdded;
    FMars_Delegate_Batter_OnAdmissionRefused_MC OnAdmissionRefused;
    FMars_Delegate_Batter_OnCoatStage_MC OnCoatStage;
    FMars_Delegate_Batter_OnPieceTakenOut_MC OnPieceTakenOut;
    FMars_Delegate_Batter_OnTakeOutRefused_MC OnTakeOutRefused;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Debug and tests only: destroys every piece in the bowl and lifts it. Payload-less: one placeholder field (request
// doctrine).
struct FMars_Request_Batter_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Batter_Reset() {}
}

// The operator holds the bowl's pieces under the batter (the dip button going down). Payload-less: one placeholder field
// (request doctrine).
struct FMars_Request_Batter_Dip
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Batter_Dip() {}
}

// The pieces come back up (the dip button coming up, or the operator leaving). Pieces and coats are untouched.
// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Batter_Lift
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Batter_Lift() {}
}

// A piece a take-out handed back that its tray refused: back in the bowl at a free slot, fully coated, with OnPieceAdded
// again after the drain's take-outs (the kernel's own landing watch sends it). Not readopted: a piece gone, or that another
// ledger holds by now, is left alone; one attached somewhere stays there, and one with no free slot left (a release was
// admitted into the slot its take-out freed) ensures and lies where it is; both with their pickup's Ledger claim
// released. A piece or PieceId already in the bowl ensures.
struct FMars_Request_Batter_Readopt
{
    UPROPERTY()
    FMars_CookingFeed_PieceId PieceId;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    FMars_Request_Batter_Readopt() {}

    FMars_Request_Batter_Readopt(FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        PieceId = InPieceId;
        Piece = InPiece;
    }
}

// Applied Reset -> Lift -> the station's take-outs -> Readopt -> the station inbox's releases -> Dip: a release and a press
// sharing a drain end the old dip before the new one, and a take-out frees its slots before a release is admitted.
struct FMars_Fragment_Batter_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Batter_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Batter_Lift> LiftRequests;

    UPROPERTY()
    TArray<FMars_Request_Batter_Readopt> ReadoptRequests;

    UPROPERTY()
    TArray<FMars_Request_Batter_Dip> DipRequests;
}
