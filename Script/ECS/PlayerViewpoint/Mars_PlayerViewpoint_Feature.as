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

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// No processor: Camera and Viewpoint are set once at Add; the trace rides the anchor every frame.
struct FMars_Fragment_PlayerViewpoint
{
    UPROPERTY()
    FCk_Handle_Camera Camera;

    // The director's view anchor: where the view renders this frame, composed in the same frame.
    UPROPERTY()
    FCk_Handle_Transform Viewpoint;

    UPROPERTY()
    FCk_Handle_ProbeTrace InteractionTrace;
}
