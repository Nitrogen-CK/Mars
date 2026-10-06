// Front-end mode for Camp_Mars_MAP (assigned by the Camp_Mars_ prefix in DefaultEngine.ini). Lobby: everyone
// holds a viewer pawn. Live: everyone is restarted as a chef; late joiners spawn as chefs directly through
// GetDefaultPawnClassForController.
class AMars_Camp_GameMode : AMars_Master_GameMode
{
    default GameStateClass = AMars_Camp_GameState;
    default PlayerControllerClass = AMars_Camp_PlayerController;
    default PlayerStateClass = AMars_Gameplay_PlayerState;
    default DefaultPawnClass = AMars_Camp_ViewerPawn;
    default HUDClass = AMars_Camp_HUD;
    default GameSessionClass = AMars_GameSession;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        // No script ancestor defines BeginPlay (Super:: does not resolve); AGameModeBase::GameState is not
        // Blueprint-visible, so read it through Gameplay::GetGameState() (spawned in PreInitializeComponents).
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
        auto CampState = Get_CampState();
        if (ck::Is_NOT_Valid(CampState))
        { return; }

        auto Session = CampState.Get_CampSession();
        if (ck::EnsureIfNot(ck::IsValid(Session), "[Mars_Camp_GameMode] the camp GameState has no CampSession"))
        { return; }

        Session.BindTo_OnPhaseChanged(FMars_Delegate_CampSession_OnPhaseChanged(this, n"OnPhaseChanged"));

        // Hosting is established by actual listen travel. A standalone menu never becomes a host by changing phase.
        if (GetWorld().GetNetMode() == ENetMode::NM_ListenServer)
        {
            auto Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
            if (ck::IsValid(Flow) && ck::IsValid(CampState.ServiceCatalog) &&
                ck::IsValid(CampState.ServiceCatalog.Find(Flow.GetCommittedServiceId())))
            { CampState.Apply_PartyState(Flow.GetCommittedServiceId(), EMars_PartyDeparture::Staying); }
            Session.Request_Play();
        }
    }

    bool TryCommitService(AMars_Camp_PlayerController InRequester, FName InServiceId)
    {
        if (IsHostRequest(InRequester) == false || Get_IsLive() == false)
        { return false; }

        auto State = Get_CampState();
        auto Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        if (ck::Is_NOT_Valid(State) || ck::Is_NOT_Valid(State.ServiceCatalog) || ck::Is_NOT_Valid(Flow) ||
            Flow.GetState() != EMars_LanFlowState::Connected || State.Get_PartyState().IsDeparting ||
            ck::Is_NOT_Valid(State.ServiceCatalog.Find(InServiceId)))
        { return false; }

        Flow.SetCommittedServiceId(InServiceId);
        State.Apply_PartyState(InServiceId, EMars_PartyDeparture::Staying);
        return true;
    }

    bool TryDepart(AMars_Camp_PlayerController InRequester)
    {
        if (IsHostRequest(InRequester) == false || Get_IsLive() == false)
        { return false; }

        auto State = Get_CampState();
        auto Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        if (ck::Is_NOT_Valid(State) || ck::Is_NOT_Valid(State.ServiceCatalog) || ck::Is_NOT_Valid(Flow) ||
            Flow.GetState() != EMars_LanFlowState::Connected)
        { return false; }

        const auto Party = State.Get_PartyState();
        auto Service = State.ServiceCatalog.Find(Party.ServiceId);
        if (Party.IsDeparting || ck::Is_NOT_Valid(Service) || Service.Destination.IsNull())
        { return false; }

        TArray<AMars_GameSession> Sessions;
        GetAllActorsOfClass(Sessions);
        if (Sessions.Num() != 1)
        { return false; }

        // Close before queueing travel. ApproveLogin rechecks this for pending logins as well as new arrivals.
        Sessions[0].SetAdmissionOpen(false);
        State.Apply_PartyState(Party.ServiceId, EMars_PartyDeparture::Departing);
        if (Flow.RequestServerTravel(Service.Destination, EMars_LanFlowTravel::DepartCamp))
        { return true; }

        Sessions[0].SetAdmissionOpen(true);
        State.Apply_PartyState(Party.ServiceId, EMars_PartyDeparture::Staying);
        return false;
    }

    private bool IsHostRequest(AMars_Camp_PlayerController InRequester) const
    {
        return HasAuthority() && ck::IsValid(InRequester) && InRequester.GetWorld() == GetWorld() &&
            InRequester.IsLocalController() && GetWorld().GetNetMode() == ENetMode::NM_ListenServer;
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_CampSession InSession, EMars_CampPhase InPrevious, EMars_CampPhase InNew)
    {
        if (InNew != EMars_CampPhase::Live)
        { return; }

        SpawnChefsForEveryone();
    }

    private AMars_Camp_GameState Get_CampState() const
    {
        auto CampState = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::EnsureIfNot(ck::IsValid(CampState), "[Mars_Camp_GameMode] the GameState is not an AMars_Camp_GameState"))
        { return nullptr; }
        return CampState;
    }

    private bool Get_IsLive() const
    {
        auto CampState = Get_CampState();
        if (ck::Is_NOT_Valid(CampState))
        { return false; }

        // Before the GameState's entity is composed there is no session yet: still the lobby.
        auto Session = CampState.Get_CampSession();
        if (ck::Is_NOT_Valid(Session))
        { return false; }

        return Session.Get_IsLive();
    }

    // RestartPlayer keeps an existing pawn: drop the viewer pawn first.
    private void SpawnChefsForEveryone()
    {
        // Seamless travel replaces player controllers without PostLogin, so the game-instance
        // session registry can still point at controllers from the previous world here.
        TArray<AMars_Camp_PlayerController> Controllers;
        GetAllActorsOfClass(Controllers);
        for (auto PC : Controllers)
        {
            if (ck::Is_NOT_Valid(PC) || PC.GetWorld() != GetWorld() || PC.HasAuthority() == false)
            { continue; }

            if (ck::IsValid(Cast<AMars_PlayerCharacter>(PC.GetControlledPawn())))
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
