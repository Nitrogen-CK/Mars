//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_MechanismDriverHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_MechanismDriver";
    RequiredFragments.Add(FMars_Feature_MechanismDriver);
    Description = "Per-world singleton that tracks every mechanism source and sink and pushes per-channel input counts to sinks";
}
struct FMars_Feature_MechanismDriver {}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_MechanismDriver
{
    UPROPERTY()
    TSet<FCk_Handle_MechanismSource> Sources;

    UPROPERTY()
    TSet<FCk_Handle_MechanismSink> Sinks;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_MechanismDriver_TrackSource
{
    UPROPERTY()
    FCk_Handle_MechanismSource Source;

    FMars_Request_MechanismDriver_TrackSource() {}

    FMars_Request_MechanismDriver_TrackSource(FCk_Handle_MechanismSource InSource)
    {
        Source = InSource;
    }
}

// The source may already be gone: untracking a destroyed source is how the driver forgets it.
struct FMars_Request_MechanismDriver_UntrackSource
{
    UPROPERTY()
    FCk_Handle_MechanismSource Source;

    FMars_Request_MechanismDriver_UntrackSource() {}

    FMars_Request_MechanismDriver_UntrackSource(FCk_Handle_MechanismSource InSource)
    {
        Source = InSource;
    }
}

struct FMars_Request_MechanismDriver_TrackSink
{
    UPROPERTY()
    FCk_Handle_MechanismSink Sink;

    FMars_Request_MechanismDriver_TrackSink() {}

    FMars_Request_MechanismDriver_TrackSink(FCk_Handle_MechanismSink InSink)
    {
        Sink = InSink;
    }
}

// The sink may already be gone, as for UntrackSource.
struct FMars_Request_MechanismDriver_UntrackSink
{
    UPROPERTY()
    FCk_Handle_MechanismSink Sink;

    FMars_Request_MechanismDriver_UntrackSink() {}

    FMars_Request_MechanismDriver_UntrackSink(FCk_Handle_MechanismSink InSink)
    {
        Sink = InSink;
    }
}

struct FMars_Request_MechanismDriver_Recompute
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_MechanismDriver_Recompute() {}
}

// Drained untracks first, then tracks, then one full recompute if anything changed or a recompute is pending.
struct FMars_Fragment_MechanismDriver_Requests
{
    UPROPERTY()
    TArray<FMars_Request_MechanismDriver_TrackSource> TrackSourceRequests;

    UPROPERTY()
    TArray<FMars_Request_MechanismDriver_UntrackSource> UntrackSourceRequests;

    UPROPERTY()
    TArray<FMars_Request_MechanismDriver_TrackSink> TrackSinkRequests;

    UPROPERTY()
    TArray<FMars_Request_MechanismDriver_UntrackSink> UntrackSinkRequests;

    // Coalescing: any number of recompute requests before the drain produce one pass.
    UPROPERTY()
    TArray<FMars_Request_MechanismDriver_Recompute> RecomputeRequests;
}
