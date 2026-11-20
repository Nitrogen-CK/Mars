// Stance SPLIT. A severed limb is one entity per severed leg, spawned once by the authority under the replicated spawn
// owner. Its root does not move; its pieces (each segment, then the foot) are child transform entities. With authority
// each piece is a dynamic Jolt body jointed to the one before it (a hinge at each knee, a point at the ankle) and the
// authority alone writes the replicated pose ledger (FMars_Fragment_SeveredLimb_Net: every piece's pose in the root's
// frame). A copy builds the same pieces with no body and no joint, simulates nothing, and poses them from the ledger:
// taken as it stands the first time, eased to each later write.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_SeveredLimbHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_SeveredLimb";
    RequiredFragments.Add(FMars_Feature_SeveredLimb);
    Description = "A severed leg as one replicated limb: jointed Jolt pieces on the authority, posed from a replicated pose ledger on a copy";
}

struct FMars_Feature_SeveredLimb {}

namespace constants_severed_limb
{
    // The authority's publish cadence, and how long a copy eases a piece to each write (s).
    const float32 k_PublishSeconds = 0.05f;
    // A piece that moved more than this since the last write is published again.
    const float64 k_MoveCm = 0.5;
    const float64 k_MoveDegrees = 0.5;
    // Nothing published for this long: one final write reads at rest, and nothing is published after it.
    const float32 k_RestSeconds = 0.5f;
    // Each knee bends this far either side of the angle it had at the cut.
    const float32 k_KneeLimitDegrees = 60.0f;
    // Jolt units (a centimetre is a unit, mass in kg): a few percent of the gravity torque on a lower segment.
    const float32 k_KneeFrictionTorque = 2000.0f;
    // The limb is born at least this far above the static ground under every piece's body.
    const float64 k_BirthClearanceCm = 0.5;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// One piece: a transform entity the caller built (a lifetime child of the limb) and the half extents it is drawn at,
// +X hip to foot.
struct FMars_SeveredLimb_PieceSpec
{
    UPROPERTY()
    FCk_Handle_Transform Piece;

    UPROPERTY()
    FVector HalfExtents = FVector::ZeroVector;

    FMars_SeveredLimb_PieceSpec() {}

    FMars_SeveredLimb_PieceSpec(FCk_Handle_Transform InPiece, FVector InHalfExtents)
    {
        Piece = InPiece;
        HalfExtents = InHalfExtents;
    }
}

struct FMars_SeveredLimb_Spec
{
    // In chain order: the hip end first, the foot last.
    UPROPERTY()
    TArray<FMars_SeveredLimb_PieceSpec> Pieces;

    UPROPERTY()
    FMars_BodyPart_Debris Debris;

    // The first piece's launch, cm/s: the limb is thrown by its hip end.
    UPROPERTY()
    FVector LaunchVelocity = FVector::ZeroVector;
}

mixin FMars_Validation Validate(const FMars_SeveredLimb_Spec& Self)
{
    if (Self.Pieces.Num() < 2)
    { return FMars_Validation(f"SeveredLimb has [{Self.Pieces.Num()}] pieces: a limb is two or more"); }

    for (int32 Index = 0; Index < Self.Pieces.Num(); ++Index)
    {
        const auto& Piece = Self.Pieces[Index];
        if (ck::Is_NOT_Valid(Piece.Piece))
        { return FMars_Validation(f"SeveredLimb piece [{Index}] is invalid"); }

        const auto HalfExtents = Piece.HalfExtents;
        if (utils_severed_limb::Get_IsFinite(HalfExtents) == false || HalfExtents.X <= 0.0 || HalfExtents.Y <= 0.0 || HalfExtents.Z <= 0.0)
        { return FMars_Validation(f"SeveredLimb piece [{Index}] has half extents [{HalfExtents}] that are not positive and finite"); }
    }

    if (utils_severed_limb::Get_IsFinite(Self.LaunchVelocity) == false)
    { return FMars_Validation("SeveredLimb has a non-finite LaunchVelocity"); }

    return Self.Debris.Validate();
}

//--------------------------------------------------------------------------------------------------------------------------
// Ledger (on the limb's root)
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_SeveredLimb_Pose
{
    UPROPERTY()
    FVector Location = FVector::ZeroVector;

    UPROPERTY()
    FQuat Rotation = FQuat::Identity;

    FMars_SeveredLimb_Pose() {}

    FMars_SeveredLimb_Pose(FTransform InTransform)
    {
        Location = InTransform.GetLocation();
        Rotation = InTransform.GetRotation();
    }
}

// Replicated. Every piece's pose in the root's frame, in piece order. Written only by the authority, through
// utils_severed_limb::Publish; AtRest is set by the one final write.
struct FMars_Fragment_SeveredLimb_Net
{
    UPROPERTY()
    TArray<FMars_SeveredLimb_Pose> Pieces;

    UPROPERTY()
    bool AtRest = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Where two neighbouring pieces met at the cut, in each one's own frame: the end of the upper piece's drawn box.
struct FMars_SeveredLimb_JointEnds
{
    UPROPERTY()
    FVector OnUpper = FVector::ZeroVector;

    UPROPERTY()
    FVector OnLower = FVector::ZeroVector;
}

// A copy's piece easing from the pose it had to the newest written one.
struct FMars_SeveredLimb_Ease
{
    UPROPERTY()
    FMars_SeveredLimb_Pose From;

    UPROPERTY()
    FMars_SeveredLimb_Pose To;

    UPROPERTY()
    float32 Elapsed = 0.0f;
}

// Each machine's own, composed by Add and written only by the limb's processors.
struct FMars_Fragment_SeveredLimb
{
    UPROPERTY()
    TArray<FMars_SeveredLimb_PieceSpec> Pieces;

    // One per neighbouring pair, on every machine.
    UPROPERTY()
    TArray<FMars_SeveredLimb_JointEnds> JointEnds;

    // The authority's constraints, one per neighbouring pair; empty on a copy.
    UPROPERTY()
    TArray<FCk_Handle_JoltConstraint> Joints;

    // How far Add raised every piece so that no piece's body starts below the ground under it (cm, never negative).
    UPROPERTY()
    float64 BirthLift = 0.0;

    // Authority: time since the last sample, and since the last write.
    UPROPERTY()
    float32 PublishClock = 0.0f;

    UPROPERTY()
    float32 QuietSeconds = 0.0f;

    // Copy: one per piece once a write has arrived.
    UPROPERTY()
    TArray<FMars_SeveredLimb_Ease> Eases;
}

// Each machine's own: the ledger the mirror last applied (unset with authority) and whether this copy has taken the
// state it was born into.
struct FMars_Fragment_SeveredLimb_Local
{
    UPROPERTY()
    TOptional<FMars_Fragment_SeveredLimb_Net> Last;

    UPROPERTY()
    EMars_Net_InitialState InitialState = EMars_Net_InitialState::Awaited;
}

// Added by Add, dropped by UMars_Processor_SeveredLimb_Mirror once it has bound the ledger's rep-notify.
struct FMars_Tag_SeveredLimb_NeedsMirror {}

// Authority, from Add until the final write.
struct FMars_Tag_SeveredLimb_Publishing {}

// A copy only, added by the mirror and never removed: UMars_Processor_SeveredLimb_Ease runs on it.
struct FMars_Tag_SeveredLimb_Easing {}
