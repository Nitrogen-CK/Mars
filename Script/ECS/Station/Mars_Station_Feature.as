//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_StationHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Station";
    RequiredFragments.Add(FMars_Feature_Station);
    Description = "An operator point: where its one operator stands, the Use interaction that reserves it, the grip the gloves hold and an optional minigame state machine";
}
struct FMars_Feature_Station {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Station_RejectReason
{
    // Another operator holds the station.
    Occupied,
    // The operator already holds a different station.
    AlreadyOperating,
    // The station is not taking operators right now (SetEngagementEnabled false, or the spec's AllowEngagement).
    Disabled
}

enum EMars_Station_ReleaseReason
{
    OperatorRequested,
    StationRequested,
    // The operator entity began destroying while it held the station.
    OperatorLost,
    // The station entity began destroying while an operator held it.
    StationDestroyed
}

enum EMars_Station_LookControl
{
    // The view turns freely inside Camera.YawHalfAngle of the stand's facing.
    Free,
    // The view is frozen at the engage framing; the station reads the look delta itself.
    Captured
}

// One glove's grip while operating: the station node the glove rides, named by its role tag (the entity script registers
// the node under that tag, FMars_Station_GripNode), and where on it.
struct FMars_Station_Grip
{
    UPROPERTY()
    EMars_Hand Hand = EMars_Hand::Right;

    UPROPERTY(meta = (Categories = "Station.Node"))
    FGameplayTag Node;

    // A socket on a static mesh the node (or a part under it) carries; NAME_None = the node itself.
    UPROPERTY()
    FName Socket;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Power;

    // Set, replaces the gloves' MaxReachCm for this grip (cm).
    UPROPERTY()
    TOptional<float32> ReachOverrideCm;

    // Socketless grips only: Aimed = a point grip at the node; Node = the node's own axes are the grip.
    UPROPERTY()
    EMars_FPHands_GripFrame Frame = EMars_FPHands_GripFrame::Aimed;

    // Authored grips: Fixed keeps the rotation (a tool held one way); FaceViewer takes the bar from the player's side.
    UPROPERTY()
    EMars_FPHands_GripRoll Roll = EMars_FPHands_GripRoll::Fixed;

    FMars_Station_Grip() {}

    FMars_Station_Grip(EMars_Hand InHand, FGameplayTag InNode, FName InSocket, EMars_HandGripPose InPose, TOptional<float32> InReachOverrideCm,
                       EMars_FPHands_GripFrame InFrame, EMars_FPHands_GripRoll InRoll)
    {
        Hand = InHand;
        Node = InNode;
        Socket = InSocket;
        Pose = InPose;
        ReachOverrideCm = InReachOverrideCm;
        Frame = InFrame;
        Roll = InRoll;
    }
}

// A station node published under a role tag, for the spec's grips to name.
struct FMars_Station_GripNode
{
    UPROPERTY()
    FGameplayTag Tag;

    UPROPERTY()
    FCk_Handle_Transform Node;

    FMars_Station_GripNode() {}

    FMars_Station_GripNode(FGameplayTag InTag, FCk_Handle_Transform InNode)
    {
        Tag = InTag;
        Node = InNode;
    }
}

// What the placing script hands utils_station::Add beside the spec: the Use probe (unset = a transform-only Use
// interactable) and the nodes its grips name.
struct FMars_Station_Setup
{
    // Not a UPROPERTY, as FMars_Interactable_Spec.ProbeInfo.
    TOptional<FMars_Interactable_ProbeInfo> Probe;

    UPROPERTY()
    TArray<FMars_Station_GripNode> GripNodes;
}

// The operator's view while operating. Field order is the positional constructor's order.
struct FMars_Station_CameraSpec
{
    UPROPERTY()
    EMars_Station_LookControl LookControl = EMars_Station_LookControl::Free;

    // Free only: how far the view may turn each side of the stand's facing (degrees).
    UPROPERTY()
    float32 YawHalfAngle = 60.0f;

    // The view pitch snapped at engage (degrees; negative looks down).
    UPROPERTY()
    float32 PitchOffset = -25.0f;

    FMars_Station_CameraSpec() {}

    FMars_Station_CameraSpec(EMars_Station_LookControl InLookControl, float32 InYawHalfAngle, float32 InPitchOffset)
    {
        LookControl = InLookControl;
        YawHalfAngle = InYawHalfAngle;
        PitchOffset = InPitchOffset;
    }
}

// What the Use prompt reads. Field order is the positional constructor's order.
struct FMars_Station_PromptSpec
{
    UPROPERTY()
    FText Text = NSLOCTEXT("MarsInteraction", "UseStationPrompt", "Use station");

    // While an operator holds the station.
    UPROPERTY()
    FText OccupiedText = NSLOCTEXT("MarsInteraction", "StationInUsePrompt", "In use");

    FMars_Station_PromptSpec() {}

    FMars_Station_PromptSpec(FText InText, FText InOccupiedText)
    {
        Text = InText;
        OccupiedText = InOccupiedText;
    }
}

// Station frame: the root is the station's origin on the floor. StandLocal is where the operator stands (Z at the floor,
// +X facing the station); Grips are where the gloves hold while operating, at most one per hand. Field order is the
// positional constructor's order (the spawn-params generator emits it when a subclass changes a default).
struct FMars_Station_Spec
{
    UPROPERTY()
    FTransform StandLocal = FTransform::Identity;

    UPROPERTY()
    TArray<FMars_Station_Grip> Grips;

    // Ceiling for the glide to the stand (seconds); the glide itself is derived from the distance and the turn
    // (utils_station::Get_EngageSeconds). 0 snaps.
    UPROPERTY()
    float32 EngageMaxSeconds = 0.35f;

    // The starting value of the station's engagement switch (FMars_Request_Station_SetEngagementEnabled changes it).
    UPROPERTY()
    bool AllowEngagement = true;

    UPROPERTY()
    FMars_Station_CameraSpec Camera;

    UPROPERTY()
    FMars_Station_PromptSpec Prompt;

    // Root state of the station's own state machine (context = the station); unset = no minigame.
    UPROPERTY()
    TSoftClassPtr<UCk_SmState_EntityScript> MinigameStateClass;

    FMars_Station_Spec() {}

    FMars_Station_Spec(
        FTransform InStandLocal,
        TArray<FMars_Station_Grip> InGrips,
        float32 InEngageMaxSeconds,
        bool InAllowEngagement,
        FMars_Station_CameraSpec InCamera,
        FMars_Station_PromptSpec InPrompt,
        TSoftClassPtr<UCk_SmState_EntityScript> InMinigameStateClass)
    {
        StandLocal = InStandLocal;
        Grips = InGrips;
        EngageMaxSeconds = InEngageMaxSeconds;
        AllowEngagement = InAllowEngagement;
        Camera = InCamera;
        Prompt = InPrompt;
        MinigameStateClass = InMinigameStateClass;
    }
}

// A negative glide ceiling has no meaning, a yaw half angle outside (0, 180] fences nothing or everything, an empty
// prompt text leaves the player a glyph with no verb, a grip without a node tag names nothing, and a glove holds one grip.
mixin FMars_Validation Validate(const FMars_Station_Spec& Self)
{
    for (int32 Index = 0; Index < Self.Grips.Num(); ++Index)
    {
        if (Self.Grips[Index].Node.IsValid() == false)
        { return FMars_Validation(f"Station grip [{Index}] has no node tag"); }

        for (int32 Earlier = 0; Earlier < Index; ++Earlier)
        {
            if (Self.Grips[Earlier].Hand == Self.Grips[Index].Hand)
            { return FMars_Validation(f"Station grip [{Index}] repeats the hand [{Self.Grips[Index].Hand :n}] of grip [{Earlier}]"); }
        }
    }

    if (Self.EngageMaxSeconds < 0.0f)
    { return FMars_Validation(f"Station has a negative EngageMaxSeconds [{Self.EngageMaxSeconds}]"); }

    if (Self.Camera.YawHalfAngle <= 0.0f || Self.Camera.YawHalfAngle > 180.0f)
    { return FMars_Validation(f"Station has Camera.YawHalfAngle [{Self.Camera.YawHalfAngle}] outside (0, 180]"); }

    if (Self.Prompt.Text.IsEmpty())
    { return FMars_Validation("Station has an empty Prompt.Text"); }

    if (Self.Prompt.OccupiedText.IsEmpty())
    { return FMars_Validation("Station has an empty Prompt.OccupiedText"); }

    return FMars_Validation();
}

struct FMars_Tag_Station_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// The spec, retained whole: the player's Operating state reads the stand, the look and the engage tuning from it.
struct FMars_Fragment_Station_Params
{
    UPROPERTY()
    FMars_Station_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Operator is written only by UMars_Processor_Station_HandleRequests, in the same drain as the operator's
// FMars_Fragment_Operator.Station (both ends of the link at once). The handles are composed by Add.
struct FMars_Fragment_Station
{
    // The operating entity (the player); invalid = free.
    UPROPERTY()
    FCk_Handle Operator;

    UPROPERTY()
    bool IsEngagementEnabled = true;

    // Child scene node at StandLocal: the world pose the operator glides to.
    UPROPERTY()
    FCk_Handle_Transform Stand;

    // The Use interactable (one Instant target that reserves the station).
    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    // Transform-only, prompt-less, on the root (its owner carries the grip table the gloves read): one ManuallyCompleted
    // Operate target the Operating state starts so the gloves hold.
    UPROPERTY()
    FCk_Handle_Interactable GripInteractable;

    // Invalid when the spec names no MinigameStateClass.
    UPROPERTY()
    FCk_Handle_StateMachine MinigameSm;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Station_OnReserved(FCk_Handle_Station InStation, FCk_Handle InOperator);
event void FMars_Delegate_Station_OnReserved_MC(FCk_Handle_Station InStation, FCk_Handle InOperator);

// Broadcast after both ends of the link are clear.
delegate void FMars_Delegate_Station_OnReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason);
event void FMars_Delegate_Station_OnReleased_MC(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason);

delegate void FMars_Delegate_Station_OnReserveRejected(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason);
event void FMars_Delegate_Station_OnReserveRejected_MC(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason);

struct FMars_Fragment_Station_Signals
{
    FMars_Delegate_Station_OnReserved_MC OnReserved;
    FMars_Delegate_Station_OnReleased_MC OnReleased;
    FMars_Delegate_Station_OnReserveRejected_MC OnReserveRejected;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// The operator must compose the Operator feature.
struct FMars_Request_Station_Reserve
{
    UPROPERTY()
    FCk_Handle Operator;

    FMars_Request_Station_Reserve() {}

    FMars_Request_Station_Reserve(FCk_Handle InOperator)
    {
        Operator = InOperator;
    }
}

// Always scoped: a no-op unless Operator is the one holding the station when it drains (a rejected or stale caller can
// never evict the holder).
struct FMars_Request_Station_Release
{
    UPROPERTY()
    FCk_Handle Operator;

    UPROPERTY()
    EMars_Station_ReleaseReason Reason = EMars_Station_ReleaseReason::StationRequested;

    FMars_Request_Station_Release() {}

    FMars_Request_Station_Release(FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        Operator = InOperator;
        Reason = InReason;
    }
}

// Disabling rejects later reserves (Disabled); it does not evict the current operator.
struct FMars_Request_Station_SetEngagementEnabled
{
    UPROPERTY()
    bool Enabled = true;

    FMars_Request_Station_SetEngagementEnabled() {}

    FMars_Request_Station_SetEngagementEnabled(bool InEnabled)
    {
        Enabled = InEnabled;
    }
}

// Applied SetEngagementEnabled -> Release -> Reserve, each kind in arrival order: a release and a reserve in one drain
// re-seat the station, and of two reserves in one drain the first wins and the second is rejected Occupied.
struct FMars_Fragment_Station_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Station_SetEngagementEnabled> SetEngagementEnabledRequests;

    UPROPERTY()
    TArray<FMars_Request_Station_Release> ReleaseRequests;

    UPROPERTY()
    TArray<FMars_Request_Station_Reserve> ReserveRequests;
}
