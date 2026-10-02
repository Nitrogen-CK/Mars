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
    // The view turns freely inside CameraYawHalfAngle of the stand's facing.
    Free,
    // The view is frozen at the engage framing; the station reads the look delta itself.
    Captured
}

// Station frame: the root is the station's origin on the floor. StandLocal is where the operator stands (Z at the floor,
// +X facing the station); GripLocal is where the gloves hold while operating. Field order is the positional constructor's
// order (the spawn-params generator emits it when a subclass changes a default).
struct FMars_Station_Spec
{
    UPROPERTY()
    FTransform StandLocal = FTransform::Identity;

    UPROPERTY()
    FTransform GripLocal = FTransform::Identity;

    // Ceiling for the glide to the stand (seconds); the glide itself is derived from the distance and the turn
    // (utils_station::Get_EngageSeconds). 0 snaps.
    UPROPERTY()
    float32 EngageMaxSeconds = 0.35f;

    // The starting value of the station's engagement switch (FMars_Request_Station_SetEngagementEnabled changes it).
    UPROPERTY()
    bool AllowEngagement = true;

    UPROPERTY()
    EMars_Station_LookControl LookControl = EMars_Station_LookControl::Free;

    // Free only: how far the view may turn each side of the stand's facing (degrees).
    UPROPERTY()
    float32 CameraYawHalfAngle = 60.0f;

    // The view pitch snapped at engage (degrees; negative looks down).
    UPROPERTY()
    float32 CameraPitchOffset = -25.0f;

    UPROPERTY()
    FText PromptText = NSLOCTEXT("MarsInteraction", "UseStationPrompt", "Use station");

    // What the Use prompt reads while an operator holds the station.
    UPROPERTY()
    FText OccupiedText = NSLOCTEXT("MarsInteraction", "StationInUsePrompt", "In use");

    // Root state of the station's own state machine (context = the station); unset = no minigame.
    UPROPERTY()
    TSoftClassPtr<UCk_SmState_EntityScript> MinigameStateClass;

    FMars_Station_Spec() {}

    FMars_Station_Spec(
        FTransform InStandLocal,
        FTransform InGripLocal,
        float32 InEngageMaxSeconds,
        bool InAllowEngagement,
        EMars_Station_LookControl InLookControl,
        float32 InCameraYawHalfAngle,
        float32 InCameraPitchOffset,
        FText InPromptText,
        FText InOccupiedText,
        TSoftClassPtr<UCk_SmState_EntityScript> InMinigameStateClass)
    {
        StandLocal = InStandLocal;
        GripLocal = InGripLocal;
        EngageMaxSeconds = InEngageMaxSeconds;
        AllowEngagement = InAllowEngagement;
        LookControl = InLookControl;
        CameraYawHalfAngle = InCameraYawHalfAngle;
        CameraPitchOffset = InCameraPitchOffset;
        PromptText = InPromptText;
        OccupiedText = InOccupiedText;
        MinigameStateClass = InMinigameStateClass;
    }
}

// A negative glide ceiling has no meaning, a yaw half angle outside (0, 180] fences nothing or everything, and an empty
// prompt text leaves the player a glyph with no verb.
mixin FMars_Validation Validate(const FMars_Station_Spec& Self)
{
    if (Self.EngageMaxSeconds < 0.0f)
    { return FMars_Validation(f"Station has a negative EngageMaxSeconds [{Self.EngageMaxSeconds}]"); }

    if (Self.CameraYawHalfAngle <= 0.0f || Self.CameraYawHalfAngle > 180.0f)
    { return FMars_Validation(f"Station has CameraYawHalfAngle [{Self.CameraYawHalfAngle}] outside (0, 180]"); }

    if (Self.PromptText.IsEmpty())
    { return FMars_Validation("Station has an empty PromptText"); }

    if (Self.OccupiedText.IsEmpty())
    { return FMars_Validation("Station has an empty OccupiedText"); }

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

    // Child scene node at GripLocal: hosts the grip interactable the gloves hold.
    UPROPERTY()
    FCk_Handle_Transform GripNode;

    // The Use interactable (one Instant target that reserves the station).
    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    // Transform-only, prompt-less: one ManuallyCompleted Use target the Operating state starts so the gloves hold.
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
