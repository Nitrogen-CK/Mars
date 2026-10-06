enum EMars_CampStation
{
    Title,
    Cauldron,
    Departure,
    Backpack,
    Wardrobe,
    Guests,
    Contracts,
    Workbench,
    // The vestibule's world boards. Append only: station values are serialized in the camp map.
    FrontendHost,
    FrontendJoin,
    FrontendSettings,
    FrontendQuit
}

namespace utils_camp_station
{
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
