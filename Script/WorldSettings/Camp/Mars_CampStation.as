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
    // The one enabled station camera (a plain camera or a menu board station) for InStation in InWorld; ensures there is
    // exactly one. Disabled cameras are authoring backups.
    AMars_CampStationCamera TryGet_Camera(UWorld InWorld, EMars_CampStation InStation)
    {
        AMars_CampStationCamera Result;
        int32 Matches = 0;
        for (auto Actor : utils_actor::Get_AllActorsOfClass(AMars_CampStationCamera))
        {
            auto Camera = Cast<AMars_CampStationCamera>(Actor);
            if (ck::IsValid(Camera) && Camera.bStationEnabled && Camera.GetWorld() == InWorld && Camera.Station == InStation)
            {
                Result = Camera;
                ++Matches;
            }
        }

        if (ck::EnsureIfNot(Matches == 1, f"[CampStation] expected exactly one enabled camera for station [{InStation}], found [{Matches}]"))
        { return nullptr; }

        return Result;
    }

    // The one board anchor for InStation in InWorld; ensures there is exactly one.
    AMars_CampBoardAnchor TryGet_BoardAnchor(UWorld InWorld, EMars_CampStation InStation)
    {
        AMars_CampBoardAnchor Result;
        int32 Matches = 0;
        for (auto Actor : utils_actor::Get_AllActorsOfClass(AMars_CampBoardAnchor))
        {
            auto Anchor = Cast<AMars_CampBoardAnchor>(Actor);
            if (ck::IsValid(Anchor) && Anchor.GetWorld() == InWorld && Anchor.Station == InStation)
            {
                Result = Anchor;
                ++Matches;
            }
        }

        if (ck::EnsureIfNot(Matches == 1, f"[CampStation] expected exactly one board anchor for station [{InStation}], found [{Matches}]"))
        { return nullptr; }

        return Result;
    }
}
