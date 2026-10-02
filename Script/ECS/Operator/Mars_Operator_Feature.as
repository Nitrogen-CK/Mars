//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_OperatorHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Operator";
    RequiredFragments.Add(FMars_Feature_Operator);
    Description = "An entity that can operate a station: the station it holds, kept by the station arbiter (lives on the player)";
}
struct FMars_Feature_Operator {}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The busy state IS this back-ref: operating <=> Station is valid.
struct FMars_Fragment_Operator
{
    // Written ONLY by UMars_Processor_Station_HandleRequests (and its destroy watches), in the same call as the station's
    // own Operator, so both ends of the link change in one drain and a same-tick double reserve (two stations, one
    // operator; or two operators, one station) cannot interleave. Nothing else writes it.
    UPROPERTY()
    FCk_Handle_Station Station;
}
