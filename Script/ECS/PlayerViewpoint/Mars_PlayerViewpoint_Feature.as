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

// InteractionTraceDistance is consumed at Add (it shapes the trace); the Camera block builds the director's resting profile.
struct FMars_PlayerViewpoint_Spec
{
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

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Loose fragment - no processor. Camera and Viewpoint are set once at Add; the trace rides the anchor every frame.
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
