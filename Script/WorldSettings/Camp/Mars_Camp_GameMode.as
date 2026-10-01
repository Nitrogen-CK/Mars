// Front-end mode for Camp_Mars_MAP (assigned by the Camp_Mars_ prefix in DefaultEngine.ini). Lobby: everyone
// holds a viewer pawn. Live: everyone is restarted as a chef (design D5); late joiners spawn as chefs directly
// through GetDefaultPawnClassForController.
class AMars_Camp_GameMode : AMars_Master_GameMode
{
    default GameStateClass = AMars_Camp_GameState;
    default PlayerControllerClass = AMars_Camp_PlayerController;
    default PlayerStateClass = AMars_Gameplay_PlayerState;
    default DefaultPawnClass = AMars_Camp_ViewerPawn;
    default HUDClass = AMars_Camp_HUD;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        // No script ancestor defines BeginPlay (Super:: does not resolve); AGameModeBase::GameState is not
        // Blueprint-visible, so read it through Gameplay::GetGameState() (spawned in PreInitializeComponents).
        // Composed, not merely linked: the EcsReady promise fires before EcsConstructionScript on authority.
        auto MasterState = Cast<AMars_Master_GameState>(Gameplay::GetGameState());
        if (ck::EnsureIfNot(ck::IsValid(MasterState), "[Mars_Camp_GameMode] the GameState is not an AMars_Master_GameState"))
        { return; }

        MasterState.Promise_OnEcsComposed(FMars_Delegate_GameState_OnEcsComposed(this, n"OnGameStateEcsComposed"));
    }

    UFUNCTION(BlueprintOverride)
    UClass GetDefaultPawnClassForController(AController InController)
    {
        if (Get_IsLive())
        { return AMars_PlayerCharacter; }

        return AMars_Camp_ViewerPawn;
    }

    UFUNCTION()
    private void OnGameStateEcsComposed(FCk_Handle InEntity)
    {
        auto CampState = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::EnsureIfNot(ck::IsValid(CampState), "[Mars_Camp_GameMode] the GameState is not an AMars_Camp_GameState"))
        { return; }

        auto Session = CampState.Get_CampSession();
        if (ck::EnsureIfNot(ck::IsValid(Session), "[Mars_Camp_GameMode] the camp GameState has no CampSession"))
        { return; }

        Session.BindTo_OnPhaseChanged(FMars_Delegate_CampSession_OnPhaseChanged(this, n"OnPhaseChanged"));
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_CampSession InSession, EMars_CampPhase InPrevious, EMars_CampPhase InNew)
    {
        if (InNew != EMars_CampPhase::Live)
        { return; }

        SpawnChefsForEveryone();
    }

    private bool Get_IsLive() const
    {
        auto CampState = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::Is_NOT_Valid(CampState) || ck::Is_NOT_Valid(CampState.Get_CampSession()))
        { return false; }

        return CampState.Get_CampSession().Get_IsLive();
    }

    // RestartPlayer keeps an existing pawn (trap 27): drop the viewer pawn first.
    private void SpawnChefsForEveryone()
    {
        auto GameSession = Subsystem::GetGameInstanceSubsystem(UCk_GameSession_Subsystem_UE);
        if (ck::EnsureIfNot(ck::IsValid(GameSession), "[Mars_Camp_GameMode] no CkGameSession subsystem"))
        { return; }

        for (auto PC : GameSession.Get_AllPlayerControllers())
        {
            if (ck::Is_NOT_Valid(PC))
            { continue; }

            auto Viewer = Cast<AMars_Camp_ViewerPawn>(PC.GetControlledPawn());
            if (ck::IsValid(Viewer))
            {
                PC.UnPossess();
                Viewer.DestroyActor();
            }

            RestartPlayer(PC);
        }
    }
}
