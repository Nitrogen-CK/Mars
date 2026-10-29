// Language=angelscript

enum EMars_GauntletHostFlowStage
{
    InitialCamp,
    Hosting,
    InvalidService,
    ServiceCommitted,
    SandboxTravel,
    CampReturn,
    StandaloneRecovery
}

class UMars_GauntletAsTest_HostServiceTravelReturn : UCk_GauntletAsTest_Base
{
    default _RequirePlayerControllerOnInit = true;
    default _TimeoutSeconds = 270.0f;

    protected FName _ServiceId = n"Sandbox";
    protected TSoftObjectPtr<UWorld> _ServiceDestination = assets::Sandbox_Mars_MAP();

    private EMars_GauntletHostFlowStage _Stage = EMars_GauntletHostFlowStage::InitialCamp;
    private float64 _StageStarted = 0.0;
    private float32 _StageTimeout = 15.0f;
    private int32 _InitialRevision = 0;
    private bool _Ended = false;

    UFUNCTION(BlueprintOverride)
    void OnAsInit()
    {
        _StageStarted = Controller.Get_ElapsedTimeSeconds();
        Controller.Request_MarkHeartbeat("[MarsGauntletAs] HostServiceTravelReturn: initial camp");
    }

    UFUNCTION(BlueprintOverride)
    void OnAsPostMapChange()
    {
        Controller.Request_MarkHeartbeat(f"[MarsGauntletAs] HostServiceTravelReturn: map changed in stage [{_Stage}]");
    }

    UFUNCTION(BlueprintOverride)
    void OnAsTick(float DeltaTime)
    {
        if (_Ended)
        { return; }

        if (Controller.Get_ElapsedTimeSeconds() - _StageStarted > _StageTimeout)
        { Fail(f"stage [{_Stage}] timed out"); return; }

        auto Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        if (ck::Is_NOT_Valid(Flow))
        { Fail("LAN flow subsystem is missing"); return; }

        if (_Stage == EMars_GauntletHostFlowStage::InitialCamp)
        { CheckInitialCamp(Flow); }
        else if (_Stage == EMars_GauntletHostFlowStage::Hosting)
        { CheckHostedCamp(Flow); }
        else if (_Stage == EMars_GauntletHostFlowStage::InvalidService)
        { CheckInvalidService(Flow); }
        else if (_Stage == EMars_GauntletHostFlowStage::ServiceCommitted)
        { CheckCommittedService(Flow); }
        else if (_Stage == EMars_GauntletHostFlowStage::SandboxTravel)
        { CheckSandbox(Flow); }
        else if (_Stage == EMars_GauntletHostFlowStage::CampReturn)
        { CheckReturnedCamp(Flow); }
        else if (_Stage == EMars_GauntletHostFlowStage::StandaloneRecovery)
        { CheckStandaloneRecovery(Flow); }
    }

    private void CheckInitialCamp(UMars_LanFlow_Subsystem InFlow)
    {
        auto PC = Cast<AMars_Camp_PlayerController>(Controller.Get_FirstPlayerController());
        if (ck::Is_NOT_Valid(PC) || ck::Is_NOT_Valid(Cast<AMars_Camp_ViewerPawn>(PC.GetControlledPawn())) ||
            PC.GetWorld().GetNetMode() != ENetMode::NM_Standalone ||
            IsMap(PC.GetWorld(), assets::Camp_Mars_MAP()) == false ||
            InFlow.GetState() != EMars_LanFlowState::Idle)
        { return; }

        InFlow.Join("bad/path");
        if (InFlow.GetState() != EMars_LanFlowState::Idle || InFlow.GetLastError().IsSet() == false)
        { Fail("invalid direct address was not rejected without travel"); return; }

        InFlow.Host();
        if (InFlow.GetState() != EMars_LanFlowState::Hosting)
        { Fail("Host did not enter Hosting"); return; }
        Next(EMars_GauntletHostFlowStage::Hosting, 45.0f, "host requested");
    }

    private void CheckHostedCamp(UMars_LanFlow_Subsystem InFlow)
    {
        auto PC = Cast<AMars_Camp_PlayerController>(Controller.Get_FirstPlayerController());
        if (ck::Is_NOT_Valid(PC) || PC.GetWorld().GetNetMode() != ENetMode::NM_ListenServer ||
            IsMap(PC.GetWorld(), assets::Camp_Mars_MAP()) == false ||
            ck::Is_NOT_Valid(Cast<AMars_PlayerCharacter>(PC.GetControlledPawn())) ||
            InFlow.GetState() != EMars_LanFlowState::Connected)
        { return; }

        auto State = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::Is_NOT_Valid(State))
        { Fail("hosted camp has no Camp GameState"); return; }
        const auto Party = State.Get_PartyState();
        if (!Party.ServiceId.IsNone() || Party.Departure == EMars_PartyDeparture::Departing || !InFlow.GetCommittedServiceId().IsNone())
        { Fail("new host has stale party service state"); return; }

        TArray<AMars_GameSession> Sessions;
        GetAllActorsOfClass(Sessions);
        if (Sessions.Num() != 1 || !Sessions[0].IsAdmissionOpen())
        { Fail("hosted camp admission is not open"); return; }

        if (CheckHostedPresentation(PC) == false)
        { return; }

        _InitialRevision = Party.Revision;
        PC.Server_CommitService(n"NotAService");
        Next(EMars_GauntletHostFlowStage::InvalidService, 5.0f, "invalid service submitted");
    }

    private void CheckInvalidService(UMars_LanFlow_Subsystem InFlow)
    {
        // This stage runs on the frame after the RPC, so a deferred server call has also executed.
        auto State = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        auto PC = Cast<AMars_Camp_PlayerController>(Controller.Get_FirstPlayerController());
        if (ck::Is_NOT_Valid(State) || ck::Is_NOT_Valid(PC))
        { Fail("hosted camp disappeared while checking invalid service"); return; }
        const auto Party = State.Get_PartyState();
        if (!Party.ServiceId.IsNone() || Party.Revision != _InitialRevision ||
            !InFlow.GetCommittedServiceId().IsNone())
        { Fail("unknown service changed the committed party state"); return; }

        PC.Server_CommitService(_ServiceId);
        Next(EMars_GauntletHostFlowStage::ServiceCommitted, 10.0f, f"{_ServiceId} service submitted");
    }

    private void CheckCommittedService(UMars_LanFlow_Subsystem InFlow)
    {
        auto State = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        auto PC = Cast<AMars_Camp_PlayerController>(Controller.Get_FirstPlayerController());
        if (ck::Is_NOT_Valid(State) || ck::Is_NOT_Valid(PC))
        { Fail("hosted camp disappeared while committing service"); return; }
        const auto Party = State.Get_PartyState();
        if (Party.ServiceId != _ServiceId)
        { return; }
        if (Party.Revision != _InitialRevision + 1 || Party.Departure == EMars_PartyDeparture::Departing ||
            InFlow.GetCommittedServiceId() != _ServiceId)
        { Fail(f"{_ServiceId} commit has inconsistent service or revision"); return; }

        TArray<AMars_GameSession> Sessions;
        GetAllActorsOfClass(Sessions);
        if (Sessions.Num() != 1 || !Sessions[0].IsAdmissionOpen())
        { Fail("admission closed before departure"); return; }

        if (CheckCommittedPresentation(PC) == false)
        { return; }

        PC.Server_RequestDepart();
        const auto DepartingParty = State.Get_PartyState();
        if (DepartingParty.Departure != EMars_PartyDeparture::Departing || DepartingParty.Revision != _InitialRevision + 2 ||
            Sessions[0].IsAdmissionOpen())
        { Fail("departure did not immediately close admission and advance party revision"); return; }
        Next(EMars_GauntletHostFlowStage::SandboxTravel, 45.0f, "departure requested");
    }

    private void CheckSandbox(UMars_LanFlow_Subsystem InFlow)
    {
        auto PC = Controller.Get_FirstPlayerController();
        if (ck::Is_NOT_Valid(PC))
        { return; }
        auto CurrentWorld = PC.GetWorld();
        if (IsMap(CurrentWorld, assets::Camp_Mars_MAP()))
        {
            auto State = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
            TArray<AMars_GameSession> Sessions;
            GetAllActorsOfClass(Sessions);
            if (ck::Is_NOT_Valid(State) || Sessions.Num() != 1)
            { Fail("departing camp lost party state or GameSession"); return; }
            const auto Party = State.Get_PartyState();
            if (Party.Departure == EMars_PartyDeparture::Departing)
            {
                if (Sessions[0].IsAdmissionOpen() || Party.Revision != _InitialRevision + 2)
                { Fail("admission stayed open or departure revision did not advance"); }
            }
            return;
        }
        if (CurrentWorld.GetNetMode() != ENetMode::NM_ListenServer ||
            IsMap(CurrentWorld, _ServiceDestination) == false ||
            ck::Is_NOT_Valid(Cast<AMars_Gameplay_PlayerController>(PC)) ||
            ck::Is_NOT_Valid(Cast<AMars_PlayerCharacter>(PC.GetControlledPawn())) ||
            InFlow.GetState() != EMars_LanFlowState::Connected)
        { return; }
        if (InFlow.GetCommittedServiceId() != _ServiceId)
        { Fail(f"service selection did not survive {_ServiceId} travel"); return; }

        TArray<AMars_GameSession> Sessions;
        GetAllActorsOfClass(Sessions);
        if (Sessions.Num() != 1 || Sessions[0].GetWorld() != CurrentWorld || Sessions[0].IsAdmissionOpen())
        { Fail("service-world admission is not closed"); return; }

        Cast<AMars_Gameplay_PlayerController>(PC).Server_ReturnToCamp();
        Next(EMars_GauntletHostFlowStage::CampReturn, 45.0f, "return to camp requested");
    }

    private void CheckReturnedCamp(UMars_LanFlow_Subsystem InFlow)
    {
        auto PC = Cast<AMars_Camp_PlayerController>(Controller.Get_FirstPlayerController());
        if (ck::Is_NOT_Valid(PC) || PC.GetWorld().GetNetMode() != ENetMode::NM_ListenServer ||
            IsMap(PC.GetWorld(), assets::Camp_Mars_MAP()) == false)
        { return; }
        if (ck::Is_NOT_Valid(Cast<AMars_PlayerCharacter>(PC.GetControlledPawn())) ||
            InFlow.GetState() != EMars_LanFlowState::Connected)
        { return; }
        auto State = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::Is_NOT_Valid(State) || State.Get_PartyState().ServiceId != _ServiceId ||
            State.Get_PartyState().Departure == EMars_PartyDeparture::Departing || InFlow.GetCommittedServiceId() != _ServiceId)
        { Fail("returned camp did not restore committed service"); return; }

        TArray<AMars_GameSession> Sessions;
        GetAllActorsOfClass(Sessions);
        if (Sessions.Num() != 1 || Sessions[0].GetWorld() != PC.GetWorld() || !Sessions[0].IsAdmissionOpen())
        { Fail("returned camp admission is not open"); return; }

        if (CheckReturnedPresentation(PC) == false)
        { return; }

        InFlow.ReturnToMenu();
        Next(EMars_GauntletHostFlowStage::StandaloneRecovery, 45.0f, "leaving session");
    }

    private void CheckStandaloneRecovery(UMars_LanFlow_Subsystem InFlow)
    {
        auto PC = Cast<AMars_Camp_PlayerController>(Controller.Get_FirstPlayerController());
        if (ck::Is_NOT_Valid(PC) || PC.GetWorld().GetNetMode() != ENetMode::NM_Standalone ||
            IsMap(PC.GetWorld(), assets::Camp_Mars_MAP()) == false ||
            ck::Is_NOT_Valid(Cast<AMars_Camp_ViewerPawn>(PC.GetControlledPawn())) ||
            InFlow.GetState() != EMars_LanFlowState::Idle)
        { return; }
        if (!InFlow.GetCommittedServiceId().IsNone() || InFlow.IsSessionActive())
        { Fail("standalone camp retained session state"); return; }

        if (CheckResetPresentation(PC) == false)
        { return; }

        _Ended = true;
        Controller.Request_MarkHeartbeat("[MarsGauntletAs] HostServiceTravelReturn: passed");
        Controller.Request_EndTest(0);
    }

    private bool IsMap(UWorld InWorld, TSoftObjectPtr<UWorld> InMap) const
    {
        return ck::IsValid(InWorld) &&
            InWorld.GetOutermost().GetName().ToString() == InMap.GetLongPackageName();
    }

    private void Next(EMars_GauntletHostFlowStage InStage, float32 InTimeout, FString InMessage)
    {
        _Stage = InStage;
        _StageStarted = Controller.Get_ElapsedTimeSeconds();
        _StageTimeout = InTimeout;
        Controller.Request_MarkHeartbeat(f"[MarsGauntletAs] HostServiceTravelReturn: {InMessage}");
    }

    // Optional process-level presentation checks. Sandbox retains its existing flow without extra dependencies.
    protected bool CheckHostedPresentation(AMars_Camp_PlayerController InPC)
    { return true; }

    protected bool CheckCommittedPresentation(AMars_Camp_PlayerController InPC)
    { return true; }

    protected bool CheckReturnedPresentation(AMars_Camp_PlayerController InPC)
    { return true; }

    protected bool CheckResetPresentation(AMars_Camp_PlayerController InPC)
    { return true; }

    protected void Fail(FString InReason)
    {
        _Ended = true;
        Controller.Request_MarkHeartbeat(f"[MarsGauntletAs] HostServiceTravelReturn: FAIL {InReason}");
        Controller.Request_EndTest(1);
    }
}
