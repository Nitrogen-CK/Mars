event void FMars_VestibuleReleaseInput();

namespace constants_camp_ui
{
    // The camera's move between two vestibule boards: the hop between the title and the host or join board is short,
    // every other move is the long one.
    const float32 k_VestibuleNearMoveSeconds = 0.70f;
    const float32 k_VestibuleFarMoveSeconds = 0.95f;
}

// Reflected soft references keep the frontend asset dependencies explicit for authoring and cooking.
struct FMars_VestibuleWidgetClasses
{
    UPROPERTY(EditAnywhere)
    TSoftClassPtr<UMars_VestibuleMain_Widget> Main = assets::VestibuleMain_Mars_WBP_Class();
    UPROPERTY(EditAnywhere)
    TSoftClassPtr<UMars_VestibuleJoin_Widget> Join = assets::VestibuleJoin_Mars_WBP_Class();
    UPROPERTY(EditAnywhere)
    TSoftClassPtr<UMars_VestibuleAction_Widget> Action = assets::VestibuleAction_Mars_WBP_Class();
    UPROPERTY(EditAnywhere)
    TSoftClassPtr<UMars_ChalkSettings_Widget> Settings = assets::Settings_Mars_WBP_Class();
}

// One vestibule board: the station it stands for, its board assembly and the widget on it.
struct FMars_VestibuleSurface
{
    EMars_CampStation Station = EMars_CampStation::Title;
    AMars_MenuBoardStation Board;
    UUserWidget Widget;
}

// Local frontend presentation only. CkUI still owns input mode and the LAN subsystem owns connection lifetime.
class UMars_VestibulePresentation : UObject
{
    FMars_VestibuleReleaseInput OnReleaseInput;
    private AMars_Camp_PlayerController _Controller;
    private UWidgetInteractionComponent _Interaction;
    private UMars_LanFlow_Subsystem _Flow;
    private UMars_MenuCameraTransition _Transition;
    private TArray<FMars_VestibuleSurface> _Surfaces;
    private UMars_VestibuleMain_Widget _Main;
    private UMars_VestibuleJoin_Widget _Join;
    private UMars_VestibuleAction_Widget _Host;
    private UMars_VestibuleAction_Widget _Quit;
    private UMars_ChalkSettings_Widget _Settings;
    private EMars_CampStation _Active = EMars_CampStation::Title;
    private bool _Open = false;
    private bool _Arriving = false;
    private bool _ClosingSettings = false;
    private bool _Interactive = false;
    private bool _RecoveryPresented = false;
    private UWidget _PendingFocus;

    bool IsOpen() const { return _Open; }
    bool IsInteractive() const { return _Open && !_Arriving; }

    bool Open(AMars_Camp_PlayerController InController, UWidgetInteractionComponent InInteraction,
        const FMars_VestibuleWidgetClasses& InClasses)
    {
        _Controller = InController;
        _Interaction = InInteraction;
        _Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        _Transition = Cast<UMars_MenuCameraTransition>(NewObject(this, UMars_MenuCameraTransition));
        _Main = Cast<UMars_VestibuleMain_Widget>(CreateWidget(System::LoadClassAsset_Blocking(InClasses.Main)));
        _Join = Cast<UMars_VestibuleJoin_Widget>(CreateWidget(System::LoadClassAsset_Blocking(InClasses.Join)));
        _Host = Cast<UMars_VestibuleAction_Widget>(CreateWidget(System::LoadClassAsset_Blocking(InClasses.Action)));
        _Quit = Cast<UMars_VestibuleAction_Widget>(CreateWidget(System::LoadClassAsset_Blocking(InClasses.Action)));
        _Settings = Cast<UMars_ChalkSettings_Widget>(CreateWidget(System::LoadClassAsset_Blocking(InClasses.Settings)));
        if (ck::Is_NOT_Valid(_Main) || ck::Is_NOT_Valid(_Join) || ck::Is_NOT_Valid(_Host) ||
            ck::Is_NOT_Valid(_Quit) || ck::Is_NOT_Valid(_Settings) || ck::Is_NOT_Valid(_Flow))
        { Close(); return false; }

        _Main.OnActionRequested.AddUFunction(this, n"HandleAction");
        _Main.OnFocusRequested.AddUFunction(this, n"QueueFocus");
        _Join.OnActionRequested.AddUFunction(this, n"HandleAction");
        _Host.OnResult.AddUFunction(this, n"OnHostResult");
        _Quit.OnResult.AddUFunction(this, n"OnQuitResult");
        _Settings.Presentation = EMars_SettingsPresentation::WorldBoard;
        _Settings.OnWorldBoardClosed.AddUFunction(this, n"OnSettingsClosed");
        _Host.Configure(FMars_ChalkConfirmation_Spec(
            NSLOCTEXT("MarsVestibule", "HostTitle", "HOST CAMP"),
            NSLOCTEXT("MarsVestibule", "HostMessage", "Preparing your camp"),
            NSLOCTEXT("MarsVestibule", "RetryHost", "Retry"), NSLOCTEXT("MarsVestibule", "HostBack", "Back")));
        _Quit.Configure(FMars_ChalkConfirmation_Spec(
            NSLOCTEXT("MarsVestibule", "QuitTitle", "QUIT GAME?"),
            NSLOCTEXT("MarsVestibule", "QuitMessage", "Return to desktop?"),
            NSLOCTEXT("MarsVestibule", "QuitConfirm", "Quit Game"), NSLOCTEXT("MarsVestibule", "Stay", "Stay")));
        if (!Attach(_Main, EMars_CampStation::Title) || !Attach(_Host, EMars_CampStation::FrontendHost) ||
            !Attach(_Join, EMars_CampStation::FrontendJoin) || !Attach(_Settings, EMars_CampStation::FrontendSettings) ||
            !Attach(_Quit, EMars_CampStation::FrontendQuit))
        { Close(); return false; }

        _Open = true;
        _Flow.OnStateChanged.AddUFunction(this, n"RefreshState");
        Navigate(EMars_CampStation::Title, true);
        RefreshState();
        return true;
    }

    // The recovered world's UI can initialize before WatchTravel observes the failed connection.
    // Reconcile on the flow signal as well as Open, once per failed operation.
    private void RestoreFailedConnection()
    {
        if (!_Flow.GetLastError().IsSet())
        { _RecoveryPresented = false; return; }
        if (_RecoveryPresented || _Flow.GetState() != EMars_LanFlowState::Idle)
        { return; }
        _RecoveryPresented = true;
        if (_Flow.GetFailedConnectAction() != EMars_LanFlowAction::None)
        {
            _Main.ShowMenu();
            if (_Flow.GetFailedConnectAction() == EMars_LanFlowAction::JoinAddress)
            {
                _Main.SetPreferredReturnAction(EMars_CampUiAction::Join);
                _Join.SetAddress(_Flow.GetLastJoinAddress());
                _Join.SetError(Get_StatusText(_Flow.GetLastError().GetValue()));
                Navigate(EMars_CampStation::FrontendJoin, true);
            }
            else if (_Flow.GetFailedConnectAction() == EMars_LanFlowAction::HostCamp)
            { Navigate(EMars_CampStation::FrontendHost, true); }
        }
    }

    // The player-facing copy for a LAN flow status.
    private FText Get_StatusText(EMars_LanFlowStatus InStatus) const
    {
        switch (InStatus)
        {
            case EMars_LanFlowStatus::OpeningCamp: return NSLOCTEXT("MarsLanFlow", "OpeningCamp", "Opening LAN camp");
            case EMars_LanFlowStatus::JoiningCamp: return NSLOCTEXT("MarsLanFlow", "JoiningCamp", "Joining LAN camp");
            case EMars_LanFlowStatus::DepartingCamp: return NSLOCTEXT("MarsLanFlow", "DepartingCamp", "Departing camp");
            case EMars_LanFlowStatus::ReturningToCamp: return NSLOCTEXT("MarsLanFlow", "ReturningToCamp", "Returning to camp");
            case EMars_LanFlowStatus::JoinedCamp: return NSLOCTEXT("MarsLanFlow", "JoinedCamp", "Joined LAN camp");
            case EMars_LanFlowStatus::SessionActive: return NSLOCTEXT("MarsLanFlow", "SessionActive", "LAN session active");
            case EMars_LanFlowStatus::InvalidAddress: return NSLOCTEXT("MarsCamp", "InvalidIPv4Address", "Enter an IPv4 address, optionally followed by a port from 1 to 65535.");
            case EMars_LanFlowStatus::CouldNotOpenCamp: return NSLOCTEXT("MarsLanFlow", "CouldNotOpenCamp", "Could not open LAN camp");
            case EMars_LanFlowStatus::CouldNotReachHost: return NSLOCTEXT("MarsLanFlow", "CouldNotReachHost", "Could not reach host");
            case EMars_LanFlowStatus::ConnectionLost: return NSLOCTEXT("MarsLanFlow", "ConnectionLost", "Connection to the host was lost");
            case EMars_LanFlowStatus::TravelIncomplete: return NSLOCTEXT("MarsLanFlow", "TravelIncomplete", "The party's travel did not complete");
            case EMars_LanFlowStatus::ServerTravelFailed: return NSLOCTEXT("MarsLanFlow", "ServerTravelFailed", "Server travel could not start");
            case EMars_LanFlowStatus::CouldNotLoadCamp: return NSLOCTEXT("MarsLanFlow", "CouldNotLoadCamp", "Could not load camp. Retry return to menu");
            default: return FText();
        }
    }

    private UUserWidget CreateWidget(TSubclassOf<UUserWidget> InLoadedClass)
    {
        if (ck::EnsureIfNot(ck::IsValid(InLoadedClass), "[Vestibule] widget class is unset or did not load"))
        { return nullptr; }

        return WidgetBlueprint::CreateWidget(InLoadedClass, _Controller);
    }

    private bool Attach(UUserWidget InWidget, EMars_CampStation InStation)
    {
        auto Board = Cast<AMars_MenuBoardStation>(utils_camp_station::TryGet_Camera(_Controller.GetWorld(), InStation));
        if (ck::EnsureIfNot(ck::IsValid(Board), f"[Vestibule] station [{InStation}] must be a board assembly"))
        { return false; }
        auto Component = Board.MenuSurface;
        Component.SetWidget(InWidget);
        Component.SetVisibility(true);
        Component.SetHiddenInGame(false);
        Component.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        InWidget.SetVisibility(ESlateVisibility::HitTestInvisible);
        FMars_VestibuleSurface Surface;
        Surface.Station = InStation;
        Surface.Board = Board;
        Surface.Widget = InWidget;
        _Surfaces.Add(Surface);
        return true;
    }

    private TOptional<int32> TryGet_SurfaceIndex(EMars_CampStation InStation) const
    {
        for (int32 Index = 0; Index < _Surfaces.Num(); ++Index)
        {
            if (_Surfaces[Index].Station == InStation)
            { return TOptional<int32>(Index); }
        }

        return TOptional<int32>();
    }

    // Valid while the vestibule is open: Open attaches a surface for every station Navigate takes.
    private FMars_VestibuleSurface Get_ActiveSurface() const
    {
        return _Surfaces[TryGet_SurfaceIndex(_Active).GetValue()];
    }

    void Close()
    {
        _Open = false;
        _Interactive = false;
        _PendingFocus = nullptr;
        if (ck::IsValid(_Interaction))
        { _Interaction.bEnableHitTesting = false; OnReleaseInput.Broadcast(); }
        if (ck::IsValid(_Flow))
        { _Flow.OnStateChanged.Unbind(this, n"RefreshState"); }
        if (ck::IsValid(_Transition))
        { _Transition.Cancel(); }
        if (ck::IsValid(_Settings) && _Settings.IsActivated())
        { _Settings.DeactivateWidget(); }
        if (ck::IsValid(_Join) && _Join.IsActivated())
        { _Join.DeactivateWidget(); }
        for (auto Surface : _Surfaces)
        {
            if (ck::IsValid(Surface.Board))
            {
                Surface.Board.MenuSurface.SetCollisionEnabled(ECollisionEnabled::NoCollision);
                Surface.Board.MenuSurface.SetHiddenInGame(true);
                Surface.Board.MenuSurface.SetWidget(nullptr);
            }
        }
        _Surfaces.Empty();
    }

    // The host and join boards stand beside the title board.
    private bool Get_IsNearTitle(EMars_CampStation InStation) const
    {
        return InStation == EMars_CampStation::FrontendHost || InStation == EMars_CampStation::FrontendJoin;
    }

    private void Navigate(EMars_CampStation InStation, bool InCut = false)
    {
        if (!_Open || TryGet_SurfaceIndex(InStation).IsSet() == false ||
            (_Arriving && InStation != EMars_CampStation::Title && !InCut))
        { return; }
        _PendingFocus = nullptr;
        _Interaction.bEnableHitTesting = false;
        _Interactive = false;
        OnReleaseInput.Broadcast();
        Widget::SetFocusToGameViewport();
        for (auto Surface : _Surfaces)
        {
            Surface.Widget.SetVisibility(ESlateVisibility::HitTestInvisible);
            Surface.Board.MenuSurface.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        }
        if (_Active == EMars_CampStation::FrontendSettings && _Settings.IsActivated())
        {
            _ClosingSettings = true;
            _Settings.DeactivateWidget();
            _Settings.SetVisibility(ESlateVisibility::HitTestInvisible);
            _ClosingSettings = false;
        }
        if (_Active == EMars_CampStation::FrontendJoin && _Join.IsActivated())
        {
            _Join.DeactivateWidget();
            _Join.SetVisibility(ESlateVisibility::HitTestInvisible);
        }
        const bool Near = Get_IsNearTitle(InStation) || (InStation == EMars_CampStation::Title && Get_IsNearTitle(_Active));
        const float Duration = Near ? constants_camp_ui::k_VestibuleNearMoveSeconds : constants_camp_ui::k_VestibuleFarMoveSeconds;
        _Active = InStation;
        _Arriving = true;
        if (!_Transition.Start(_Controller, Get_ActiveSurface().Board, InCut ? 0.0 : Duration))
        { Close(); }
    }

    void Tick(float InDeltaSeconds)
    {
        if (!_Open) { return; }
        if (ck::Is_NOT_Valid(_Controller) || ck::Is_NOT_Valid(Get_ActiveSurface().Board))
        { Close(); return; }
        _Transition.Tick(InDeltaSeconds);
        if (_Arriving && !_Transition.IsMoving())
        {
            auto Surface = Get_ActiveSurface();
            auto Board = Surface.Board;
            auto Widget = Surface.Widget;
            auto Target = Board.MenuSurface.GetRenderTarget();
            if (_Controller.GetViewTarget() != Board || ck::Is_NOT_Valid(Target) ||
                !_Controller.PlayerCameraManager.GetCameraLocation().Equals(Board.CameraComponent.GetWorldLocation(), 0.1))
            { return; }
            if (_Active == EMars_CampStation::FrontendSettings && !_Settings.IsActivated())
            { _Settings.ActivateWidget(); _Settings.ForceLayoutPrepass(); return; }
            if (_Active == EMars_CampStation::FrontendJoin && !_Join.IsActivated())
            { _Join.ActivateWidget(); _Join.ForceLayoutPrepass(); return; }
            if (_Controller.IsInputKeyDown(EKeys::LeftMouseButton) || _Controller.IsInputKeyDown(EKeys::Enter) ||
                _Controller.IsInputKeyDown(EKeys::Gamepad_FaceButton_Bottom))
            { return; }
            Widget.SetVisibility(ESlateVisibility::SelfHitTestInvisible);
            Board.MenuSurface.SetCollisionEnabled(ECollisionEnabled::QueryOnly);
            _Arriving = false;
            RefreshInput();
            _PendingFocus = PreferredFocus();
        }
        if (ck::IsValid(_PendingFocus) && _Interactive)
        {
            const auto Size = _PendingFocus.GetCachedGeometry().GetLocalSize();
            if (Size.X <= 0 || Size.Y <= 0) { return; }
            _PendingFocus.SetUserFocus(_Controller);
            _PendingFocus = nullptr;
        }
    }

    void RefreshInput()
    {
        const bool Interactive = IsInteractive() &&
            utils_u_i_layout::Get_EffectiveInputMode(_Controller) == ECk_UI_InputMode::GameAndUI;
        if (!Interactive && _Interactive)
        { OnReleaseInput.Broadcast(); }
        // Hardware input and WidgetInteraction must not both drive the same pointer/focus path.
        _Interaction.bEnableHitTesting = false;
        for (auto Surface : _Surfaces)
        {
            Surface.Board.MenuSurface.SetCollisionEnabled(Interactive && Surface.Station == _Active
                ? ECollisionEnabled::QueryOnly : ECollisionEnabled::NoCollision);
        }
        if (Interactive && !_Interactive) { _PendingFocus = PreferredFocus(); }
        _Interactive = Interactive;
    }

    private UWidget PreferredFocus() const
    {
        if (_Active == EMars_CampStation::Title) { return _Main.GetPreferredFocusTarget(); }
        if (_Active == EMars_CampStation::FrontendHost) { return _Host.GetPreferredFocusTarget(); }
        if (_Active == EMars_CampStation::FrontendJoin) { return _Join.GetPreferredFocusTarget(); }
        if (_Active == EMars_CampStation::FrontendSettings) { return _Settings.GetPreferredFocusTarget(); }
        return _Quit.GetPreferredFocusTarget();
    }

    UFUNCTION()
    private void QueueFocus(UWidget InWidget) { _PendingFocus = InWidget; }

    bool AdvanceTitle()
    { return IsInteractive() && _Active == EMars_CampStation::Title && _Main.AdvanceFromTitle(); }

    void SetNavigationPresentation()
    {
        if (!_Open) { return; }
        auto Board = Cast<UMars_WorldBoard_Widget>(Get_ActiveSurface().Widget);
        if (ck::IsValid(Board)) { Board.SetNavigationPresentation(true); }
    }

    UFUNCTION()
    private void HandleAction(EMars_CampUiAction InAction)
    {
        if (!IsInteractive()) { return; }
        if (InAction == EMars_CampUiAction::Back) { Back(); return; }
        if (_Active == EMars_CampStation::FrontendJoin && InAction == EMars_CampUiAction::Join)
        {
            if (_Flow.GetState() != EMars_LanFlowState::Idle) { return; }
            const auto Address = _Join.GetJoinAddress();
            if (!_Flow.IsValidDirectAddress(Address))
            {
                _Join.SetError(Get_StatusText(EMars_LanFlowStatus::InvalidAddress));
                return;
            }
            _Join.SetError(FText());
            _Flow.Join(Address);
            return;
        }
        if (_Active != EMars_CampStation::Title || _Flow.IsBusy()) { return; }
        _Main.SetPreferredReturnAction(InAction);
        if (InAction == EMars_CampUiAction::Host)
        { Navigate(EMars_CampStation::FrontendHost); _Flow.Host(); }
        else if (InAction == EMars_CampUiAction::Join)
        { _Join.SetError(FText()); Navigate(EMars_CampStation::FrontendJoin); }
        else if (InAction == EMars_CampUiAction::Settings) { Navigate(EMars_CampStation::FrontendSettings); }
        else if (InAction == EMars_CampUiAction::Quit) { Navigate(EMars_CampStation::FrontendQuit); }
    }

    void Back()
    {
        if (!_Open || _Active == EMars_CampStation::Title) { return; }
        if (utils_u_i_layout::Get_EffectiveInputMode(_Controller) != ECk_UI_InputMode::GameAndUI)
        { return; }
        if (_Active == EMars_CampStation::FrontendSettings && ck::IsValid(_Settings.GetOpenDropdown()))
        { return; } // The physical Escape/Back event belongs to the open Slate popup first.
        if (_Flow.IsBusy())
        {
            if (!_Flow.IsSessionActive()) { _Flow.Cancel(); }
            return;
        }
        _Join.SetError(FText());
        Navigate(EMars_CampStation::Title);
    }

    UFUNCTION()
    private void OnSettingsClosed()
    { if (_Open && !_ClosingSettings) { Navigate(EMars_CampStation::Title); } }

    UFUNCTION()
    private void OnHostResult(bool InRetry)
    {
        if (!IsInteractive() || _Active != EMars_CampStation::FrontendHost) { return; }
        if (!InRetry) { Back(); }
        else if (_Flow.GetState() == EMars_LanFlowState::Idle) { _Flow.Host(); }
    }

    UFUNCTION()
    private void OnQuitResult(bool InConfirmed)
    {
        if (!IsInteractive() || _Active != EMars_CampStation::FrontendQuit) { return; }
        if (InConfirmed) { System::QuitGame(_Controller, EQuitPreference::Quit, false); }
        else { Back(); }
    }

    UFUNCTION()
    private void RefreshState()
    {
        if (!_Open) { return; }
        const auto Status = Get_StatusText(_Flow.GetStatus());
        const auto Action = _Flow.IsBusy() ? EMars_ButtonState::Busy : EMars_ButtonState::Enabled;
        _Main.SetActionState(Action);
        _Host.SetStatus(Status, Action);
        _Join.SetStatus(_Flow.GetLastError().IsSet() && !_Flow.IsBusy() ? FText() : Status, Action);
        RestoreFailedConnection();
    }
}
