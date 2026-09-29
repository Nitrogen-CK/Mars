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

struct FMars_Fragment_MechanismDriver_Requests
{
    UPROPERTY()
    TArray<FCk_Handle_MechanismSource> TrackSources;

    UPROPERTY()
    TArray<FCk_Handle_MechanismSource> UntrackSources;

    UPROPERTY()
    TArray<FCk_Handle_MechanismSink> TrackSinks;

    UPROPERTY()
    TArray<FCk_Handle_MechanismSink> UntrackSinks;

    UPROPERTY()
    bool Recompute = false;
}
