// Level-placed view point for one camp station. AMars_Camp_PlayerController blends the local view between these
// (Request_FocusStation); Mars.Camp.Build places one per EMars_CampStation. Not under Script/Editor (trap 33).
class AMars_CampStationCamera : ACameraActor
{
    UPROPERTY(EditAnywhere, Category = "Camp")
    EMars_CampStation Station = EMars_CampStation::Title;
}
