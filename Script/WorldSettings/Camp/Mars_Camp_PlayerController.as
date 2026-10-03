class UMars_Camp_CheatManager : UMars_Gameplay_CheatManager
{
    // Console: Mars_Camp_Play - the Play button's path, for smoke tests.
    UFUNCTION(Exec)
    void Mars_Camp_Play()
    {
        auto PC = Cast<AMars_Camp_PlayerController>(GetPlayerController());
        if (ck::EnsureIfNot(ck::IsValid(PC), "[Mars_Camp_CheatManager] its PlayerController is not an AMars_Camp_PlayerController"))
        { return; }

        PC.Server_RequestPlay();
    }
}

// Camp front-end controller. Client-local: the menu camera tour (FocusStation) and the gameplay input profile once a chef
// is possessed. Server: Server_RequestPlay. Input MODE is owned by the CkUI layout (the Menu layer is UIOnly while the
// menu is up), so there is no SetInputMode here.
class AMars_Camp_PlayerController : AMars_Master_PlayerController
{
    default CheatClass = UMars_Camp_CheatManager;

    private TArray<AMars_CampStationCamera> _StationCameras;

    // Blends the local view to a station camera, starting now. Cameras are level content, gathered once.
    UFUNCTION()
    void FocusStation(EMars_CampStation InStation, float32 InBlendSeconds = 0.6f)
    {
        if (ck::EnsureIfNot(IsLocalController(), f"[Mars_Camp_PlayerController] FocusStation [{InStation}] drives the local view; call it on the local controller"))
        { return; }

        if (_StationCameras.IsEmpty())
        { GetAllActorsOfClass(_StationCameras); }

        auto Camera = utils_camp_station::TryGet_Camera(_StationCameras, InStation);
        if (ck::EnsureIfNot(ck::IsValid(Camera), f"[Mars_Camp_PlayerController] no AMars_CampStationCamera for station [{InStation}] in this map"))
        { return; }

        const float32 BlendExponent = 2.0f;
        const bool LockOutgoing = false;
        SetViewTargetWithBlend(Camera, InBlendSeconds, EViewTargetBlendFunction::VTBlend_EaseInOut, BlendExponent, LockOutgoing);
    }

    UFUNCTION(Server)
    void Server_RequestPlay()
    {
        auto CampState = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::EnsureIfNot(ck::IsValid(CampState), "[Mars_Camp_PlayerController] the GameState is not an AMars_Camp_GameState"))
        { return; }

        // Before the GameState's entity is composed there is no session to start yet.
        auto Session = CampState.Get_CampSession();
        if (ck::Is_NOT_Valid(Session))
        { return; }

        Session.Request_Play();
    }

    protected void OnLocalPawnPossessed(APawn InPawn) override
    {
        if (ck::IsValid(Cast<AMars_Camp_ViewerPawn>(InPawn)))
        {
            FocusStation(EMars_CampStation::Title, 0.0f);
            return;
        }

        if (ck::IsValid(Cast<AMars_PlayerCharacter>(InPawn)))
        { TryActivateGameplayInputs(InPawn); }
    }
}
