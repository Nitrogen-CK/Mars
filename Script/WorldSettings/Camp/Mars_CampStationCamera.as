// Level-placed view point for one camp station (AMars_Camp_PlayerController::FocusStation). Runtime class, so not
// under Script/Editor even though Mars.Camp.Build places them.
class AMars_CampStationCamera : ACameraActor
{
    UPROPERTY(EditAnywhere, Category = "Camp")
    EMars_CampStation Station = EMars_CampStation::Title;

    // Disabled endpoints can remain in the level as migration/authoring backups.
    UPROPERTY(EditAnywhere, Category = "Camp")
    bool bStationEnabled = true;
}
