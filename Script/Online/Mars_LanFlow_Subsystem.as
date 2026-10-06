// Local-network camp travel. UI chooses the destination; this subsystem owns only the travel lifetime.
enum EMars_LanFlowState
{
    Idle,
    Hosting,
    Joining,
    Connected,
    Departing,
    Returning,
    Recovering
}

enum EMars_LanFlowAction
{
    None,
    HostCamp,
    JoinAddress,
    ServerMap,
    StandaloneCamp
}

enum EMars_LanFlowTravel
{
    DepartCamp,
    ReturnToCamp
}

namespace constants_lan_flow
{
    // Ticked (not wall-clock) seconds: wall time advances during the blocking LoadMap.
    const float32 k_TravelAbandonTickedSeconds = 30.0f;
    // A server travel loads the destination asynchronously while the old world keeps ticking.
    const float32 k_ServerTravelAbandonTickedSeconds = 90.0f;
}

event void FMars_LanFlow_OnStateChanged();

class UMars_LanFlow_Subsystem : UScriptGameInstanceSubsystem
{
    FMars_LanFlow_OnStateChanged OnStateChanged;

    private EMars_LanFlowState _State = EMars_LanFlowState::Idle;
    private EMars_LanFlowAction _PendingAction = EMars_LanFlowAction::None;
    private int32 _Generation = 0;
    private int32 _PendingGeneration = 0;
    private TWeakObjectPtr<UWorld> _DepartureWorld;
    private TSoftObjectPtr<UWorld> _TravelTarget;
    private FString _JoinAddress;
    // Request context survives the covered recovery reload so the matching board can show Retry.
    private EMars_LanFlowAction _LastConnectAction = EMars_LanFlowAction::None;
    private FString _LastJoinAddress;
    private FString _Status;
    private TOptional<FString> _LastError;
    private float32 _TravelTickedSeconds = 0.0f;
    private UCk_LoadingProcess_Task_UE _LoadingHold;
    UPROPERTY()
    private FName _CommittedServiceId;

    UFUNCTION(BlueprintOverride)
    bool ShouldCreateSubsystem(UObject InOuter) const
    {
        auto CurrentWorld = InOuter.GetWorld();
        return ck::IsValid(CurrentWorld) && (CurrentWorld.WorldType == EWorldType::Game || CurrentWorld.WorldType == EWorldType::PIE);
    }

    UFUNCTION(BlueprintOverride)
    void Deinitialize()
    {
        ReleaseHold();
        _DepartureWorld = nullptr;
    }

    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaTime)
    {
        if (_PendingAction != EMars_LanFlowAction::None && _PendingGeneration == _Generation)
        {
            const EMars_LanFlowAction Action = _PendingAction;
            _PendingAction = EMars_LanFlowAction::None;
            IssueTravel(Action);
        }

        if (_State == EMars_LanFlowState::Idle)
        { return; }
        if (_State == EMars_LanFlowState::Connected)
        { WatchSession(); return; }
        WatchTravel(DeltaTime);
    }

    UFUNCTION()
    void Host()
    {
        if (_State != EMars_LanFlowState::Idle)
        { return; }
        auto CurrentWorld = GetWorld();
        if (ck::EnsureIfNot(ck::IsValid(CurrentWorld) && CurrentWorld.GetNetMode() == ENetMode::NM_Standalone,
            "[Mars_LanFlow] Host called outside a standalone world"))
        { return; }

        _TravelTarget = assets::Camp_Mars_MAP();
        _LastConnectAction = EMars_LanFlowAction::HostCamp;
        BeginOperation(EMars_LanFlowState::Hosting, "Opening LAN camp", EMars_LanFlowAction::HostCamp);
        _CommittedServiceId = NAME_None;
    }

    UFUNCTION()
    void Join(FString InDirectAddress)
    {
        if (_State != EMars_LanFlowState::Idle)
        { return; }
        if (IsValidDirectAddress(InDirectAddress) == false)
        {
            const FString Error = "Enter an IPv4 address, optionally followed by a port from 1 to 65535";
            _LastError = TOptional<FString>(Error);
            _Status = Error;
            OnStateChanged.Broadcast();
            return;
        }

        _JoinAddress = InDirectAddress;
        _LastJoinAddress = InDirectAddress;
        _LastConnectAction = EMars_LanFlowAction::JoinAddress;
        _TravelTarget = assets::Camp_Mars_MAP();
        BeginOperation(EMars_LanFlowState::Joining, "Joining LAN camp", EMars_LanFlowAction::JoinAddress);
        _CommittedServiceId = NAME_None;
    }

    // A server travel cannot be taken back once queued: clients have already been told to follow.
    UFUNCTION()
    void Cancel()
    {
        if (ck::EnsureIfNot(_State != EMars_LanFlowState::Departing && _State != EMars_LanFlowState::Returning,
            "[Mars_LanFlow] Cancel during a server travel; the server owns that travel"))
        { return; }
        if (_State == EMars_LanFlowState::Idle)
        { return; }
        if (_State == EMars_LanFlowState::Recovering)
        {
            if (_TravelTickedSeconds < constants_lan_flow::k_TravelAbandonTickedSeconds)
            { return; }
            BeginRecovery(_LastError);
            return;
        }
        ReturnToMenu();
    }

    UFUNCTION()
    void ReturnToMenu()
    {
        _LastConnectAction = EMars_LanFlowAction::None;
        BeginRecovery(TOptional<FString>());
    }

    UFUNCTION()
    bool RequestServerTravel(TSoftObjectPtr<UWorld> InTarget, EMars_LanFlowTravel InTravel)
    {
        if (ck::EnsureIfNot(InTarget.IsNull() == false, "[Mars_LanFlow] RequestServerTravel needs a destination map"))
        { return false; }
        auto CurrentWorld = GetWorld();
        if (_State != EMars_LanFlowState::Connected || ck::Is_NOT_Valid(CurrentWorld) ||
            CurrentWorld.GetNetMode() != ENetMode::NM_ListenServer)
        { return false; }

        _TravelTarget = InTarget;
        if (InTravel == EMars_LanFlowTravel::ReturnToCamp)
        { BeginOperation(EMars_LanFlowState::Returning, "Returning to camp", EMars_LanFlowAction::ServerMap); }
        else
        { BeginOperation(EMars_LanFlowState::Departing, "Departing camp", EMars_LanFlowAction::ServerMap); }
        return true;
    }

    UFUNCTION()
    bool IsBusy() const
    { return _State != EMars_LanFlowState::Idle && _State != EMars_LanFlowState::Connected; }

    UFUNCTION()
    FString GetStatus() const
    { return _Status; }

    TOptional<FString> GetLastError() const
    { return _LastError; }

    EMars_LanFlowAction GetFailedConnectAction() const
    { return _LastError.IsSet() ? _LastConnectAction : EMars_LanFlowAction::None; }

    // Meaningful only while GetFailedConnectAction() is JoinAddress.
    FString GetLastJoinAddress() const
    { return _LastJoinAddress; }

    UFUNCTION()
    bool IsSessionActive() const
    { return _State == EMars_LanFlowState::Connected || _State == EMars_LanFlowState::Departing || _State == EMars_LanFlowState::Returning; }

    UFUNCTION()
    EMars_LanFlowState GetState() const
    { return _State; }

    UFUNCTION()
    void SetCommittedServiceId(FName InServiceId)
    {
        auto CurrentWorld = GetWorld();
        if (_State != EMars_LanFlowState::Connected || ck::Is_NOT_Valid(CurrentWorld) || CurrentWorld.GetNetMode() != ENetMode::NM_ListenServer)
        { return; }
        _CommittedServiceId = InServiceId;
        OnStateChanged.Broadcast();
    }

    UFUNCTION()
    FName GetCommittedServiceId() const
    { return _CommittedServiceId; }

    private void BeginOperation(EMars_LanFlowState InState, FString InStatus, EMars_LanFlowAction InAction)
    {
        ++_Generation;
        _LastError.Reset();
        _DepartureWorld = TWeakObjectPtr<UWorld>(GetWorld());
        _TravelTickedSeconds = 0.0f;
        SetState(InState, InStatus);
        HoldLoading(InStatus);
        QueueAction(InAction);
    }

    private void BeginRecovery(TOptional<FString> InError)
    {
        ++_Generation;
        _PendingAction = EMars_LanFlowAction::None;
        _JoinAddress.Empty();
        _TravelTarget = assets::Camp_Mars_MAP();
        _CommittedServiceId = NAME_None;
        _LastError = InError;
        _DepartureWorld = TWeakObjectPtr<UWorld>(GetWorld());
        _TravelTickedSeconds = 0.0f;
        SetState(EMars_LanFlowState::Recovering, InError.IsSet() ? InError.GetValue() : "Returning to camp");
        HoldLoading("Returning to camp");
        QueueAction(EMars_LanFlowAction::StandaloneCamp);
    }

    // The engine already travelled us back to a standalone world: a failed connect, a lost connection or a failed
    // listen all end here. A standalone camp is settled in place instead of being loaded a second time.
    private void SettleAfterBounce(UWorld InWorld, FString InError)
    {
        if (IsMap(InWorld, assets::Camp_Mars_MAP()) == false)
        { BeginRecovery(TOptional<FString>(InError)); return; }

        ++_Generation;
        _PendingAction = EMars_LanFlowAction::None;
        _JoinAddress.Empty();
        _TravelTarget = assets::Camp_Mars_MAP();
        _CommittedServiceId = NAME_None;
        _LastError = TOptional<FString>(InError);
        _DepartureWorld = nullptr;
        _TravelTickedSeconds = 0.0f;
        SetState(EMars_LanFlowState::Recovering, InError);
        HoldLoading("Returning to camp");
    }

    private void QueueAction(EMars_LanFlowAction InAction)
    {
        _PendingAction = InAction;
        _PendingGeneration = _Generation;
    }

    private void IssueTravel(EMars_LanFlowAction InAction)
    {
        if (InAction == EMars_LanFlowAction::HostCamp)
        { Gameplay::OpenLevelBySoftObjectPtr(_TravelTarget, true, "listen"); }
        else if (InAction == EMars_LanFlowAction::JoinAddress)
        { Gameplay::OpenLevel(FName(_JoinAddress), true, ""); }
        else if (InAction == EMars_LanFlowAction::StandaloneCamp)
        {
            // A plain local OpenLevel does not cancel PendingNetGame. Browse's closed path
            // cancels it before loading GameDefaultMap (Camp, per DefaultEngine.ini), otherwise
            // a failed Join can reopen Camp as a client with no authoritative GameState.
            Gameplay::OpenLevelBySoftObjectPtr(_TravelTarget, true, "closed");
        }
        else if (InAction == EMars_LanFlowAction::ServerMap)
        {
            auto CurrentWorld = GetWorld();
            if (ck::Is_NOT_Valid(CurrentWorld) || CurrentWorld.GetNetMode() != ENetMode::NM_ListenServer ||
                CurrentWorld.ServerTravel(_TravelTarget.GetLongPackageName(), false, false) == false)
            { BeginRecovery(TOptional<FString>("Server travel could not start")); }
        }
    }

    private void WatchSession()
    {
        auto CurrentWorld = GetWorld();
        if (ck::Is_NOT_Valid(CurrentWorld))
        { return; }
        const auto Mode = CurrentWorld.GetNetMode();
        if (Mode == ENetMode::NM_Client || Mode == ENetMode::NM_ListenServer)
        { return; }
        SettleAfterBounce(CurrentWorld, Get_FailureMessage());
    }

    private void WatchTravel(float DeltaTime)
    {
        auto CurrentWorld = GetWorld();
        if (ck::IsValid(CurrentWorld) && CurrentWorld != _DepartureWorld.Get())
        {
            const auto Mode = CurrentWorld.GetNetMode();
            if (_State == EMars_LanFlowState::Recovering)
            {
                if (Mode == ENetMode::NM_Standalone && IsExpectedMap(CurrentWorld) && IsLocalPlayerReady(CurrentWorld))
                { FinishTravel(EMars_LanFlowState::Idle, _LastError.IsSet() ? _LastError.GetValue() : ""); return; }
            }
            else if (Mode == ENetMode::NM_Standalone)
            { SettleAfterBounce(CurrentWorld, Get_FailureMessage()); return; }
            else if (_State == EMars_LanFlowState::Joining && Mode == ENetMode::NM_Client && IsExpectedMap(CurrentWorld) && IsLocalPlayerReady(CurrentWorld))
            { FinishTravel(EMars_LanFlowState::Connected, "Joined LAN camp"); return; }
            else if ((_State == EMars_LanFlowState::Hosting || _State == EMars_LanFlowState::Departing ||
                _State == EMars_LanFlowState::Returning) && Mode == ENetMode::NM_ListenServer && IsExpectedMap(CurrentWorld) && IsLocalPlayerReady(CurrentWorld))
            { FinishTravel(EMars_LanFlowState::Connected, "LAN session active"); return; }
        }

        if (_State == EMars_LanFlowState::Recovering && _TravelTickedSeconds >= constants_lan_flow::k_TravelAbandonTickedSeconds)
        { return; }
        _TravelTickedSeconds += float32(DeltaTime);
        if (_TravelTickedSeconds < Get_AbandonBudget())
        { return; }
        if (_State == EMars_LanFlowState::Recovering)
        {
            ReleaseHold();
            SetState(EMars_LanFlowState::Recovering, "Could not load camp. Retry return to menu");
            return;
        }
        BeginRecovery(TOptional<FString>(Get_FailureMessage()));
    }

    private float32 Get_AbandonBudget() const
    {
        if (_State == EMars_LanFlowState::Departing || _State == EMars_LanFlowState::Returning)
        { return constants_lan_flow::k_ServerTravelAbandonTickedSeconds; }
        return constants_lan_flow::k_TravelAbandonTickedSeconds;
    }

    private FString Get_FailureMessage() const
    {
        if (_State == EMars_LanFlowState::Hosting)
        { return "Could not open LAN camp"; }
        if (_State == EMars_LanFlowState::Joining)
        { return "Could not reach host"; }
        if (_State == EMars_LanFlowState::Connected)
        { return "Connection to the host was lost"; }
        return "The party's travel did not complete";
    }

    private void FinishTravel(EMars_LanFlowState InState, FString InStatus)
    {
        _DepartureWorld = nullptr;
        _TravelTarget = TSoftObjectPtr<UWorld>();
        _JoinAddress.Empty();
        ReleaseHold();
        SetState(InState, InStatus);
    }

    private void SetState(EMars_LanFlowState InState, FString InStatus)
    {
        _State = InState;
        _Status = InStatus;
        OnStateChanged.Broadcast();
    }

    private void HoldLoading(FString InReason)
    {
        ReleaseHold();
        _LoadingHold = UCk_LoadingProcess_Task_UE::Create(InReason, FCk_Time());
    }

    private void ReleaseHold()
    {
        if (ck::IsValid(_LoadingHold))
        { _LoadingHold.Request_Unregister(); }
        _LoadingHold = nullptr;
    }

    private bool IsExpectedMap(UWorld InWorld) const
    {
        if (_TravelTarget.IsNull())
        { return false; }
        return IsMap(InWorld, _TravelTarget);
    }

    private bool IsMap(UWorld InWorld, TSoftObjectPtr<UWorld> InMap) const
    {
        if (ck::Is_NOT_Valid(InWorld))
        { return false; }
        const FString Expected = InMap.GetLongPackageName();
        const FString Actual = InWorld.GetOutermost().GetName().ToString();
        if (Actual == Expected)
        { return true; }

        // PIE inserts UEDPIE_<instance>_ before the map leaf in the same package directory.
        FString Directory;
        FString Leaf;
        if (Expected.Split("/", Directory, Leaf, ESearchCase::CaseSensitive, ESearchDir::FromEnd) == false)
        { return false; }
        return Actual.StartsWith(f"{Directory}/UEDPIE_", ESearchCase::CaseSensitive) &&
            Actual.EndsWith(f"_{Leaf}", ESearchCase::CaseSensitive);
    }

    private bool IsLocalPlayerReady(UWorld InWorld) const
    {
        auto PC = Gameplay::GetPlayerController(0);
        if (ck::Is_NOT_Valid(PC) || PC.GetWorld() != InWorld)
        { return false; }
        auto Pawn = PC.GetControlledPawn();
        if (ck::Is_NOT_Valid(Pawn) || Pawn.GetWorld() != InWorld)
        { return false; }

        if (_TravelTarget.GetLongPackageName() == assets::Camp_Mars_MAP().GetLongPackageName())
        {
            auto CampState = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
            if (ck::Is_NOT_Valid(CampState) || CampState.GetWorld() != InWorld)
            { return false; }
            if (_State == EMars_LanFlowState::Recovering)
            { return ck::IsValid(Cast<AMars_Camp_ViewerPawn>(Pawn)); }
            return ck::IsValid(Cast<AMars_PlayerCharacter>(Pawn));
        }
        return true;
    }

    // Dotted-decimal IPv4, optionally followed by a decimal port.
    UFUNCTION()
    bool IsValidDirectAddress(const FString& InAddress) const
    {
        const int32 AddressLength = InAddress.Len();
        if (AddressLength == 0)
        { return false; }

        int32 HostLength = AddressLength;
        for (int32 Index = 0; Index < AddressLength; ++Index)
        {
            if (int32(InAddress[Index]) != 58)
            { continue; }
            if (HostLength != AddressLength)
            { return false; }
            HostLength = Index;
        }
        if (HostLength == 0)
        { return false; }

        int32 OctetCount = 1;
        int32 OctetDigits = 0;
        int32 OctetValue = 0;
        for (int32 Index = 0; Index < HostLength; ++Index)
        {
            const int32 Code = int32(InAddress[Index]);
            if (Code == 46)
            {
                if (OctetDigits == 0 || OctetCount >= 4)
                { return false; }
                ++OctetCount;
                OctetDigits = 0;
                OctetValue = 0;
                continue;
            }
            if (Code < 48 || Code > 57)
            { return false; }
            ++OctetDigits;
            if (OctetDigits > 3)
            { return false; }
            OctetValue = OctetValue * 10 + Code - 48;
            if (OctetValue > 255)
            { return false; }
        }
        if (OctetCount != 4 || OctetDigits == 0)
        { return false; }

        if (HostLength == AddressLength)
        { return true; }
        const int32 PortLength = AddressLength - HostLength - 1;
        if (PortLength == 0 || PortLength > 5)
        { return false; }
        int32 Port = 0;
        for (int32 Index = HostLength + 1; Index < AddressLength; ++Index)
        {
            const int32 Code = int32(InAddress[Index]);
            if (Code < 48 || Code > 57)
            { return false; }
            Port = Port * 10 + Code - 48;
        }
        return Port >= 1 && Port <= 65535;
    }
}
