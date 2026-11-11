// Predicts, every frame an aim is requested, the path a throw of the carrier's held item would take: the launch the
// release would make right now (HeldItemUse's launch solution), flown with the item body's own Jolt flight
// (WorldItem's flight body) and swept against the world to the first thing it meets. No bounce. The kernel knows no
// player and no input: whoever composes it decides when to aim, and draws nothing here.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_ThrowPreviewHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_ThrowPreview";
    RequiredFragments.Add(FMars_Feature_ThrowPreview);
    Description = "Predicts the path a throw of the held item would take, while an aim is requested";
}
struct FMars_Feature_ThrowPreview {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_ThrowPreview_Aim
{
    Idle,
    Aiming
}

// How a predicted path ends.
enum EMars_ThrowPreview_End
{
    // There is no path: nothing is aimed, the hands are empty, or the held item has no body to fly as.
    None,
    // The path meets something.
    Surface,
    // The path was still in the air at the Spec's MaxFlightSeconds.
    OutOfRange
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_throw_preview
{
    // What a thrown item's body is blocked by: the object channel world-item bodies are built on.
    const ECollisionChannel k_FlightChannel = ECollisionChannel::ECC_PhysicsBody;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_ThrowPreview_Spec
{
    // How far ahead the flight is predicted.
    UPROPERTY()
    float32 MaxFlightSeconds = 2.5f;

    // Simulation steps per path point and sweep.
    UPROPERTY()
    int32 StepsPerSegment = 3;

    // The smallest sphere a flight is swept with, whatever the item's bounds.
    UPROPERTY()
    float32 MinCastRadius = 4.0f;
}

mixin FMars_Validation Validate(const FMars_ThrowPreview_Spec& Self)
{
    if (Self.MaxFlightSeconds <= 0.0f)
    { return FMars_Validation(f"MaxFlightSeconds must be positive (got {Self.MaxFlightSeconds})"); }

    if (Self.StepsPerSegment < 1)
    { return FMars_Validation(f"StepsPerSegment must be at least 1 (got {Self.StepsPerSegment})"); }

    if (Self.MinCastRadius <= 0.0f)
    { return FMars_Validation(f"MinCastRadius must be positive (got {Self.MinCastRadius})"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_ThrowPreview_Params
{
    UPROPERTY()
    FMars_ThrowPreview_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_ThrowPreview_Landing
{
    UPROPERTY()
    FVector Location = FVector::ZeroVector;

    UPROPERTY()
    FVector Normal = FVector::UpVector;

    // Invalid when what was hit has no entity.
    UPROPERTY()
    FCk_Handle Entity;
}

struct FMars_ThrowPreview_Path
{
    // The item's centre from launch to End, in world space. Empty when End is None.
    UPROPERTY()
    TArray<FVector> Points;

    UPROPERTY()
    EMars_ThrowPreview_End End = EMars_ThrowPreview_End::None;

    // Where and what the path meets; meaningful only when End is Surface.
    UPROPERTY()
    FMars_ThrowPreview_Landing Landing;

    UPROPERTY()
    float32 FlightSeconds = 0.0f;

    // The sphere the flight was swept with.
    UPROPERTY()
    float32 CastRadius = 0.0f;
}

// Written only by UMars_Processor_ThrowPreview_HandleRequests and UMars_Processor_ThrowPreview_Predict.
struct FMars_Fragment_ThrowPreview
{
    UPROPERTY()
    FMars_ThrowPreview_Path Path;
}

// Present exactly while an aim is requested: what the predictor iterates. Named as the other view-filtering tags
// (FMars_Tag_Bat_NeedsSetup).
struct FMars_Tag_ThrowPreview_Aiming {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_ThrowPreview_OnAimChanged(FCk_Handle_ThrowPreview InPreview, EMars_ThrowPreview_Aim InAim);
event void FMars_Delegate_ThrowPreview_OnAimChanged_MC(FCk_Handle_ThrowPreview InPreview, EMars_ThrowPreview_Aim InAim);

// The path was predicted again (every frame while aiming), or cleared.
delegate void FMars_Delegate_ThrowPreview_OnPathUpdated(FCk_Handle_ThrowPreview InPreview);
event void FMars_Delegate_ThrowPreview_OnPathUpdated_MC(FCk_Handle_ThrowPreview InPreview);

struct FMars_Fragment_ThrowPreview_Signals
{
    FMars_Delegate_ThrowPreview_OnAimChanged_MC OnAimChanged;
    FMars_Delegate_ThrowPreview_OnPathUpdated_MC OnPathUpdated;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_ThrowPreview_SetAim
{
    UPROPERTY()
    EMars_ThrowPreview_Aim Aim = EMars_ThrowPreview_Aim::Idle;

    FMars_Request_ThrowPreview_SetAim() {}

    FMars_Request_ThrowPreview_SetAim(EMars_ThrowPreview_Aim InAim)
    {
        Aim = InAim;
    }
}

// Only the last SetAim of a drain applies (see UMars_Processor_ThrowPreview_HandleRequests).
struct FMars_Fragment_ThrowPreview_Requests
{
    UPROPERTY()
    TArray<FMars_Request_ThrowPreview_SetAim> SetAimRequests;
}
