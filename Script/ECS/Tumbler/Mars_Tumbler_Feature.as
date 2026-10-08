//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_TumblerHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Tumbler";
    RequiredFragments.Add(FMars_Feature_Tumbler);
    Description = "A tumbling minigame on a station: a hand the operator steers over a reach plane, a hatch it clicks open and shut, a crank lever it grips and rocks (one Mover turns lever, drum and its kinematic shell together), and admitted pieces that tumble as dynamic bodies in the shell and gain coating with the distance they move while it is shut";
}
struct FMars_Feature_Tumbler {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// Free: the hand follows the cursor (and snaps to a hovered target). Reaching: travelling to the lever grip after a press on
// it. Gripped: riding the lever grip; looks rock the lever.
enum EMars_Tumbler_HandMode
{
    Free,
    Reaching,
    Gripped
}

enum EMars_Tumbler_Target
{
    None,
    Hatch,
    Lever
}

enum EMars_Tumbler_Hatch
{
    Closed,
    Opening,
    Open,
    Closing
}

// Home: the drum rests at its start pose. Gripped: the operator holds the lever. Returning: let go, the axle Mover settling
// back to its start pose.
enum EMars_Tumbler_Drum
{
    Home,
    Gripped,
    Returning
}

// InFlight while the feed carries a piece toward the drum (the control layer forwards the feed's busy edges).
enum EMars_Tumbler_Loading
{
    Idle,
    InFlight
}

// Why a press did nothing.
enum EMars_Tumbler_Refusal
{
    NotHome,
    HatchOpen,
    HatchMoving,
    LoadingInFlight,
    NoTarget,
    HandBusy
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The reach surface is the station-frame YZ plane through WorkspaceCentreLocal; the cursor is a (Y, Z) point on it.
struct FMars_Tumbler_HandSpec
{
    UPROPERTY()
    FVector WorkspaceCentreLocal = FVector::ZeroVector;

    UPROPERTY()
    float32 HalfExtentY = 45.0f;

    UPROPERTY()
    float32 HalfExtentZ = 35.0f;

    UPROPERTY()
    float32 CmPerLookDegree = 1.2f;

    // Per second: the hand eases toward its target with 1 - exp(-FollowRate * dt).
    UPROPERTY()
    float32 FollowRate = 18.0f;

    // From the free pose to the lever grip; 0 grips at once.
    UPROPERTY()
    float32 ReachSeconds = 0.25f;

    FMars_Tumbler_HandSpec() {}

    FMars_Tumbler_HandSpec(
        FVector InWorkspaceCentreLocal,
        float32 InHalfExtentY,
        float32 InHalfExtentZ,
        float32 InCmPerLookDegree,
        float32 InFollowRate,
        float32 InReachSeconds)
    {
        WorkspaceCentreLocal = InWorkspaceCentreLocal;
        HalfExtentY = InHalfExtentY;
        HalfExtentZ = InHalfExtentZ;
        CmPerLookDegree = InCmPerLookDegree;
        FollowRate = InFollowRate;
        ReachSeconds = InReachSeconds;
    }
}

// A target is hovered when the cursor's plane point is within its radius of the target anchor's YZ projection; nearest wins.
struct FMars_Tumbler_TargetsSpec
{
    UPROPERTY()
    float32 HatchRadius = 14.0f;

    UPROPERTY()
    float32 LeverRadius = 16.0f;

    FMars_Tumbler_TargetsSpec() {}

    FMars_Tumbler_TargetsSpec(float32 InHatchRadius, float32 InLeverRadius)
    {
        HatchRadius = InHatchRadius;
        LeverRadius = InLeverRadius;
    }
}

// ArcDegrees must equal the axle Mover's end pitch: the kernel reads the drum's turn as the Mover's alpha times it.
struct FMars_Tumbler_DrumSpec
{
    UPROPERTY()
    float32 ArcDegrees = 90.0f;

    // The shell's inner faces sit this far from the axis.
    UPROPERTY()
    float32 InnerRadius = 28.0f;

    // The baffles' half length along the axis; the panels reach Shell.DiscGap past it to the end discs.
    UPROPERTY()
    float32 HalfLength = 22.0f;

    UPROPERTY()
    int32 Capacity = 6;

    // A piece whose centre is this far past the shell's inner radius or its end discs has escaped and is reseated.
    UPROPERTY()
    float32 EscapeMarginCm = 6.0f;

    FMars_Tumbler_DrumSpec() {}

    FMars_Tumbler_DrumSpec(
        float32 InArcDegrees,
        float32 InInnerRadius,
        float32 InHalfLength,
        int32 InCapacity,
        float32 InEscapeMarginCm)
    {
        ArcDegrees = InArcDegrees;
        InnerRadius = InInnerRadius;
        HalfLength = InHalfLength;
        Capacity = InCapacity;
        EscapeMarginCm = InEscapeMarginCm;
    }
}

// The hatch gap in the shell, drum frame degrees from the bottom at home (-90 is the operator's side): it spans
// CentreDegrees +/- HalfDegrees, the hinge at its upper edge (CentreDegrees - HalfDegrees); the hatch body is PlateSegments
// boxes across it.
struct FMars_Tumbler_GapSpec
{
    UPROPERTY()
    float32 CentreDegrees = -120.0f;

    UPROPERTY()
    float32 HalfDegrees = 35.0f;

    UPROPERTY()
    int32 PlateSegments = 3;

    FMars_Tumbler_GapSpec() {}

    FMars_Tumbler_GapSpec(float32 InCentreDegrees, float32 InHalfDegrees, int32 InPlateSegments)
    {
        CentreDegrees = InCentreDegrees;
        HalfDegrees = InHalfDegrees;
        PlateSegments = InPlateSegments;
    }
}

// Ribs on the shell's inner face, spread evenly over the closed arc: what lifts the pieces as the drum turns.
struct FMars_Tumbler_BafflesSpec
{
    UPROPERTY()
    int32 Count = 3;

    UPROPERTY()
    float32 Height = 4.0f;

    FMars_Tumbler_BafflesSpec() {}

    FMars_Tumbler_BafflesSpec(int32 InCount, float32 InHeight)
    {
        Count = InCount;
        Height = InHeight;
    }
}

struct FMars_Tumbler_SurfaceSpec
{
    UPROPERTY()
    float32 Friction = 0.6f;

    UPROPERTY()
    float32 Restitution = 0.05f;

    FMars_Tumbler_SurfaceSpec() {}

    FMars_Tumbler_SurfaceSpec(float32 InFriction, float32 InRestitution)
    {
        Friction = InFriction;
        Restitution = InRestitution;
    }
}

// The kinematic shell utils_tumbler::Add_DrumBodies and Add_HatchBody build: end discs DiscGap past the baffles' half
// length, PanelCount tangent boxes WallThickness thick around the closed arc, the baffles and the hatch plate.
struct FMars_Tumbler_ShellSpec
{
    UPROPERTY()
    float32 WallThickness = 2.0f;

    UPROPERTY()
    int32 PanelCount = 14;

    UPROPERTY()
    float32 DiscGap = 4.0f;

    UPROPERTY()
    FMars_Tumbler_GapSpec Gap;

    UPROPERTY()
    FMars_Tumbler_BafflesSpec Baffles;

    UPROPERTY()
    FMars_Tumbler_SurfaceSpec Surface;
}

// Each admitted piece is a dynamic box body of this size and feel.
struct FMars_Tumbler_PieceSpec
{
    UPROPERTY()
    float32 HalfSize = 6.0f;

    UPROPERTY()
    float32 MassKg = 0.1f;

    UPROPERTY()
    float32 Friction = 0.6f;

    UPROPERTY()
    float32 Restitution = 0.1f;

    UPROPERTY()
    float32 LinearDamping = 0.05f;

    UPROPERTY()
    float32 AngularDamping = 0.15f;

    FMars_Tumbler_PieceSpec() {}

    FMars_Tumbler_PieceSpec(
        float32 InHalfSize,
        float32 InMassKg,
        float32 InFriction,
        float32 InRestitution,
        float32 InLinearDamping,
        float32 InAngularDamping)
    {
        HalfSize = InHalfSize;
        MassKg = InMassKg;
        Friction = InFriction;
        Restitution = InRestitution;
        LinearDamping = InLinearDamping;
        AngularDamping = InAngularDamping;
    }
}

// Useful travel: the distance each piece's own centre moves while the hatch is Closed. A step under MinStepCm is solver
// jitter, not tumbling, and coats nothing.
struct FMars_Tumbler_CoatingSpec
{
    UPROPERTY()
    float32 CoveragePerCm = 1.0f / 900.0f;

    UPROPERTY()
    float32 MinStepCm = 0.05f;

    FMars_Tumbler_CoatingSpec() {}

    FMars_Tumbler_CoatingSpec(float32 InCoveragePerCm, float32 InMinStepCm)
    {
        CoveragePerCm = InCoveragePerCm;
        MinStepCm = InMinStepCm;
    }
}

// Built by the placing script before Add. Hand is a scene node on the station root (the kernel writes its offset); HatchTab
// is a child of the hatch hinge and LeverGrip a child of the axle (both read as hover anchors); Lever is the axle's
// ManuallyCompleted Control, whose Mover is the drum; Hatch is the hinge Mover (Start = closed, End = open); Drum is the
// axle node (the kernel reads every piece in its frame); DrumBody is the shell utils_tumbler::Add_DrumBodies built under it
// (admission waits for it to be in the simulation); View gives screen right and up for the pull projection.
struct FMars_Tumbler_Nodes
{
    UPROPERTY()
    FCk_Handle_SceneNode Hand;

    UPROPERTY()
    FCk_Handle_Transform HatchTab;

    UPROPERTY()
    FCk_Handle_Transform LeverGrip;

    UPROPERTY()
    FCk_Handle_Control Lever;

    UPROPERTY()
    FCk_Handle_Mover Hatch;

    UPROPERTY()
    FCk_Handle_Transform Drum;

    UPROPERTY()
    FCk_Handle_JoltBody DrumBody;

    UPROPERTY()
    FCk_Handle_Transform View;

    FMars_Tumbler_Nodes() {}

    FMars_Tumbler_Nodes(
        FCk_Handle_SceneNode InHand,
        FCk_Handle_Transform InHatchTab,
        FCk_Handle_Transform InLeverGrip,
        FCk_Handle_Control InLever,
        FCk_Handle_Mover InHatch,
        FCk_Handle_Transform InDrum,
        FCk_Handle_JoltBody InDrumBody,
        FCk_Handle_Transform InView)
    {
        Hand = InHand;
        HatchTab = InHatchTab;
        LeverGrip = InLeverGrip;
        Lever = InLever;
        Hatch = InHatch;
        Drum = InDrum;
        DrumBody = InDrumBody;
        View = InView;
    }
}

struct FMars_Tumbler_Spec
{
    UPROPERTY()
    FMars_Tumbler_HandSpec Hand;

    UPROPERTY()
    FMars_Tumbler_TargetsSpec Targets;

    UPROPERTY()
    FMars_Tumbler_DrumSpec Drum;

    UPROPERTY()
    FMars_Tumbler_ShellSpec Shell;

    UPROPERTY()
    FMars_Tumbler_PieceSpec Piece;

    UPROPERTY()
    FMars_Tumbler_CoatingSpec Coating;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Tumbler_Nodes Nodes;
}

// A reach with no extent or no look, a hand that never arrives, a target nobody can hover, a drum that never turns, has no
// room or never notices an escape, a shell with no wall, too few panels to close, a gap that swallows the drum or a hatch
// with no plate, a baffle with no height, a piece with no size or mass or one that cannot fit, or a coating that never grows
// each make the minigame unplayable.
mixin FMars_Validation Validate(const FMars_Tumbler_Spec& Self)
{
    const auto& Hand = Self.Hand;
    if (Hand.HalfExtentY <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Hand.HalfExtentY [{Hand.HalfExtentY}]"); }

    if (Hand.HalfExtentZ <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Hand.HalfExtentZ [{Hand.HalfExtentZ}]"); }

    if (Hand.CmPerLookDegree <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Hand.CmPerLookDegree [{Hand.CmPerLookDegree}]"); }

    if (Hand.FollowRate <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Hand.FollowRate [{Hand.FollowRate}]"); }

    if (Hand.ReachSeconds < 0.0f)
    { return FMars_Validation(f"Tumbler has a negative Hand.ReachSeconds [{Hand.ReachSeconds}]"); }

    if (Self.Targets.HatchRadius <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Targets.HatchRadius [{Self.Targets.HatchRadius}]"); }

    if (Self.Targets.LeverRadius <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Targets.LeverRadius [{Self.Targets.LeverRadius}]"); }

    const auto& Drum = Self.Drum;
    if (Drum.ArcDegrees <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Drum.ArcDegrees [{Drum.ArcDegrees}]"); }

    if (Drum.InnerRadius <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Drum.InnerRadius [{Drum.InnerRadius}]"); }

    if (Drum.HalfLength <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Drum.HalfLength [{Drum.HalfLength}]"); }

    if (Drum.Capacity <= 0)
    { return FMars_Validation(f"Tumbler has a non-positive Drum.Capacity [{Drum.Capacity}]"); }

    if (Drum.EscapeMarginCm <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Drum.EscapeMarginCm [{Drum.EscapeMarginCm}]"); }

    const auto& Shell = Self.Shell;
    if (Shell.WallThickness <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Shell.WallThickness [{Shell.WallThickness}]"); }

    if (Shell.PanelCount < 6)
    { return FMars_Validation(f"Tumbler has Shell.PanelCount [{Shell.PanelCount}] under 6"); }

    if (Shell.DiscGap <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Shell.DiscGap [{Shell.DiscGap}]"); }

    if (Shell.Gap.HalfDegrees <= 0.0f || Shell.Gap.HalfDegrees >= 90.0f)
    { return FMars_Validation(f"Tumbler has Shell.Gap.HalfDegrees [{Shell.Gap.HalfDegrees}] outside (0, 90)"); }

    if (Shell.Gap.PlateSegments < 1)
    { return FMars_Validation(f"Tumbler has Shell.Gap.PlateSegments [{Shell.Gap.PlateSegments}] under 1"); }

    if (Shell.Baffles.Count < 0)
    { return FMars_Validation(f"Tumbler has a negative Shell.Baffles.Count [{Shell.Baffles.Count}]"); }

    if (Shell.Baffles.Height <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Shell.Baffles.Height [{Shell.Baffles.Height}]"); }

    if (Shell.Surface.Friction <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Shell.Surface.Friction [{Shell.Surface.Friction}]"); }

    if (Shell.Surface.Restitution <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Shell.Surface.Restitution [{Shell.Surface.Restitution}]"); }

    const auto& Piece = Self.Piece;
    if (Piece.HalfSize <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Piece.HalfSize [{Piece.HalfSize}]"); }

    if (Piece.HalfSize >= Drum.InnerRadius)
    { return FMars_Validation(f"Tumbler has Piece.HalfSize [{Piece.HalfSize}] not under Drum.InnerRadius [{Drum.InnerRadius}]"); }

    if (Piece.MassKg <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Piece.MassKg [{Piece.MassKg}]"); }

    if (Piece.Friction <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Piece.Friction [{Piece.Friction}]"); }

    if (Piece.Restitution <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Piece.Restitution [{Piece.Restitution}]"); }

    if (Piece.LinearDamping <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Piece.LinearDamping [{Piece.LinearDamping}]"); }

    if (Piece.AngularDamping <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Piece.AngularDamping [{Piece.AngularDamping}]"); }

    if (Self.Coating.CoveragePerCm <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Coating.CoveragePerCm [{Self.Coating.CoveragePerCm}]"); }

    if (Self.Coating.MinStepCm <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Coating.MinStepCm [{Self.Coating.MinStepCm}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Tumbler_Params
{
    UPROPERTY()
    FMars_Tumbler_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Tumbler_HandState
{
    UPROPERTY()
    EMars_Tumbler_HandMode Mode = EMars_Tumbler_HandMode::Free;

    // (Y, Z) on the reach plane, station frame, relative to WorkspaceCentreLocal and clamped to the half extents.
    UPROPERTY()
    FVector2D Cursor = FVector2D::ZeroVector;

    // Station frame: what the Hand node's offset is written from.
    UPROPERTY()
    FVector HandLocal = FVector::ZeroVector;

    UPROPERTY()
    FQuat HandRotationLocal = FQuat::Identity;

    // Reaching only.
    UPROPERTY()
    float32 ReachElapsed = 0.0f;

    // Where the reach started (station frame).
    UPROPERTY()
    FVector ReachFrom = FVector::ZeroVector;

    UPROPERTY()
    FQuat ReachFromRotation = FQuat::Identity;
}

// One admitted piece, keyed by the feed identity it arrived with (an array index is never identity). Its entity is a
// lifetime child of the station carrying a dynamic box body: the simulation moves it, the kernel only reads it (and
// reseats it when it escapes).
struct FMars_Tumbler_PieceState
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    // The release's preset (which mesh the placing script dresses it as); the kernel never reads it.
    UPROPERTY()
    int32 PresetIndex = 0;

    UPROPERTY()
    FCk_Handle Entity;

    UPROPERTY()
    FCk_Handle_JoltBody Body;

    // The piece's world location as of the last tick: the next tick's step is measured from it.
    UPROPERTY()
    FVector LastWorld = FVector::ZeroVector;

    // 0..1, never decreases.
    UPROPERTY()
    float32 Coverage = 0.0f;
}

// Written only by the two Tumbler processors (and Add). The station SM, the feed bridge and the operator only issue requests.
struct FMars_Fragment_Tumbler
{
    UPROPERTY()
    FMars_Tumbler_HandState Hand;

    UPROPERTY()
    EMars_Tumbler_Target Hovered = EMars_Tumbler_Target::None;

    UPROPERTY()
    EMars_Tumbler_Hatch Hatch = EMars_Tumbler_Hatch::Closed;

    UPROPERTY()
    EMars_Tumbler_Drum Drum = EMars_Tumbler_Drum::Home;

    UPROPERTY()
    EMars_Tumbler_Loading Loading = EMars_Tumbler_Loading::Idle;

    // The drum's turn from home as of the last tick (the axle Mover's alpha times ArcDegrees).
    UPROPERTY()
    float32 DrumDegrees = 0.0f;

    // In admission order.
    UPROPERTY()
    TArray<FMars_Tumbler_PieceState> Pieces;

    // Escaped pieces put back since the last Reset.
    UPROPERTY()
    int32 Reseats = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Tumbler_OnHandModeChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_HandMode InHandMode);
event void FMars_Delegate_Tumbler_OnHandModeChanged_MC(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_HandMode InHandMode);

delegate void FMars_Delegate_Tumbler_OnHoverChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Target InTarget);
event void FMars_Delegate_Tumbler_OnHoverChanged_MC(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Target InTarget);

delegate void FMars_Delegate_Tumbler_OnHatchChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Hatch InHatch);
event void FMars_Delegate_Tumbler_OnHatchChanged_MC(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Hatch InHatch);

delegate void FMars_Delegate_Tumbler_OnDrumChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Drum InDrum);
event void FMars_Delegate_Tumbler_OnDrumChanged_MC(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Drum InDrum);

// A press that did nothing (consumed: nothing is queued).
delegate void FMars_Delegate_Tumbler_OnPressRefused(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Refusal InRefusal);
event void FMars_Delegate_Tumbler_OnPressRefused_MC(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Refusal InRefusal);

// The answer to every AddPiece: Accepted (the piece entity exists; OnPieceAdded follows) or Rejected with a reason (nothing
// made).
delegate void FMars_Delegate_Tumbler_OnPieceAdmission(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);
event void FMars_Delegate_Tumbler_OnPieceAdmission_MC(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);

// An admitted piece's entity (its body's) exists: the placing script adds its visuals here.
delegate void FMars_Delegate_Tumbler_OnPieceAdded(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);
event void FMars_Delegate_Tumbler_OnPieceAdded_MC(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);

delegate void FMars_Delegate_Tumbler_OnCoverageChanged(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, float32 InCoverage);
event void FMars_Delegate_Tumbler_OnCoverageChanged_MC(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, float32 InCoverage);

// A piece escaped the shell and was put back at the drum's bottom (no failure state): the assembly may cue it.
delegate void FMars_Delegate_Tumbler_OnPieceReseated(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId);
event void FMars_Delegate_Tumbler_OnPieceReseated_MC(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId);

struct FMars_Fragment_Tumbler_Signals
{
    FMars_Delegate_Tumbler_OnHandModeChanged_MC OnHandModeChanged;
    FMars_Delegate_Tumbler_OnHoverChanged_MC OnHoverChanged;
    FMars_Delegate_Tumbler_OnHatchChanged_MC OnHatchChanged;
    FMars_Delegate_Tumbler_OnDrumChanged_MC OnDrumChanged;
    FMars_Delegate_Tumbler_OnPressRefused_MC OnPressRefused;
    FMars_Delegate_Tumbler_OnPieceAdmission_MC OnPieceAdmission;
    FMars_Delegate_Tumbler_OnPieceAdded_MC OnPieceAdded;
    FMars_Delegate_Tumbler_OnCoverageChanged_MC OnCoverageChanged;
    FMars_Delegate_Tumbler_OnPieceReseated_MC OnPieceReseated;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Debug and tests only: destroys every piece entity (its body with it), zeroes the reseat count, frees the hand, closes the
// hatch and lets go of the lever. Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Tumbler_Reset
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Tumbler_Reset() {}
}

// The operator left: a grip ends (the drum returns) or a reach stops; the hand is Free. Pieces and coverage are untouched.
// Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Tumbler_Cancel
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Tumbler_Cancel() {}
}

// The feed's busy edges. Last wins within a drain.
struct FMars_Request_Tumbler_SetLoading
{
    UPROPERTY()
    EMars_Tumbler_Loading Loading = EMars_Tumbler_Loading::Idle;

    FMars_Request_Tumbler_SetLoading() {}

    FMars_Request_Tumbler_SetLoading(EMars_Tumbler_Loading InLoading)
    {
        Loading = InLoading;
    }
}

// One released piece to admit, answered by OnPieceAdmission. Accepted only with the drum body in the simulation, the hatch
// Open, the drum Home, no piece with that Id and fewer than Drum.Capacity pieces in. The piece's body starts at the
// release's pose and velocities.
struct FMars_Request_Tumbler_AddPiece
{
    UPROPERTY()
    FMars_CookingFeed_Release Release;

    FMars_Request_Tumbler_AddPiece() {}

    FMars_Request_Tumbler_AddPiece(FMars_CookingFeed_Release InRelease)
    {
        Release = InRelease;
    }
}

// The Use button going down. Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Tumbler_Press
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Tumbler_Press() {}
}

// The Use button coming up. Payload-less: one placeholder field (request doctrine).
struct FMars_Request_Tumbler_Release
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Tumbler_Release() {}
}

// One drained InputIntents look delta (degrees; X yaw right+, Y pitch down+). Summed per drain: Free moves the cursor,
// Gripped rocks the lever, Reaching drops it.
struct FMars_Request_Tumbler_Look
{
    UPROPERTY()
    FVector LookDelta = FVector::ZeroVector;

    FMars_Request_Tumbler_Look() {}

    FMars_Request_Tumbler_Look(FVector InLookDelta)
    {
        LookDelta = InLookDelta;
    }
}

// Applied Reset -> Cancel -> SetLoading -> AddPiece -> Release -> Press -> Look: a leave (Cancel) lands before anything the
// same drain asks of the hand, the feed's busy edge is current before admission and before a press reads it, and a release
// and a press sharing a drain end the old grip before the new press is judged.
struct FMars_Fragment_Tumbler_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Tumbler_Reset> ResetRequests;

    UPROPERTY()
    TArray<FMars_Request_Tumbler_Cancel> CancelRequests;

    UPROPERTY()
    TArray<FMars_Request_Tumbler_SetLoading> SetLoadingRequests;

    UPROPERTY()
    TArray<FMars_Request_Tumbler_AddPiece> AddPieceRequests;

    UPROPERTY()
    TArray<FMars_Request_Tumbler_Release> ReleaseRequests;

    UPROPERTY()
    TArray<FMars_Request_Tumbler_Press> PressRequests;

    UPROPERTY()
    TArray<FMars_Request_Tumbler_Look> LookRequests;
}
