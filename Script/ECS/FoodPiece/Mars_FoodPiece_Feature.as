//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_FoodPieceHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_FoodPiece";
    RequiredFragments.Add(FMars_Feature_FoodPiece);
    Description = "One cuttable piece of food: a RuntimeMesh solid with an identity, a lineage, a mass and a cook state; a plane cut replaces it with two pieces that split its mass by volume";
}
struct FMars_Feature_FoodPiece {}

//--------------------------------------------------------------------------------------------------------------------------
// Vocabulary
//--------------------------------------------------------------------------------------------------------------------------

// Pending until the geometry imports. Cutting from a submitted slice until it resolves.
enum EMars_FoodPiece_Status
{
    Pending,
    Ready,
    Cutting,
    Failed
}

enum EMars_FoodPiece_CutOutcome
{
    // The piece was replaced by its two halves.
    Cut,
    // The plane does not pass through the piece (no intersection, or it only touches a face).
    Missed,
    // RuntimeMesh refused the slice (a half too small or thin, limits, topology, a full queue).
    Rejected,
    // Not sliced: the piece is not Ready.
    RefusedNotReady,
    // Not sliced: another cut of this piece is in flight.
    RefusedBusy,
    Cancelled,
    Failed
}

// What OnCutResolved reports. The halves are valid only for Cut.
struct FMars_FoodPiece_CutResult
{
    UPROPERTY()
    EMars_FoodPiece_CutOutcome Outcome = EMars_FoodPiece_CutOutcome::Failed;

    // Unset when the piece refused the cut without slicing.
    UPROPERTY()
    TOptional<ECk_RuntimeMesh_SliceOutcome> SliceOutcome;

    UPROPERTY()
    FCk_Handle_FoodPiece Positive;

    UPROPERTY()
    FCk_Handle_FoodPiece Negative;

    FMars_FoodPiece_CutResult() {}

    FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome InOutcome)
    {
        Outcome = InOutcome;
    }

    FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome InOutcome, ECk_RuntimeMesh_SliceOutcome InSliceOutcome)
    {
        Outcome = InOutcome;
        SliceOutcome = TOptional<ECk_RuntimeMesh_SliceOutcome>(InSliceOutcome);
    }
}

// A cutting plane in world space. Tangent orients the cut face's UVs.
struct FMars_FoodPiece_WorldPlane
{
    UPROPERTY()
    FVector PositionCm = FVector::ZeroVector;

    UPROPERTY()
    FVector Normal = FVector::UpVector;

    UPROPERTY()
    FVector Tangent = FVector::ForwardVector;

    FMars_FoodPiece_WorldPlane() {}

    FMars_FoodPiece_WorldPlane(FVector InPositionCm, FVector InNormal, FVector InTangent)
    {
        PositionCm = InPositionCm;
        Normal = InNormal;
        Tangent = InTangent;
    }
}

// A cut's mass, per half (positive = the plane normal's side).
struct FMars_FoodPiece_MassSplit
{
    float PositiveKg = 0.0;
    float NegativeKg = 0.0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// What the piece is. A cut half carries its source's lineage and cook state and its share of the mass.
struct FMars_FoodPiece_Data
{
    // The root joint's identity, shared by every piece cut from it. Left invalid for a new root: Add assigns one.
    UPROPERTY()
    FGuid Lineage;

    // The piece this one was cut from; invalid for a root.
    UPROPERTY()
    FGuid ParentId;

    UPROPERTY()
    float MassKg = 0.0;

    UPROPERTY()
    FMars_CookState CookState;

    FMars_FoodPiece_Data() {}

    FMars_FoodPiece_Data(float InMassKg)
    {
        MassKg = InMassKg;
    }
}

// The smallest portion a cut may leave: neither half lighter than MinPortionMassKg nor thinner than MinPortionThicknessCm
// along the cut normal. A cut that would is Rejected and the piece stays whole.
struct FMars_FoodPiece_Tuners
{
    UPROPERTY()
    float MinPortionMassKg = 0.005;

    UPROPERTY()
    float MinPortionThicknessCm = 0.5;

    FMars_FoodPiece_Tuners() {}

    FMars_FoodPiece_Tuners(float InMinPortionMassKg, float InMinPortionThicknessCm)
    {
        MinPortionMassKg = InMinPortionMassKg;
        MinPortionThicknessCm = InMinPortionThicknessCm;
    }
}

struct FMars_FoodPiece_Spec
{
    UPROPERTY()
    FMars_FoodPiece_Data Data;

    UPROPERTY()
    FMars_FoodPiece_Tuners Tuners;

    // The face every cut of this piece and its halves gets: the cap material slot, colour and UV scale the assembly chose.
    UPROPERTY()
    FCk_RuntimeMesh_Cap Cap;

    FMars_FoodPiece_Spec() {}

    FMars_FoodPiece_Spec(FMars_FoodPiece_Data InData, FMars_FoodPiece_Tuners InTuners, FCk_RuntimeMesh_Cap InCap)
    {
        Data = InData;
        Tuners = InTuners;
        Cap = InCap;
    }
}

// A massless piece has no density to split, a non-positive portion minimum is no minimum RuntimeMesh accepts, a ParentId
// without a Lineage breaks the lineage, and a cap outside the slice's ranges would fail every cut. The RuntimeMesh and
// Transform the piece needs are checked by Add.
mixin FMars_Validation Validate(const FMars_FoodPiece_Spec& Self)
{
    if (Math::IsFinite(Self.Data.MassKg) == false || Self.Data.MassKg <= 0.0)
    { return FMars_Validation(f"FoodPiece has a non-positive or non-finite Data.MassKg [{Self.Data.MassKg}]"); }

    if (Self.Data.ParentId.IsValid() && Self.Data.Lineage.IsValid() == false)
    { return FMars_Validation("FoodPiece has a Data.ParentId but no Data.Lineage: a cut piece belongs to its root's lineage"); }

    if (Math::IsFinite(Self.Tuners.MinPortionMassKg) == false || Self.Tuners.MinPortionMassKg <= 0.0)
    { return FMars_Validation(f"FoodPiece has a non-positive or non-finite Tuners.MinPortionMassKg [{Self.Tuners.MinPortionMassKg}]"); }

    if (Math::IsFinite(Self.Tuners.MinPortionThicknessCm) == false || Self.Tuners.MinPortionThicknessCm <= 0.0
        || Self.Tuners.MinPortionThicknessCm > utils_foodpiece::k_MaxPortionThicknessCm)
    { return FMars_Validation(f"FoodPiece has Tuners.MinPortionThicknessCm [{Self.Tuners.MinPortionThicknessCm}] outside (0, {utils_foodpiece::k_MaxPortionThicknessCm}]"); }

    if (Self.Cap.Get_MaterialID() < 0)
    { return FMars_Validation(f"FoodPiece has a negative Cap.MaterialID [{Self.Cap.Get_MaterialID()}]"); }

    const auto CmPerUVUnit = Self.Cap.Get_CmPerUVUnit();
    if (Math::IsFinite(CmPerUVUnit) == false || CmPerUVUnit < utils_foodpiece::k_MinCapCmPerUVUnit || CmPerUVUnit > utils_foodpiece::k_MaxCapCmPerUVUnit)
    { return FMars_Validation(f"FoodPiece has Cap.CmPerUVUnit [{CmPerUVUnit}] outside [{utils_foodpiece::k_MinCapCmPerUVUnit}, {utils_foodpiece::k_MaxCapCmPerUVUnit}]"); }

    if (utils_foodpiece::Get_IsUnitColor(Self.Cap.Get_Color()) == false)
    { return FMars_Validation(f"FoodPiece has a Cap.Color [{Self.Cap.Get_Color().ToString()}] outside [0, 1]"); }

    const auto UVOffset = Self.Cap.Get_UVOffset();
    if (Math::IsFinite(UVOffset.X) == false || Math::IsFinite(UVOffset.Y) == false
        || Math::Abs(UVOffset.X) > utils_foodpiece::k_MaxCapUVOffset || Math::Abs(UVOffset.Y) > utils_foodpiece::k_MaxCapUVOffset)
    { return FMars_Validation(f"FoodPiece has a Cap.UVOffset [{UVOffset.ToString()}] that is non-finite or beyond {utils_foodpiece::k_MaxCapUVOffset}"); }

    return FMars_Validation();
}

struct FMars_Tag_FoodPiece_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// Read at every cut and handed on to both halves.
struct FMars_Fragment_FoodPiece_Params
{
    UPROPERTY()
    FMars_FoodPiece_Tuners Tuners;

    UPROPERTY()
    FCk_RuntimeMesh_Cap Cap;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the FoodPiece processors (and Add). Status is Cutting exactly while PendingCut is set.
struct FMars_Fragment_FoodPiece
{
    // New for every piece, halves included.
    UPROPERTY()
    FGuid Id;

    UPROPERTY()
    FGuid ParentId;

    UPROPERTY()
    FGuid Lineage;

    UPROPERTY()
    float MassKg = 0.0;

    // The geometry's volume, recorded once it is Ready.
    UPROPERTY()
    float VolumeCm3 = 0.0;

    UPROPERTY()
    FMars_CookState CookState;

    UPROPERTY()
    EMars_FoodPiece_Status Status = EMars_FoodPiece_Status::Pending;

    // The operation of the slice in flight.
    UPROPERTY()
    TOptional<FGuid> PendingCut;
}

// One slice in flight: the operation RuntimeMesh answers with, and the piece it cuts.
struct FMars_FoodPiece_CutInFlight
{
    UPROPERTY()
    FGuid OperationID;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    FMars_FoodPiece_CutInFlight() {}

    FMars_FoodPiece_CutInFlight(FGuid InOperationID, FCk_Handle_FoodPiece InPiece)
    {
        OperationID = InOperationID;
        Piece = InPiece;
    }
}

// On the world's transient entity (the FoodPiece processors' own handle, which also owns every half): a slice result
// carries only its operation, so this is how it finds its piece. An entry lives from submission to resolution. Written
// only by the FoodPiece processors.
struct FMars_Fragment_FoodPiece_PendingCuts
{
    UPROPERTY()
    TArray<FMars_FoodPiece_CutInFlight> Entries;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Once per piece, when its geometry is Ready and its volume recorded. A cut half is Ready from Add and announces in the
// same frame.
delegate void FMars_Delegate_FoodPiece_OnReady(FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_FoodPiece_OnReady_MC(FCk_Handle_FoodPiece InPiece);

// Once per piece whose mesh failed to import.
delegate void FMars_Delegate_FoodPiece_OnFailed(FCk_Handle_FoodPiece InPiece, ECk_RuntimeMesh_SetupFailure InReason);
event void FMars_Delegate_FoodPiece_OnFailed_MC(FCk_Handle_FoodPiece InPiece, ECk_RuntimeMesh_SetupFailure InReason);

// Once per Cut request. On Cut the halves are composed and Ready, and InSource is destroyed right after the broadcast;
// on any other outcome InSource is Ready again (or still not Ready, for RefusedNotReady).
delegate void FMars_Delegate_FoodPiece_OnCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult);
event void FMars_Delegate_FoodPiece_OnCutResolved_MC(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult);

struct FMars_Fragment_FoodPiece_Signals
{
    FMars_Delegate_FoodPiece_OnReady_MC OnReady;
    FMars_Delegate_FoodPiece_OnFailed_MC OnFailed;
    FMars_Delegate_FoodPiece_OnCutResolved_MC OnCutResolved;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Slice the piece along Plane, in the piece's local frame (utils_foodpiece::Get_LocalPlane converts a world plane).
struct FMars_Request_FoodPiece_Cut
{
    UPROPERTY()
    FCk_RuntimeMesh_PlaneLocal Plane;

    FMars_Request_FoodPiece_Cut() {}

    FMars_Request_FoodPiece_Cut(FCk_RuntimeMesh_PlaneLocal InPlane)
    {
        Plane = InPlane;
    }
}

// Applied in order: the first cut a Ready piece takes in a drain is submitted and every later one is RefusedBusy, unless
// RuntimeMesh rejects that submission on the spot (its queue is full): the piece is Ready again and the next one submits.
struct FMars_Fragment_FoodPiece_Requests
{
    UPROPERTY()
    TArray<FMars_Request_FoodPiece_Cut> CutRequests;
}
