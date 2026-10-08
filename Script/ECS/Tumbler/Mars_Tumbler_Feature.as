//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_TumblerHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Tumbler";
    RequiredFragments.Add(FMars_Feature_Tumbler);
    Description = "A tumbling minigame on a station: a hand the operator steers over a reach plane, a hatch it clicks open and shut, a crank lever it grips and rocks (one Mover turns lever and drum together), and admitted pieces that tumble kinematically in the drum and gain coating with every degree it turns while shut";
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

    // The pieces' orbit radius.
    UPROPERTY()
    float32 InnerRadius = 28.0f;

    // The pieces' axial spread.
    UPROPERTY()
    float32 HalfLength = 22.0f;

    // A piece is carried until its world angle from the bottom is this far from its rest offset, then it slides.
    UPROPERTY()
    float32 ReposeDegrees = 35.0f;

    UPROPERTY()
    float32 SlideDegreesPerSecond = 120.0f;

    UPROPERTY()
    int32 Capacity = 6;

    FMars_Tumbler_DrumSpec() {}

    FMars_Tumbler_DrumSpec(
        float32 InArcDegrees,
        float32 InInnerRadius,
        float32 InHalfLength,
        float32 InReposeDegrees,
        float32 InSlideDegreesPerSecond,
        int32 InCapacity)
    {
        ArcDegrees = InArcDegrees;
        InnerRadius = InInnerRadius;
        HalfLength = InHalfLength;
        ReposeDegrees = InReposeDegrees;
        SlideDegreesPerSecond = InSlideDegreesPerSecond;
        Capacity = InCapacity;
    }
}

// Useful travel: every degree the drum turns while the hatch is Closed, gripped or returning.
struct FMars_Tumbler_CoatingSpec
{
    UPROPERTY()
    float32 CoveragePerDegree = 1.0f / 540.0f;

    FMars_Tumbler_CoatingSpec() {}

    FMars_Tumbler_CoatingSpec(float32 InCoveragePerDegree)
    {
        CoveragePerDegree = InCoveragePerDegree;
    }
}

// Built by the placing script before Add. Hand is a scene node on the station root (the kernel writes its offset); HatchTab
// is a child of the hatch plate and LeverGrip a child of the axle (both read as hover anchors); Lever is the axle's
// ManuallyCompleted Control, whose Mover is the drum; Hatch is the hinge Mover (Start = closed, End = open); Drum is the
// axle node (pieces are scene nodes under it); View gives screen right and up for the pull projection.
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
    FCk_Handle_Transform View;

    FMars_Tumbler_Nodes() {}

    FMars_Tumbler_Nodes(
        FCk_Handle_SceneNode InHand,
        FCk_Handle_Transform InHatchTab,
        FCk_Handle_Transform InLeverGrip,
        FCk_Handle_Control InLever,
        FCk_Handle_Mover InHatch,
        FCk_Handle_Transform InDrum,
        FCk_Handle_Transform InView)
    {
        Hand = InHand;
        HatchTab = InHatchTab;
        LeverGrip = InLeverGrip;
        Lever = InLever;
        Hatch = InHatch;
        Drum = InDrum;
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
    FMars_Tumbler_CoatingSpec Coating;

    // Built by the placing script before Add. Not a UPROPERTY: the spawn params never carry handles.
    FMars_Tumbler_Nodes Nodes;
}

// A reach with no extent or no look, a hand that never arrives, a target nobody can hover, a drum that never turns or has no
// orbit, a repose that never carries or carries past the side, a slide that never moves, a drum with no room, or a coating
// that never grows each make the minigame unplayable.
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

    if (Drum.HalfLength < 0.0f)
    { return FMars_Validation(f"Tumbler has a negative Drum.HalfLength [{Drum.HalfLength}]"); }

    if (Drum.ReposeDegrees <= 0.0f || Drum.ReposeDegrees > 90.0f)
    { return FMars_Validation(f"Tumbler has Drum.ReposeDegrees [{Drum.ReposeDegrees}] outside (0, 90]"); }

    if (Drum.SlideDegreesPerSecond <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Drum.SlideDegreesPerSecond [{Drum.SlideDegreesPerSecond}]"); }

    if (Drum.Capacity <= 0)
    { return FMars_Validation(f"Tumbler has a non-positive Drum.Capacity [{Drum.Capacity}]"); }

    if (Self.Coating.CoveragePerDegree <= 0.0f)
    { return FMars_Validation(f"Tumbler has a non-positive Coating.CoveragePerDegree [{Self.Coating.CoveragePerDegree}]"); }

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

// One admitted piece, keyed by the feed identity it arrived with (an array index is never identity). Its entity is a scene
// node under the drum, posed by the kernel.
// A piece rides the drum (Carried) until its world angle is more than ReposeDegrees from its rest offset; it then
// avalanches (Sliding) all the way back to rest, whatever the drum does meanwhile, and is carried again from there.
enum EMars_Tumbler_PieceMotion
{
    Carried,
    Sliding
}

struct FMars_Tumbler_PieceState
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    // The release's preset (which mesh the placing script dresses it as); the kernel never reads it.
    UPROPERTY()
    int32 PresetIndex = 0;

    UPROPERTY()
    FCk_Handle Entity;

    // Drum frame, 0 = the drum's bottom at home.
    UPROPERTY()
    float32 OrbitDegrees = 0.0f;

    // The world angle the piece settles toward (spread by slot so the batch does not stack).
    UPROPERTY()
    float32 RestOffsetDegrees = 0.0f;

    UPROPERTY()
    float32 AxialCm = 0.0f;

    UPROPERTY()
    EMars_Tumbler_PieceMotion Motion = EMars_Tumbler_PieceMotion::Carried;

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

// The answer to every AddPiece: Accepted (the node exists; OnPieceAdded follows) or Rejected with a reason (nothing made).
delegate void FMars_Delegate_Tumbler_OnPieceAdmission(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);
event void FMars_Delegate_Tumbler_OnPieceAdmission_MC(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason);

// An admitted piece's node exists under the drum: the placing script adds its visuals here.
delegate void FMars_Delegate_Tumbler_OnPieceAdded(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);
event void FMars_Delegate_Tumbler_OnPieceAdded_MC(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece);

delegate void FMars_Delegate_Tumbler_OnCoverageChanged(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, float32 InCoverage);
event void FMars_Delegate_Tumbler_OnCoverageChanged_MC(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, float32 InCoverage);

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
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Debug and tests only: destroys every piece node, frees the hand, closes the hatch and lets go of the lever.
// Payload-less: one placeholder field (request doctrine).
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

// One released piece to admit, answered by OnPieceAdmission. Accepted only with the hatch Open, the drum Home, no piece with
// that Id and fewer than Drum.Capacity pieces in. The release's pose is not used: the kernel places the piece by its slot.
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
