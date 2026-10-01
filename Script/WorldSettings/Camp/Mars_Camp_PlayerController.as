class UMars_Camp_CheatManager : UMars_Gameplay_CheatManager
{
    // Console: Mars_Camp_Play - the Play button's path, for smoke tests before the menu exists.
    UFUNCTION(Exec)
    void Mars_Camp_Play()
    {
        auto PC = Cast<AMars_Camp_PlayerController>(GetPlayerController());
        if (ck::IsValid(PC))
        { PC.Server_RequestPlay(); }
    }
}

// Camp front-end controller. Client-local: the menu camera tour (Request_FocusStation) and the gameplay input
// profile once a chef is possessed. Server: Server_RequestPlay. Input MODE is owned by the CkUI layout (the Menu
// layer is UIOnly while the menu is up) - no SetInputMode here (design section 4).
class AMars_Camp_PlayerController : AMars_Master_PlayerController
{
    default CheatClass = UMars_Camp_CheatManager;

    UPROPERTY(DefaultComponent)
    UMars_InputComponent InputComp;

    private TArray<AMars_CampStationCamera> _StationCameras;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        Super::BeginPlay();

        if (IsLocalController() == false)
        { return; }

        // The first focus happens on possession, never before a pawn exists: the handler covers a possession that
        // comes after BeginPlay (standalone LoadMap), the direct call below one that came before it.
        OnPossessedPawnChanged.AddUFunction(this, n"HandlePossessedPawnChanged");

        // PIE possesses the local pawn before BeginPlay; standalone possesses after. Cover the first case here, the second in the handler.
        if (ck::IsValid(ControlledPawn))
        { HandlePossessedPawnChanged(nullptr, ControlledPawn); }
    }

    UFUNCTION()
    UMars_InputComponent Get_InputStack() const
    { return InputComp; }

    // Blends the local view to a station camera. Cameras are gathered once (level content, static).
    UFUNCTION()
    void Request_FocusStation(EMars_CampStation InStation, float32 InBlendSeconds = 0.6f)
    {
        if (IsLocalController() == false)
        { return; }

        if (_StationCameras.IsEmpty())
        { GetAllActorsOfClass(_StationCameras); }

        auto Camera = utils_camp_station::TryGet_Camera(_StationCameras, InStation);
        if (ck::EnsureIfNot(ck::IsValid(Camera), f"[Mars_Camp_PlayerController] no AMars_CampStationCamera for station [{InStation}] in this map"))
        { return; }

        SetViewTargetWithBlend(Camera, InBlendSeconds, EViewTargetBlendFunction::VTBlend_EaseInOut, 2.0f, false);
    }

    UFUNCTION(Server)
    void Server_RequestPlay()
    {
        auto CampState = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::Is_NOT_Valid(CampState) || ck::Is_NOT_Valid(CampState.Get_CampSession()))
        { return; }

        auto Session = CampState.Get_CampSession();
        Session.Request_Play();
    }

    UFUNCTION()
    private void HandlePossessedPawnChanged(APawn OldPawn, APawn NewPawn)
    {
        if (ck::Is_NOT_Valid(NewPawn))
        { return; }

        if (ck::IsValid(Cast<AMars_Camp_ViewerPawn>(NewPawn)))
        {
            Request_FocusStation(EMars_CampStation::Title, 0.0f);
            return;
        }

        if (ck::IsValid(Cast<AMars_PlayerCharacter>(NewPawn)))
        { TryActivateGameplayInputs(InputComp, NewPawn); }
    }
}
