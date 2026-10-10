//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PlayerViewpointHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_PlayerViewpoint";
    RequiredFragments.Add(FMars_Feature_PlayerViewpoint);
    Description = "A player's view: the CkCamera director, its view anchor (the rendered view's transform) and the interaction trace cast from it";
}

struct FMars_Feature_PlayerViewpoint {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Camera and InteractionTraceDistance are consumed at Add; the Camera block builds the director's resting profile
// (utils_player_viewpoint::Make_CameraProfile), which exists before the director and so before Add.
struct FMars_PlayerViewpoint_Spec
{
    // The player's camera director; its view anchor becomes the viewpoint. Set at composition (a config asset leaves it
    // empty).
    UPROPERTY()
    FCk_Handle_Camera Camera;

    UPROPERTY()
    float32 InteractionTraceDistance = 250.0f;

    UPROPERTY(Category = "Camera")
    float32 FieldOfView = 90.0f;

    UPROPERTY(Category = "Camera")
    FCk_FloatRange PitchLimits = FCk_FloatRange(-89.0f, 89.0f);

    // Degrees of view rotation per unit of look intention (the input profile pre-scales by sensitivity).
    UPROPERTY(Category = "Camera")
    float32 LookSpeed = 1.0f;
}

mixin FMars_Validation Validate(const FMars_PlayerViewpoint_Spec& Self)
{
    if (ck::Is_NOT_Valid(Self.Camera))
    { return FMars_Validation("Camera is not set"); }

    // A NaN passes every comparison below, so finiteness is checked first.
    if (Math::IsFinite(Self.InteractionTraceDistance) == false)
    { return FMars_Validation(f"InteractionTraceDistance [{Self.InteractionTraceDistance}] is not finite"); }

    if (Math::IsFinite(Self.FieldOfView) == false)
    { return FMars_Validation(f"FieldOfView [{Self.FieldOfView}] is not finite"); }

    if (Math::IsFinite(Self.LookSpeed) == false)
    { return FMars_Validation(f"LookSpeed [{Self.LookSpeed}] is not finite"); }

    if (Self.InteractionTraceDistance <= 0.0f)
    { return FMars_Validation(f"InteractionTraceDistance [{Self.InteractionTraceDistance}] must be > 0"); }

    if (Self.FieldOfView <= 0.0f || Self.FieldOfView >= 180.0f)
    { return FMars_Validation(f"FieldOfView [{Self.FieldOfView}] is outside (0, 180)"); }

    if (Self.PitchLimits._Min > Self.PitchLimits._Max)
    { return FMars_Validation(f"PitchLimits min [{Self.PitchLimits._Min}] exceeds max [{Self.PitchLimits._Max}]"); }

    if (Self.LookSpeed <= 0.0f)
    { return FMars_Validation(f"LookSpeed [{Self.LookSpeed}] must be > 0"); }

    return FMars_Validation();
}

// Who holds the view still: each keeps its own hold, so one releasing never frees the view another still holds.
enum EMars_PlayerViewpoint_ViewHolder
{
    // A gripped control: the look input pulls it.
    ControlPull,
    // The emote wheel: the look input steers its pointer.
    EmoteWheel,
    // A station whose look control is captured: the station reads the look input.
    Station
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Camera and Viewpoint are set once at Add; the trace rides the anchor every frame. Written only by Add and
// UMars_Processor_PlayerViewpoint_HandleRequests.
struct FMars_Fragment_PlayerViewpoint
{
    UPROPERTY()
    FCk_Handle_Camera Camera;

    // The director's view anchor: where the view renders this frame, composed in the same frame.
    UPROPERTY()
    FCk_Handle_Transform Viewpoint;

    UPROPERTY()
    FCk_Handle_ProbeTrace InteractionTrace;

    // A set: the camera's orientation follows the look input while it is empty.
    UPROPERTY()
    TArray<EMars_PlayerViewpoint_ViewHolder> ViewHolders;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Holds the view still for InHolder until it releases. Holding a held holder changes nothing.
struct FMars_Request_PlayerViewpoint_HoldView
{
    UPROPERTY()
    EMars_PlayerViewpoint_ViewHolder Holder = EMars_PlayerViewpoint_ViewHolder::ControlPull;

    FMars_Request_PlayerViewpoint_HoldView() {}

    FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder InHolder)
    {
        Holder = InHolder;
    }
}

// Releases InHolder's hold. Releasing a holder that does not hold changes nothing.
struct FMars_Request_PlayerViewpoint_ReleaseView
{
    UPROPERTY()
    EMars_PlayerViewpoint_ViewHolder Holder = EMars_PlayerViewpoint_ViewHolder::ControlPull;

    FMars_Request_PlayerViewpoint_ReleaseView() {}

    FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder InHolder)
    {
        Holder = InHolder;
    }
}

enum EMars_PlayerViewpoint_ViewHoldChange
{
    Hold,
    Release
}

// A Hold or a Release, queued with the other kind so the drain sees them in arrival order.
struct FMars_PlayerViewpoint_ViewHoldRequest
{
    UPROPERTY()
    EMars_PlayerViewpoint_ViewHoldChange Change = EMars_PlayerViewpoint_ViewHoldChange::Hold;

    UPROPERTY()
    EMars_PlayerViewpoint_ViewHolder Holder = EMars_PlayerViewpoint_ViewHolder::ControlPull;

    FMars_PlayerViewpoint_ViewHoldRequest() {}

    FMars_PlayerViewpoint_ViewHoldRequest(EMars_PlayerViewpoint_ViewHoldChange InChange, EMars_PlayerViewpoint_ViewHolder InHolder)
    {
        Change = InChange;
        Holder = InHolder;
    }
}

struct FMars_Fragment_PlayerViewpoint_Requests
{
    UPROPERTY()
    TArray<FMars_PlayerViewpoint_ViewHoldRequest> ViewHoldRequests;
}
