// Level-placed view point for one camp station. AMars_Camp_PlayerController blends the local view between these
// (FocusStation); Mars.Camp.Build places one per EMars_CampStation. Not under Script/Editor: that code is editor-only,
// and the camp map needs this class at runtime.
class AMars_CampStationCamera : ACameraActor
{
    UPROPERTY(EditAnywhere, Category = "Camp")
    EMars_CampStation Station = EMars_CampStation::Title;
}
