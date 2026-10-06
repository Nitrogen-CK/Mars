event void FMars_VestibuleReleaseInput();

// Reflected soft references keep the frontend asset dependencies explicit for authoring and cooking.
struct FMars_VestibuleWidgetClasses
{
    UPROPERTY(EditAnywhere)
    TSoftClassPtr<UUserWidget> Main = TSoftClassPtr<UUserWidget>(FSoftObjectPath(
        "/Game/Mars/UI/Widgets/ChalkParchment/VestibuleMain_Mars_WBP.VestibuleMain_Mars_WBP_C"));
    UPROPERTY(EditAnywhere)
    TSoftClassPtr<UUserWidget> Join = TSoftClassPtr<UUserWidget>(FSoftObjectPath(
        "/Game/Mars/UI/Widgets/ChalkParchment/VestibuleJoin_Mars_WBP.VestibuleJoin_Mars_WBP_C"));
    UPROPERTY(EditAnywhere)
    TSoftClassPtr<UUserWidget> Action = TSoftClassPtr<UUserWidget>(FSoftObjectPath(
        "/Game/Mars/UI/Widgets/ChalkParchment/VestibuleAction_Mars_WBP.VestibuleAction_Mars_WBP_C"));
    UPROPERTY(EditAnywhere)
    TSoftClassPtr<UUserWidget> Settings = TSoftClassPtr<UUserWidget>(FSoftObjectPath(
        "/Game/Mars/UI/Widgets/ChalkParchment/Settings_Mars_WBP.Settings_Mars_WBP_C"));
}

struct FMars_VestibuleSurface
{
    UUserWidget Widget;
    AMars_MenuBoardStation Station;
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
    private int _Active = 0;
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
        _Main = Cast<UMars_VestibuleMain_Widget>(CreateWidget(InClasses.Main));
        _Join = Cast<UMars_VestibuleJoin_Widget>(CreateWidget(InClasses.Join));
        _Host = Cast<UMars_VestibuleAction_Widget>(CreateWidget(InClasses.Action));
        _Quit = Cast<UMars_VestibuleAction_Widget>(CreateWidget(InClasses.Action));
        _Settings = Cast<UMars_ChalkSettings_Widget>(CreateWidget(InClasses.Settings));
        if (ck::Is_NOT_Valid(_Main) || ck::Is_NOT_Valid(_Join) || ck::Is_NOT_Valid(_Host) ||
            ck::Is_NOT_Valid(_Quit) || ck::Is_NOT_Valid(_Settings) || ck::Is_NOT_Valid(_Flow))
        { Close(); return false; }

        _Main.OnActionRequested.AddUFunction(this, n"HandleAction");
        _Main.OnFocusRequested.AddUFunction(this, n"QueueFocus");
        _Join.bWorldBoardPresentation = true;
        _Join.OnActionRequested.AddUFunction(this, n"HandleAction");
        _Join.OnFocusRequested.AddUFunction(this, n"QueueFocus");
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
        Navigate(0, true);
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
                _Join.SetError(FText::FromString(_Flow.GetLastError().GetValue()));
                Navigate(2, true);
            }
            else if (_Flow.GetFailedConnectAction() == EMars_LanFlowAction::HostCamp)
            { Navigate(1, true); }
        }
    }

    private UUserWidget CreateWidget(TSoftClassPtr<UUserWidget> InClass)
    {
        auto WidgetClass = System::LoadClassAsset_Blocking(InClass);
        if (ck::EnsureIfNot(ck::IsValid(WidgetClass), "[Vestibule] widget class is unset or did not load"))
        { return nullptr; }
        return WidgetBlueprint::CreateWidget(WidgetClass, _Controller);
    }

    private bool Attach(UUserWidget InWidget, EMars_CampStation InStation)
    {
        auto Station = Cast<AMars_MenuBoardStation>(_Controller.GetStationCamera(InStation));
        if (ck::EnsureIfNot(ck::IsValid(Station), f"[Vestibule] station [{InStation}] must be a board assembly"))
        { return false; }
        auto Component = Station.MenuSurface;
        Component.SetWidget(InWidget);
        Component.SetVisibility(true);
        Component.SetHiddenInGame(false);
        Component.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        InWidget.SetVisibility(ESlateVisibility::HitTestInvisible);
        FMars_VestibuleSurface Surface;
        Surface.Widget = InWidget;
        Surface.Station = Station;
        _Surfaces.Add(Surface);
        return true;
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
            if (ck::IsValid(Surface.Station))
            {
                Surface.Station.MenuSurface.SetCollisionEnabled(ECollisionEnabled::NoCollision);
                Surface.Station.MenuSurface.SetHiddenInGame(true);
                Surface.Station.MenuSurface.SetWidget(nullptr);
            }
        }
        _Surfaces.Empty();
    }

    private void Navigate(int InIndex, bool InCut = false)
    {
        if (!_Open || !_Surfaces.IsValidIndex(InIndex) || (_Arriving && InIndex != 0 && !InCut))
        { return; }
        _PendingFocus = nullptr;
        _Interaction.bEnableHitTesting = false;
        _Interactive = false;
        OnReleaseInput.Broadcast();
        Widget::SetFocusToGameViewport();
        for (auto Surface : _Surfaces)
        {
            Surface.Widget.SetVisibility(ESlateVisibility::HitTestInvisible);
            Surface.Station.MenuSurface.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        }
        if (_Active == 3 && _Settings.IsActivated())
        {
            _ClosingSettings = true;
            _Settings.DeactivateWidget();
            _Settings.SetVisibility(ESlateVisibility::HitTestInvisible);
            _ClosingSettings = false;
        }
        if (_Active == 2 && _Join.IsActivated())
        {
            _Join.DeactivateWidget();
            _Join.SetVisibility(ESlateVisibility::HitTestInvisible);
        }
        const float Duration = (InIndex == 1 || InIndex == 2 ||
            (InIndex == 0 && (_Active == 1 || _Active == 2))) ? 0.70 : 0.95;
        _Active = InIndex;
        _Arriving = true;
        if (!_Transition.Start(_Controller, _Surfaces[_Active].Station, InCut ? 0.0 : Duration, false))
        { Close(); }
    }

    void Tick(float InDeltaSeconds)
    {
        if (!_Open) { return; }
        if (ck::Is_NOT_Valid(_Controller) || ck::Is_NOT_Valid(_Surfaces[_Active].Station))
        { Close(); return; }
        _Transition.Tick(InDeltaSeconds);
        if (_Arriving && !_Transition.IsMoving())
        {
            auto Station = _Surfaces[_Active].Station;
            auto Widget = _Surfaces[_Active].Widget;
            auto Target = Station.MenuSurface.GetRenderTarget();
            if (_Controller.GetViewTarget() != Station || ck::Is_NOT_Valid(Target) ||
                !_Controller.PlayerCameraManager.GetCameraLocation().Equals(Station.CameraComponent.GetWorldLocation(), 0.1))
            { return; }
            if (_Active == 3 && !_Settings.IsActivated())
            { _Settings.ActivateWidget(); _Settings.ForceLayoutPrepass(); return; }
            if (_Active == 2 && !_Join.IsActivated())
            { _Join.ActivateWidget(); _Join.ForceLayoutPrepass(); return; }
            if (_Controller.IsInputKeyDown(EKeys::LeftMouseButton) || _Controller.IsInputKeyDown(EKeys::Enter) ||
                _Controller.IsInputKeyDown(EKeys::Gamepad_FaceButton_Bottom))
            { return; }
            Widget.SetVisibility(ESlateVisibility::SelfHitTestInvisible);
            Station.MenuSurface.SetCollisionEnabled(ECollisionEnabled::QueryOnly);
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
        for (int Index = 0; Index < _Surfaces.Num(); ++Index)
        {
            _Surfaces[Index].Station.MenuSurface.SetCollisionEnabled(Interactive && Index == _Active
                ? ECollisionEnabled::QueryOnly : ECollisionEnabled::NoCollision);
        }
        if (Interactive && !_Interactive) { _PendingFocus = PreferredFocus(); }
        _Interactive = Interactive;
    }

    private UWidget PreferredFocus() const
    {
        if (_Active == 0) { return _Main.GetPreferredFocusTarget(); }
        if (_Active == 1) { return _Host.GetPreferredFocusTarget(); }
        if (_Active == 2) { return _Join.GetPreferredFocusTarget(); }
        if (_Active == 3) { return _Settings.GetPreferredFocusTarget(); }
        return _Quit.GetPreferredFocusTarget();
    }

    UFUNCTION()
    private void QueueFocus(UWidget InWidget) { _PendingFocus = InWidget; }

    bool AdvanceTitle()
    { return IsInteractive() && _Active == 0 && _Main.AdvanceFromTitle(); }

    void SetNavigationPresentation()
    {
        auto Board = Cast<UMars_WorldBoard_Widget>(_Surfaces[_Active].Widget);
        if (ck::IsValid(Board)) { Board.SetNavigationPresentation(true); }
    }

    UFUNCTION()
    private void HandleAction(EMars_CampUiAction InAction)
    {
        if (!IsInteractive()) { return; }
        if (InAction == EMars_CampUiAction::Back) { Back(); return; }
        if (_Active == 2 && InAction == EMars_CampUiAction::Join)
        {
            if (_Flow.GetState() != EMars_LanFlowState::Idle) { return; }
            const auto Address = _Join.GetJoinAddress();
            if (!_Flow.IsValidDirectAddress(Address))
            {
                _Join.SetError(NSLOCTEXT("MarsCamp", "InvalidIPv4Address", "Enter an IPv4 address, optionally followed by a port from 1 to 65535."));
                return;
            }
            _Join.SetError(FText());
            _Flow.Join(Address);
            return;
        }
        if (_Active != 0 || _Flow.IsBusy()) { return; }
        _Main.SetPreferredReturnAction(InAction);
        if (InAction == EMars_CampUiAction::Host)
        { Navigate(1); _Flow.Host(); }
        else if (InAction == EMars_CampUiAction::Join)
        { _Join.SetError(FText()); Navigate(2); }
        else if (InAction == EMars_CampUiAction::Settings) { Navigate(3); }
        else if (InAction == EMars_CampUiAction::Quit) { Navigate(4); }
    }

    void Back()
    {
        if (!_Open || _Active == 0) { return; }
        if (utils_u_i_layout::Get_EffectiveInputMode(_Controller) != ECk_UI_InputMode::GameAndUI)
        { return; }
        if (_Active == 3 && ck::IsValid(_Settings.GetOpenDropdown()))
        { return; } // The physical Escape/Back event belongs to the open Slate popup first.
        if (_Flow.IsBusy())
        {
            if (!_Flow.IsSessionActive()) { _Flow.Cancel(); }
            return;
        }
        _Join.SetError(FText());
        Navigate(0);
    }

    UFUNCTION()
    private void OnSettingsClosed()
    { if (_Open && !_ClosingSettings) { Navigate(0); } }

    UFUNCTION()
    private void OnHostResult(bool InRetry)
    {
        if (!IsInteractive() || _Active != 1) { return; }
        if (!InRetry) { Back(); }
        else if (_Flow.GetState() == EMars_LanFlowState::Idle) { _Flow.Host(); }
    }

    UFUNCTION()
    private void OnQuitResult(bool InConfirmed)
    {
        if (!IsInteractive() || _Active != 4) { return; }
        if (InConfirmed) { System::QuitGame(_Controller, EQuitPreference::Quit, false); }
        else { Back(); }
    }

    UFUNCTION()
    private void RefreshState()
    {
        if (!_Open) { return; }
        const auto Status = FText::FromString(_Flow.GetStatus());
        const auto Action = _Flow.IsBusy() ? EMars_ButtonState::Busy : EMars_ButtonState::Enabled;
        _Main.SetActionState(Action);
        _Host.SetStatus(Status, Action);
        _Join.SetStatus(_Flow.GetLastError().IsSet() && !_Flow.IsBusy() ? FText() : Status, Action);
        RestoreFailedConnection();
    }
}
