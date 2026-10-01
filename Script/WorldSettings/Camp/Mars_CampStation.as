// One entry per camp station (design section 6). Title and Cauldron are camera-only stations.
enum EMars_CampStation
{
    Title,
    Cauldron,
    Departure,
    Backpack,
    Wardrobe,
    Guests,
    Contracts,
    Workbench
}

namespace utils_camp_station
{
    // The placed camera for a station, or null. Cameras are level content; callers gather them once with GetAllActorsOfClass.
    AMars_CampStationCamera TryGet_Camera(const TArray<AMars_CampStationCamera>& InCameras, EMars_CampStation InStation)
    {
        for (auto Camera : InCameras)
        {
            if (ck::IsValid(Camera) && Camera.Station == InStation)
            { return Camera; }
        }

        return nullptr;
    }
}
