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

// Stance AUTHORITY: the cuts and the ledger are the authority's (a copy without authority refuses every cut and drops every
// cook state). A whole food's piece is composed on every machine from its replicated world item; a cut of a piece that
// replicates makes replicated piece scripts whose spawn data (the recipe, the identity, the mass) and root transform
// replicate. A piece whose entity replicates carries FMars_Fragment_FoodPiece_Net, the authority's replicated ledger: its
// identity, its cook state, who holds it and its geometry's check numbers. A copy without authority adopts the identity,
// wears the cook state (OnCookStateChanged) and checks its own geometry against the numbers; only the authority gives a
// piece a body. A machine without the slice rebuilds a cut piece from its recipe (the Replay processors): it imports the
// definition's mesh once, slices each cut of a lineage once through its local replay memo, and shares the result onto the
// replicated entity; the memo and everything it holds are local and read by no simulation. A copy without authority shows
// a piece only while it stands (its local standing, ruled by the Succession processor): a cut piece arrives and stands
// once built, and supersedes every standing piece it was cut from; the authority's pieces always stand.

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
    Failed,
    // Not sliced: this machine has no authority over the piece. Only the authority cuts.
    RefusedNoAuthority
}

// Which side of a cut a piece kept: the plane normal's (Positive) or the other.
enum EMars_FoodPiece_CutSide
{
    Positive,
    Negative
}

// One cut of a piece's lineage: the plane it was cut along, in the definition mesh's frame (every cut of a lineage is in
// that one frame), and the side this piece kept.
struct FMars_FoodPiece_RecipeCut
{
    UPROPERTY()
    FCk_RuntimeMesh_PlaneLocal Plane;

    UPROPERTY()
    EMars_FoodPiece_CutSide Kept = EMars_FoodPiece_CutSide::Positive;

    FMars_FoodPiece_RecipeCut() {}

    FMars_FoodPiece_RecipeCut(FCk_RuntimeMesh_PlaneLocal InPlane, EMars_FoodPiece_CutSide InKept)
    {
        Plane = InPlane;
        Kept = InKept;
    }
}

// How any machine rebuilds a piece: its food definition's wire id and every cut of its lineage, root first. Empty Cuts for
// a whole food; an unset Definition for a piece that never leaves its machine (a bare piece).
struct FMars_FoodPiece_Recipe
{
    UPROPERTY(meta = (Categories = "FoodDef.Mars"))
    FGameplayTag Definition;

    UPROPERTY()
    TArray<FMars_FoodPiece_RecipeCut> Cuts;
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

// A piece's six faces, by their outward normal in the piece's own frame (its bounds box's faces). int32(Face) indexes
// every per-face channel of the cook state.
enum EMars_FoodPiece_Face
{
    PosX,
    NegX,
    PosY,
    NegY,
    PosZ,
    NegZ
}

// How cooked the piece is, as the kernels that cooked it wrote it (each its own channels; nothing clamps one channel into
// another). A display shows it through utils_cookstate::Make_DisplayParams.
struct FMars_FoodPiece_CookState
{
    // A pan's sear per face, 0 raw .. 1 full crust. Six, indexed by int32(EMars_FoodPiece_Face).
    UPROPERTY()
    TArray<float32> Sear;

    // The fryer's batter heat per face, 0 pale .. 1 golden .. 2 overdone. Six, indexed by int32(EMars_FoodPiece_Face).
    UPROPERTY()
    TArray<float32> Batter;

    // The oil a fryer left on the piece when it took it out, 0..1: its sheen at the next station.
    UPROPERTY()
    float32 OilCoat = 0.0f;

    // The crumb coating a tumbler left on the piece when it took it out, 0..1 (its coverage).
    UPROPERTY()
    float32 Crumb = 0.0f;

    // 1 once the batter station handed the piece back fully coated (it admitted it whole, and its food has a battered variant), else 0.
    // A cut half inherits it with the rest of the ledger.
    UPROPERTY()
    float32 Battered = 0.0f;

    FMars_FoodPiece_CookState()
    {
        for (int32 Index = 0; Index < utils_foodpiece::k_FaceCount; ++Index)
        {
            Sear.Add(0.0f);
            Batter.Add(0.0f);
        }
    }
}

// What the piece is. A cut half carries its source's lineage, cook state, definition and kind, and its share of the mass.
struct FMars_FoodPiece_Data
{
    // The piece's identity. Left invalid: Add assigns one. Set only where another machine must name the piece as the
    // authority does (a replicated cut half).
    UPROPERTY()
    FGuid Id;

    // The root joint's identity, shared by every piece cut from it. Left invalid for a new root: Add assigns one.
    UPROPERTY()
    FGuid Lineage;

    // The piece this one was cut from; invalid for a root.
    UPROPERTY()
    FGuid ParentId;

    UPROPERTY()
    float MassKg = 0.0;

    UPROPERTY()
    FMars_FoodPiece_CookState CookState;

    // The food this piece is a portion of; identity for whoever dresses or gates it, never read by the kernel. Unset for a
    // bare piece (tests).
    UPROPERTY()
    TWeakObjectPtr<UMars_Food_Def> Definition;

    // What the food is (Food.Meat.Beef); the gate every station policy reads. Inherited by every half.
    UPROPERTY(meta = (Categories = "Food"))
    FGameplayTagContainer Kind;

    // How the piece is rebuilt on another machine; a cut half carries its source's with that cut appended.
    UPROPERTY()
    FMars_FoodPiece_Recipe Recipe;

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

// The surface of the piece's own convex body (utils_foodpiece::Add_Body). The piece carries it, so every body it is given
// (a platter's drop, a board's loose release, a food item's construction) has the one surface, and a cut half inherits it.
struct FMars_FoodPiece_BodyTuners
{
    UPROPERTY()
    FName CollisionProfileName = n"PhysicsActor";

    UPROPERTY()
    float32 Friction = 0.6f;

    UPROPERTY()
    float32 Restitution = 0.1f;

    FMars_FoodPiece_BodyTuners() {}

    FMars_FoodPiece_BodyTuners(FName InCollisionProfileName, float32 InFriction, float32 InRestitution)
    {
        CollisionProfileName = InCollisionProfileName;
        Friction = InFriction;
        Restitution = InRestitution;
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

    UPROPERTY()
    FMars_FoodPiece_BodyTuners Body;

    FMars_FoodPiece_Spec() {}

    FMars_FoodPiece_Spec(FMars_FoodPiece_Data InData, FMars_FoodPiece_Tuners InTuners, FCk_RuntimeMesh_Cap InCap, FMars_FoodPiece_BodyTuners InBody)
    {
        Data = InData;
        Tuners = InTuners;
        Cap = InCap;
        Body = InBody;
    }
}

// A massless piece has no density to split, a non-positive portion minimum is no minimum RuntimeMesh accepts, a ParentId
// without a Lineage breaks the lineage, a cap outside the slice's ranges would fail every cut, and a body surface Jolt
// would refuse (no collision profile, a negative friction, a restitution outside [0, 1]) would fail every body. The
// RuntimeMesh and Transform the piece needs are checked by Add.
mixin FMars_Validation Validate(const FMars_FoodPiece_Spec& Self)
{
    if (Math::IsFinite(Self.Data.MassKg) == false || Self.Data.MassKg <= 0.0)
    { return FMars_Validation(f"FoodPiece has a non-positive or non-finite Data.MassKg [{Self.Data.MassKg}]"); }

    if (Self.Data.ParentId.IsValid() && Self.Data.Lineage.IsValid() == false)
    { return FMars_Validation("FoodPiece has a Data.ParentId but no Data.Lineage: a cut piece belongs to its root's lineage"); }

    if (Self.Data.Definition.IsValid() && Self.Data.Kind.IsEmpty())
    { return FMars_Validation("FoodPiece has a Data.Definition but no Data.Kind: a piece nobody can gate is a defect"); }

    if (Self.Data.Recipe.Cuts.Num() > 0 && Self.Data.Recipe.Definition.IsValid() == false)
    { return FMars_Validation("FoodPiece has Data.Recipe.Cuts but no Data.Recipe.Definition: no machine could rebuild it"); }

    if (Self.Data.Recipe.Cuts.Num() > 0 && Self.Data.ParentId.IsValid() == false)
    { return FMars_Validation("FoodPiece has Data.Recipe.Cuts but no Data.ParentId: a cut piece names the piece it was cut from"); }

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

    if (Self.Body.CollisionProfileName.IsNone())
    { return FMars_Validation("FoodPiece has no Body.CollisionProfileName"); }

    if (Math::IsFinite(Self.Body.Friction) == false || Self.Body.Friction < 0.0f)
    { return FMars_Validation(f"FoodPiece has a negative or non-finite Body.Friction [{Self.Body.Friction}]"); }

    if (Math::IsFinite(Self.Body.Restitution) == false || Self.Body.Restitution < 0.0f || Self.Body.Restitution > 1.0f)
    { return FMars_Validation(f"FoodPiece has Body.Restitution [{Self.Body.Restitution}] outside [0, 1]"); }

    return FMars_Validation();
}

struct FMars_Tag_FoodPiece_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// Read at every cut and handed on to both halves; Body by every utils_foodpiece::Add_Body.
struct FMars_Fragment_FoodPiece_Params
{
    UPROPERTY()
    FMars_FoodPiece_Tuners Tuners;

    UPROPERTY()
    FCk_RuntimeMesh_Cap Cap;

    UPROPERTY()
    FMars_FoodPiece_BodyTuners Body;

    UPROPERTY()
    FMars_FoodPiece_Recipe Recipe;
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
    FMars_FoodPiece_CookState CookState;

    // Identity, never read by the kernel; unset for a bare piece.
    UPROPERTY()
    TWeakObjectPtr<UMars_Food_Def> Definition;

    // The gate station policies read.
    UPROPERTY(meta = (Categories = "Food"))
    FGameplayTagContainer Kind;

    UPROPERTY()
    EMars_FoodPiece_Status Status = EMars_FoodPiece_Status::Pending;

    // The operation of the slice in flight.
    UPROPERTY()
    TOptional<FGuid> PendingCut;
}

// One slice in flight: the operation RuntimeMesh answers with, the piece it cuts and the plane it was submitted with (the
// plane a replicated half's recipe records).
struct FMars_FoodPiece_CutInFlight
{
    UPROPERTY()
    FGuid OperationID;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    UPROPERTY()
    FCk_RuntimeMesh_PlaneLocal Plane;

    FMars_FoodPiece_CutInFlight() {}

    FMars_FoodPiece_CutInFlight(FGuid InOperationID, FCk_Handle_FoodPiece InPiece, FCk_RuntimeMesh_PlaneLocal InPlane)
    {
        OperationID = InOperationID;
        Piece = InPiece;
        Plane = InPlane;
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
// Replicated pieces
//--------------------------------------------------------------------------------------------------------------------------

// A cut whose source replicates makes its halves as replicated piece scripts (UMars_FoodPiece_EntityScript). Their spawn
// data is the recipe, the identity and the mass; the authority shares the slice's geometry onto each, a client rebuilds it
// from the recipe (FMars_Fragment_FoodPiece_Replay). The cut commits once both halves are composed: the source waits with FMars_Fragment_FoodPiece_PendingCommit, and
// the second half to compose broadcasts the cut (utils_foodpiece::Add_Born).

// What a piece script is born from on the authority.
struct FMars_FoodPiece_Birth
{
    // A Ready geometry on a local entity (a slice result); destroyed once shared onto the piece.
    UPROPERTY()
    FCk_Handle_RuntimeMesh Geometry;

    UPROPERTY()
    FMars_FoodPiece_Spec Spec;

    UPROPERTY()
    FTransform World;

    // The piece whose cut this is, and the other half of that cut. Invalid for a piece spawned outside a cut.
    UPROPERTY()
    FCk_Handle_FoodPiece Source;

    UPROPERTY()
    FCk_Handle Sibling;
}

// On a piece script's entity under construction, the authority's only: removed when the piece composes.
struct FMars_Fragment_FoodPiece_Birth
{
    UPROPERTY()
    FMars_FoodPiece_Birth Birth;

    FMars_Fragment_FoodPiece_Birth() {}

    FMars_Fragment_FoodPiece_Birth(FMars_FoodPiece_Birth InBirth)
    {
        Birth = InBirth;
    }
}

// On a source whose halves are composing: the two halves as it spawned them and the slice's outcome, for the broadcast.
// While it is there the source stays Cutting.
struct FMars_Fragment_FoodPiece_PendingCommit
{
    UPROPERTY()
    FCk_Handle Positive;

    UPROPERTY()
    FCk_Handle Negative;

    UPROPERTY()
    ECk_RuntimeMesh_SliceOutcome SliceOutcome = ECk_RuntimeMesh_SliceOutcome::Succeeded;

    FMars_Fragment_FoodPiece_PendingCommit() {}

    FMars_Fragment_FoodPiece_PendingCommit(FCk_Handle InPositive, FCk_Handle InNegative, ECk_RuntimeMesh_SliceOutcome InSliceOutcome)
    {
        Positive = InPositive;
        Negative = InNegative;
        SliceOutcome = InSliceOutcome;
    }
}

// What a piece script is spawned with; injection matches UMars_FoodPiece_EntityScript's properties by name.
struct FMars_FoodPiece_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform;

    UPROPERTY(meta = (Categories = "FoodDef.Mars"))
    FGameplayTag Definition;

    UPROPERTY()
    TArray<FMars_FoodPiece_RecipeCut> Cuts;

    UPROPERTY()
    FGuid Id;

    UPROPERTY()
    FGuid ParentId;

    UPROPERTY()
    FGuid Lineage;

    UPROPERTY()
    float MassKg = 0.0;
}

// What a machine without the slice keeps of a piece: the spec the recipe and the definition give, and the mesh the recipe
// replays on.
struct FMars_FoodPiece_ReplaySpec
{
    UPROPERTY()
    FMars_FoodPiece_Spec Piece;

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;
}

enum EMars_FoodPiece_ReplayState
{
    // The recipe is still being walked: an import or a slice it needs has not resolved.
    Waiting,
    // The recipe's geometry is shared onto the entity.
    Built,
    // The recipe cannot be rebuilt here (FMars_FoodPiece_ReplayResult::Failure says why); the entity stays a non-piece.
    Failed
}

enum EMars_FoodPiece_ReplayFailure
{
    None,
    // The definition's mesh did not import on this machine.
    ImportFailed,
    // RuntimeMesh refused a slice the recipe needs (FMars_FoodPiece_ReplayResult::SliceOutcome).
    SliceRejected,
    // The recipe cuts a piece along a plane other than the one this machine already split it along.
    PlaneMismatch
}

// How a machine without the slice fared rebuilding one entity's recipe.
struct FMars_FoodPiece_ReplayResult
{
    UPROPERTY()
    EMars_FoodPiece_ReplayState State = EMars_FoodPiece_ReplayState::Waiting;

    UPROPERTY()
    EMars_FoodPiece_ReplayFailure Failure = EMars_FoodPiece_ReplayFailure::None;

    // Set only for SliceRejected.
    UPROPERTY()
    TOptional<ECk_RuntimeMesh_SliceOutcome> SliceOutcome;
}

// On the entity of a piece script that a machine without the slice rebuilds; written by Request_Replay (the spec) and the
// Replay processor (the result).
struct FMars_Fragment_FoodPiece_Replay
{
    UPROPERTY()
    FMars_FoodPiece_ReplaySpec Spec;

    UPROPERTY()
    EMars_FoodPiece_ReplayState State = EMars_FoodPiece_ReplayState::Waiting;

    UPROPERTY()
    EMars_FoodPiece_ReplayFailure Failure = EMars_FoodPiece_ReplayFailure::None;

    UPROPERTY()
    TOptional<ECk_RuntimeMesh_SliceOutcome> SliceOutcome;
}

// While the entity's replay is Waiting.
struct FMars_Tag_FoodPiece_AwaitsReplay {}

// On the one local entity whose lifetime keeps the replay memo swept (UMars_Processor_FoodPiece_ReplayKeeper).
struct FMars_Tag_FoodPiece_ReplayKeeper {}

// One definition's mesh imported on this machine, on a local entity: the root of every lineage of that definition.
struct FMars_FoodPiece_ReplayImport
{
    UPROPERTY(meta = (Categories = "FoodDef.Mars"))
    FGameplayTag Definition;

    UPROPERTY()
    FCk_Handle_RuntimeMesh Geometry;
}

enum EMars_FoodPiece_ReplayNodeState
{
    // Not cut on this machine yet.
    Leaf,
    // Its slice is submitted and unresolved.
    InFlight,
    // Cut along SplitPlane into Positive and Negative.
    Split,
    // Its slice was refused (Rejection).
    Rejected
}

// One geometry of a lineage as this machine rebuilt it. A node's key is its path from the root: the plane and side of
// every cut on the way; a piece is cut once, so a node has at most one split plane.
struct FMars_FoodPiece_ReplayNode
{
    UPROPERTY()
    FCk_Handle_RuntimeMesh Geometry;

    // The entity this node's geometry was shared onto; invalid until one was.
    UPROPERTY()
    FCk_Handle Piece;

    UPROPERTY()
    EMars_FoodPiece_ReplayNodeState State = EMars_FoodPiece_ReplayNodeState::Leaf;

    // Meaningful from InFlight on.
    UPROPERTY()
    FCk_RuntimeMesh_PlaneLocal SplitPlane;

    // Node indices of the two sides, once Split.
    UPROPERTY()
    int32 Positive = -1;

    UPROPERTY()
    int32 Negative = -1;

    UPROPERTY()
    ECk_RuntimeMesh_SliceOutcome Rejection = ECk_RuntimeMesh_SliceOutcome::Succeeded;
}

// Every geometry this machine rebuilt of one lineage; node 0 is the root, whose geometry is the definition's import.
struct FMars_FoodPiece_ReplayLineage
{
    UPROPERTY()
    FGuid Lineage;

    UPROPERTY(meta = (Categories = "FoodDef.Mars"))
    FGameplayTag Definition;

    UPROPERTY()
    TArray<FMars_FoodPiece_ReplayNode> Nodes;

    // How long the lineage has had no slice in flight and no live piece.
    UPROPERTY()
    float32 OrphanSeconds = 0.0f;
}

// One replay slice in flight: the operation RuntimeMesh answers with and the node it cuts.
struct FMars_FoodPiece_ReplayFlight
{
    UPROPERTY()
    FGuid OperationID;

    UPROPERTY()
    FGuid Lineage;

    UPROPERTY()
    int32 Node = -1;
}

struct FMars_FoodPiece_ReplayCounts
{
    UPROPERTY()
    int32 Slices = 0;

    UPROPERTY()
    int32 Built = 0;

    UPROPERTY()
    int32 Failed = 0;
}

// On the world's transient entity (the replay processors' own handle, which also owns every import, replay geometry and
// the keeper): every lineage this machine rebuilds, so a cut shared by several pieces is sliced once and a piece that
// arrives after its own halves still finds its geometry. Local to the machine, never replicated. Written only by the
// Replay and ReplayKeeper processors.
struct FMars_Fragment_FoodPiece_ReplayMemo
{
    UPROPERTY()
    TArray<FMars_FoodPiece_ReplayImport> Imports;

    UPROPERTY()
    TArray<FMars_FoodPiece_ReplayLineage> Lineages;

    UPROPERTY()
    TArray<FMars_FoodPiece_ReplayFlight> Flights;

    UPROPERTY()
    FMars_FoodPiece_ReplayCounts Tally;

    UPROPERTY()
    FCk_Handle Keeper;
}

// What utils_foodpiece::Get_ReplayTally reads of a world's replay memo: the slices submitted, the entities built and
// failed, and the lineages and live geometry entities (imports included) the memo holds now.
struct FMars_FoodPiece_ReplayTally
{
    UPROPERTY()
    int32 Slices = 0;

    UPROPERTY()
    int32 Built = 0;

    UPROPERTY()
    int32 Failed = 0;

    UPROPERTY()
    int32 Lineages = 0;

    UPROPERTY()
    int32 Geometries = 0;
}

// Once per replayed entity, when its replay resolves Built or Failed.
delegate void FMars_Delegate_FoodPiece_OnReplayResolved(FCk_Handle InEntity, EMars_FoodPiece_ReplayState InState);
event void FMars_Delegate_FoodPiece_OnReplayResolved_MC(FCk_Handle InEntity, EMars_FoodPiece_ReplayState InState);

struct FMars_Fragment_FoodPiece_ReplaySignals
{
    FMars_Delegate_FoodPiece_OnReplayResolved_MC OnReplayResolved;
}

// The one ledger holding the piece (a platter, a board, a pan, a fryer): the fact every "another ledger holds it" check
// reads. A ledger's processor stamps it when that ledger admits the piece and removes it when the ledger lets the piece go
// (utils_foodpiece::Stamp_Holder, Clear_Holder); each ledger keeps its own record of the piece besides. Absent while no
// ledger holds the piece (in a hand, in flight between two ledgers, lying loose).
struct FMars_Fragment_FoodPiece_Holder
{
    UPROPERTY()
    FCk_Handle Owner;
}

//--------------------------------------------------------------------------------------------------------------------------
// Replicated ledger
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_FoodPiece_Holding
{
    Free,
    Held
}

enum EMars_FoodPiece_Check
{
    // The authority has not recorded its geometry's numbers yet (its import has not resolved).
    NotRecorded,
    Recorded
}

// How a copy without authority compares its own geometry with the authority's numbers.
enum EMars_FoodPiece_CheckResult
{
    Unchecked,
    Matches,
    Differs
}

// Stance REPLICATED, authority-written: on every piece whose entity replicates (utils_foodpiece::DoGet_HasLedger), written only
// by the authority through utils_foodpiece's ledger writers (from Add, the FoodPiece processors and the holder helpers),
// each write followed by its dirty mark. A copy without authority reads it and never writes it.
struct FMars_Fragment_FoodPiece_Net
{
    UPROPERTY()
    FGuid Id;

    UPROPERTY()
    FGuid ParentId;

    UPROPERTY()
    FGuid Lineage;

    UPROPERTY()
    FMars_FoodPiece_CookState CookState;

    // 0 exactly while the piece has never been cooked; one more for every drain that set its cook state.
    UPROPERTY()
    int32 CookSerial = 0;

    UPROPERTY()
    EMars_FoodPiece_Holding Holding = EMars_FoodPiece_Holding::Free;

    // The ledger holding the piece, meaningful only while Holding is Held (TryGet_ReplicatedHolder): a cleared handle keeps
    // its old value on a client.
    UPROPERTY()
    FCk_Handle Holder;

    UPROPERTY()
    EMars_FoodPiece_Check Check = EMars_FoodPiece_Check::NotRecorded;

    // The authority's Ready geometry, meaningful once Check is Recorded.
    UPROPERTY()
    float CheckVolumeCm3 = 0.0;

    UPROPERTY()
    int32 CheckTriangles = 0;

    UPROPERTY()
    FVector CheckBoundsMinCm = FVector::ZeroVector;

    UPROPERTY()
    FVector CheckBoundsMaxCm = FVector::ZeroVector;
}

// Whether a copy without authority shows the piece. A cut piece arrives before it stands; a piece stands until one cut
// from it stands, and is then superseded for good. A piece with authority always stands.
enum EMars_FoodPiece_Standing
{
    Arriving,
    Current,
    Superseded
}

// Beside the ledger, this machine's own: the cook serial it last wore, how its geometry compared and whether it stands.
struct FMars_Fragment_FoodPiece_Local
{
    UPROPERTY()
    int32 LastCookSerial = 0;

    UPROPERTY()
    EMars_FoodPiece_CheckResult CheckResult = EMars_FoodPiece_CheckResult::Unchecked;

    UPROPERTY()
    EMars_FoodPiece_Standing Standing = EMars_FoodPiece_Standing::Current;
}

struct FMars_Tag_FoodPiece_NeedsMirror {}

// On a copy without authority whose lineage is known: the Succession processor rules on its standing.
struct FMars_Tag_FoodPiece_NeedsSuccession {}

// On the Succession processor's handle (the world's transient entity): every piece of this machine it has ruled on and that
// is not gone. Local, read by no simulation.
struct FMars_Fragment_FoodPiece_Kin
{
    UPROPERTY()
    TArray<FCk_Handle_FoodPiece> Pieces;
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

// On a copy without authority, each time the replicated ledger brings a cook state it had not worn. Never raised on the
// authority: whoever writes a cook state there writes its look.
delegate void FMars_Delegate_FoodPiece_OnCookStateChanged(FCk_Handle_FoodPiece InPiece);
event void FMars_Delegate_FoodPiece_OnCookStateChanged_MC(FCk_Handle_FoodPiece InPiece);

// On a copy without authority, each time the piece's standing changes (the standing is written first). Never raised on the
// authority.
delegate void FMars_Delegate_FoodPiece_OnStandingChanged(FCk_Handle_FoodPiece InPiece, EMars_FoodPiece_Standing InStanding);
event void FMars_Delegate_FoodPiece_OnStandingChanged_MC(FCk_Handle_FoodPiece InPiece, EMars_FoodPiece_Standing InStanding);

struct FMars_Fragment_FoodPiece_Signals
{
    FMars_Delegate_FoodPiece_OnReady_MC OnReady;
    FMars_Delegate_FoodPiece_OnFailed_MC OnFailed;
    FMars_Delegate_FoodPiece_OnCutResolved_MC OnCutResolved;
    FMars_Delegate_FoodPiece_OnCookStateChanged_MC OnCookStateChanged;
    FMars_Delegate_FoodPiece_OnStandingChanged_MC OnStandingChanged;
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

// Replace the piece's cook state (a heat kernel's write-back when the piece leaves it). Applied before any cut in the same
// drain, so the halves of that cut carry it; one sent while the piece is Cutting reaches the halves too (the commit takes
// the last write still queued on the source).
struct FMars_Request_FoodPiece_SetCookState
{
    UPROPERTY()
    FMars_FoodPiece_CookState CookState;

    FMars_Request_FoodPiece_SetCookState() {}

    FMars_Request_FoodPiece_SetCookState(FMars_FoodPiece_CookState InCookState)
    {
        CookState = InCookState;
    }
}

// Applied SetCookState -> Cut: the last cook state set wins and reaches the halves of a cut in the same drain; cuts then
// as before, in order: the first cut a Ready piece takes in a drain is submitted and every later one is RefusedBusy,
// unless RuntimeMesh rejects that submission on the spot (its queue is full): the piece is Ready again and the next one
// submits.
struct FMars_Fragment_FoodPiece_Requests
{
    UPROPERTY()
    TArray<FMars_Request_FoodPiece_SetCookState> SetCookStateRequests;

    UPROPERTY()
    TArray<FMars_Request_FoodPiece_Cut> CutRequests;
}
