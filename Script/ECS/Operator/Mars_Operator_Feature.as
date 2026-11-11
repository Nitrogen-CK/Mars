// Stance A, following its host: the back-ref (FMars_Fragment_Operator) replicates and is written only by the station
// arbiter on the authority; a client reads the authority's answer. Leaving goes through the held station's Act cue.

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
    // Written ONLY by UMars_Processor_Station_HandleRequests on the authority (and its destroy watches), marked dirty with
    // each write, in the same call as the station's
    // own Operator, so both ends of the link change in one drain and a same-tick double reserve (two stations, one
    // operator; or two operators, one station) cannot interleave. Nothing else writes it.
    UPROPERTY()
    FCk_Handle_Station Station;

    // Station is meaningful only while this says Operated (a replicated handle cleared on the authority keeps its old
    // value on a client).
    UPROPERTY()
    EMars_Station_Occupancy Occupancy = EMars_Station_Occupancy::Free;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Payload-less: one placeholder field (request doctrine). Forwarded at once as a scoped release to the held station.
struct FMars_Request_Operator_Leave
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Operator_Leave() {}
}
