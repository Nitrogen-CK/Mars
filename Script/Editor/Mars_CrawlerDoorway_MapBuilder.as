#if EDITOR
UFUNCTION()
void Mars_BuildCrawlerDoorwayFunc(const TArray<FString>& Args)
{
    const FString MapPath = "/Game/Mars/Maps/CrawlerDoorway_Mars_MAP";
    auto World = utils_mars_map_builder::TryGet_UntitledWorld("Mars.CrawlerDoorway.Build", MapPath);
    if (ck::Is_NOT_Valid(World))
    { return; }
    utils_mars_map_builder::Spawn_EntityScript(UMars_CrawlerDoorway_EntityScript,
        FMars_MapBuilder_Placement("Doorway_Prototype_8_Legs", FVector(-340.0, 0.0, 270.0)));
    utils_mars_map_builder::Spawn_DaylightRig();
    UEditorActorSubsystem::Get().SpawnActorFromClass(APlayerStart, FVector(850.0, 0.0, 150.0), FRotator(-4.0, 180.0, 0.0));
    utils_mars_map_builder::SaveWorld(World, MapPath);
    ck::Trace("[Doorway] Isolated map created. PIE runs the audited crossing and safe return in a loop.");
}

const FConsoleCommand Mars_BuildCrawlerDoorwayCommand("Mars.CrawlerDoorway.Build", n"Mars_BuildCrawlerDoorwayFunc");
#endif

// Keep the existing input/movement setup, without opening the switchboard's input-consuming overlay.
class AMars_CrawlerDoorway_PlayerController : ACk_Gym_Base_PlayerController
{
    void Request_StartGym() override {}
}

// Use the existing free-flying gym pawn, without the gym cycler's startup map redirect.
class AMars_CrawlerDoorway_GameMode : ACk_GameMode_UE
{
    default PlayerControllerClass = AMars_CrawlerDoorway_PlayerController;
    default DefaultPawnClass = ACk_Gym_Base_Pawn;
}
