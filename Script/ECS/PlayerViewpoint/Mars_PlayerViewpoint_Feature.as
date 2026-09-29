//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PlayerViewpointHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_PlayerViewpoint";
    RequiredFragments.Add(FMars_Feature_PlayerViewpoint);
    Description = "A player's view in ECS: a transform that follows the camera, and the interaction trace cast from it";
}
struct FMars_Feature_PlayerViewpoint {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Consumed at Add (it shapes the trace); not retained.
struct FMars_PlayerViewpoint_Spec
{
    UPROPERTY()
    float32 InteractionTraceDistance = 250.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Loose fragment - no processor. The view is pushed into Viewpoint by the player HFSM's viewpoint
// sync task; the trace rides it.
struct FMars_Fragment_PlayerViewpoint
{
    UPROPERTY()
    FCk_Handle_Transform Viewpoint;

    UPROPERTY()
    FCk_Handle_ProbeTrace InteractionTrace;
}
