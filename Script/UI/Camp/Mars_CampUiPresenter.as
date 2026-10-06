enum EMars_CampBoardClose
{
    // Blend the view back to the possessed chef.
    ReturnToChef,
    // Drop the board only; the view is someone else's to move (possession change, world teardown).
    Teardown
}

namespace constants_camp_ui
{
    const float32 k_InteractionDistance = 3000.0f;
    const float32 k_ReturnToChefBlendSeconds = 0.25f;
}

// One client-local owner of the open world board: its render surface, Slate virtual user and input profile.
// The CkUI layout owns input mode through a tree-less UI.Layer.GameMenu host. Party state stays on the GameState.
class AMars_CampUiPresenter : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent, Attach = Root)
    UWidgetInteractionComponent Interaction;
    default Interaction.InteractionSource = EWidgetInteractionSource::Mouse;
    default Interaction.InteractionDistance = constants_camp_ui::k_InteractionDistance;
    default Interaction.VirtualUserIndex = 1;
    default Interaction.bEnableHitTesting = false;

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    FMars_VestibuleWidgetClasses VestibuleClasses;

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    TSoftClassPtr<UMars_ChalkConfirmation_Widget> ConfirmationClass = assets::Confirmation_Mars_WBP_Class();

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    TSoftClassPtr<UMars_ChalkService_Widget> ServiceClass = assets::Service_Mars_WBP_Class();

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    TSoftClassPtr<UMars_ChalkDeparture_Widget> DepartureClass = assets::Departure_Mars_WBP_Class();

    private AMars_Camp_PlayerController _Controller;
    private UMars_LanFlow_Subsystem _Flow;
    private AMars_Camp_GameState _State;
    private UMars_WorldBoardHost_Widget _Host;
    private UMars_VestibulePresentation _Frontend;
    private UMars_WorldBoard_Widget _Board;
    private FCk_Handle_WorldSpaceWidget _WorldWidget;
    private UMars_InputProfile_WorldUI _Profile;
    private UMars_ChalkService_Widget _Services;
    private UMars_ChalkDeparture_Widget _Departure;
    private UMars_ChalkConfirmation_Widget _Confirmation;
    private UWidget _PendingFocus;
    private TArray<FKey> _HeldKeys;
    private bool _PointerHeld = false;
    private bool _VestibuleRequested = false;

    void Initialize(AMars_Camp_PlayerController InController)
    {
        _Controller = InController;
        _Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        if (ck::IsValid(_Flow))
        { _Flow.OnStateChanged.AddUFunction(this, n"RefreshState"); }
        ResolveGameState();

        auto Layout = utils_u_i_layout::Get_LayoutSubsystem(_Controller);
        if (ck::EnsureIfNot(ck::IsValid(Layout), "[CampUiPresenter] the local player has no UI layout subsystem"))
        { return; }
        Layout.OnLayoutCreated_BP.AddUFunction(this, n"OnLayoutCreated");
        Layout.OnInputModeChanged.AddUFunction(this, n"OnInputModeChanged");
    }

    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaSeconds)
    {
        if (ck::IsValid(_Frontend))
        {
            _Frontend.Tick(DeltaSeconds);
            if (!_Frontend.IsOpen())
            { CloseBoard(EMars_CampBoardClose::Teardown); }
        }
        if (ck::Is_NOT_Valid(_State))
        {
            ResolveGameState();
            if (ck::IsValid(_State))
            { RefreshState(); }
        }

        if (ck::IsValid(_PendingFocus) && Interaction.bEnableHitTesting)
        {
            Interaction.SetFocus(_PendingFocus);
            _PendingFocus = nullptr;
        }
    }

    UFUNCTION(BlueprintOverride)
    void EndPlay(EEndPlayReason InReason)
    {
        CloseBoard(EMars_CampBoardClose::Teardown);
        if (ck::IsValid(_Flow))
        { _Flow.OnStateChanged.Unbind(this, n"RefreshState"); }
        if (ck::IsValid(_State))
        { _State.OnPartyStateChanged.Unbind(this, n"RefreshState"); }
        if (ck::IsValid(_Controller))
        {
            auto Layout = utils_u_i_layout::Get_LayoutSubsystem(_Controller);
            if (ck::IsValid(Layout))
            {
                Layout.OnLayoutCreated_BP.Unbind(this, n"OnLayoutCreated");
                Layout.OnInputModeChanged.Unbind(this, n"OnInputModeChanged");
            }
        }
        _Services = nullptr;
        _Departure = nullptr;
        _Controller = nullptr;
    }

    // The main menu board. The HUD layout loads asynchronously; the board waits for it.
    void OpenVestibule()
    {
        if (ck::IsValid(utils_u_i_layout::Get_Layout(_Controller)))
        { DoOpenVestibule(); }
        else
        { _VestibuleRequested = true; }
    }

    void OnChefPossessed()
    {
        _VestibuleRequested = false;
        CloseBoard(EMars_CampBoardClose::Teardown);
    }

    void OpenStation(EMars_CampStation InStation)
    {
        if (ck::EnsureIfNot(ck::IsValid(_Controller) && ck::IsValid(Cast<AMars_PlayerCharacter>(_Controller.GetControlledPawn())),
            "[CampUiPresenter] a camp station opens for a possessed chef only"))
        { return; }

        if (InStation == EMars_CampStation::Contracts)
        {
            if (ck::Is_NOT_Valid(_Services))
            {
                _Services = Cast<UMars_ChalkService_Widget>(CreateBoardWidget(System::LoadClassAsset_Blocking(ServiceClass)));
                if (ck::Is_NOT_Valid(_Services))
                { return; }
                _Services.OnActionRequested.AddUFunction(this, n"HandleAction");
                _Services.OnFocusRequested.AddUFunction(this, n"QueueFocus");
                ResolveGameState();
                if (ck::IsValid(_State))
                { _Services.SetCatalog(_State.ServiceCatalog); }
            }
            OpenBoard(_Services, InStation);
        }
        else if (InStation == EMars_CampStation::Departure)
        {
            if (ck::Is_NOT_Valid(_Departure))
            {
                _Departure = Cast<UMars_ChalkDeparture_Widget>(CreateBoardWidget(System::LoadClassAsset_Blocking(DepartureClass)));
                if (ck::Is_NOT_Valid(_Departure))
                { return; }
                _Departure.OnActionRequested.AddUFunction(this, n"HandleAction");
                _Departure.OnFocusRequested.AddUFunction(this, n"QueueFocus");
            }
            OpenBoard(_Departure, InStation);
        }
        else
        {
            ck::EnsureIfNot(false, f"[CampUiPresenter] station [{InStation}] has no board");
            return;
        }

        RefreshState();
        QueueBoardFocus();
    }

    void CloseBoard(EMars_CampBoardClose InClose)
    {
        _VestibuleRequested = false;
        _PendingFocus = nullptr;
        UI_ReleaseInput();
        Interaction.bEnableHitTesting = false;
        if (ck::IsValid(_Frontend))
        { _Frontend.Close(); _Frontend = nullptr; }
        CloseModals();

        auto Host = _Host;
        _Host = nullptr;
        if (ck::IsValid(Host) && ck::IsValid(_Controller))
        { utils_u_i_layout::RemoveWidget(_Controller, Host); }

        if (ck::IsValid(_WorldWidget))
        {
            utils_world_space_widget::Request_SetEnabled(_WorldWidget, false);
            utils_entity_lifetime::Request_DestroyEntity(_WorldWidget.H());
        }
        _WorldWidget = FCk_Handle_WorldSpaceWidget();
        _Board = nullptr;
        ReleaseProfile();

        if (InClose == EMars_CampBoardClose::ReturnToChef && ck::IsValid(_Controller) && ck::IsValid(_Controller.GetControlledPawn()))
        { _Controller.SetViewTargetWithBlend(_Controller.GetControlledPawn(), constants_camp_ui::k_ReturnToChefBlendSeconds); }
    }

    UFUNCTION()
    private void OnLayoutCreated()
    {
        if (!_VestibuleRequested)
        { return; }
        _VestibuleRequested = false;
        DoOpenVestibule();
    }

    private void DoOpenVestibule()
    {
        // A chef possessed in the meantime owns the view now.
        if (ck::Is_NOT_Valid(Cast<AMars_Camp_ViewerPawn>(_Controller.GetControlledPawn())))
        { return; }

        if (ck::IsValid(_Frontend) && _Frontend.IsOpen())
        { return; }
        CloseBoard(EMars_CampBoardClose::Teardown);
        _Frontend = Cast<UMars_VestibulePresentation>(NewObject(this, UMars_VestibulePresentation));
        _Frontend.OnReleaseInput.AddUFunction(this, n"UI_ReleaseInput");
        if (!_Frontend.Open(_Controller, Interaction, VestibuleClasses))
        { CloseBoard(EMars_CampBoardClose::Teardown); return; }
        AcquireProfile();
        OpenInputHost();
    }

    private UUserWidget CreateBoardWidget(TSubclassOf<UUserWidget> InLoadedClass)
    {
        if (ck::EnsureIfNot(ck::IsValid(InLoadedClass), "[CampUiPresenter] a board widget class is unset or did not load"))
        { return nullptr; }

        auto Widget = WidgetBlueprint::CreateWidget(InLoadedClass, _Controller);
        ck::EnsureIfNot(ck::IsValid(Widget), "[CampUiPresenter] could not create a board widget");
        return Widget;
    }

    private AMars_CampBoardAnchor FindBoardAnchor(EMars_CampStation InStation)
    {
        TArray<AMars_CampBoardAnchor> Anchors;
        GetAllActorsOfClass(Anchors);
        AMars_CampBoardAnchor Anchor;
        int32 Matches = 0;
        for (auto Candidate : Anchors)
        {
            if (ck::IsValid(Candidate) && Candidate.GetWorld() == GetWorld() && Candidate.Station == InStation)
            { Anchor = Candidate; ++Matches; }
        }

        if (ck::EnsureIfNot(Matches == 1 && ck::IsValid(Anchor) && Anchor.DrawSize.X > 0 && Anchor.DrawSize.Y > 0,
            f"[CampUiPresenter] expected one valid board anchor for station [{InStation}], found [{Matches}]"))
        { return nullptr; }

        return Anchor;
    }

    private void OpenBoard(UMars_WorldBoard_Widget InBoard, EMars_CampStation InStation)
    {
        CloseBoard(EMars_CampBoardClose::Teardown);
        auto Anchor = FindBoardAnchor(InStation);
        if (ck::Is_NOT_Valid(Anchor))
        { return; }

        SetActorLocation(Anchor.GetActorLocation());
        SetActorRotation(Anchor.GetActorRotation());
        SetActorScale3D(Anchor.GetActorScale3D());
        auto Spec = FCk_WorldSpaceWidget_Spec(InBoard, ECk_UI_Widget_ViewportOperation::DoNothing, 0);
        Spec.Set_RenderMode(ECk_WorldSpaceWidget_RenderMode::WorldComponent);
        Spec.Set_WorldComponentInfo(FCk_WorldSpaceWidget_WorldComponentInfo(Anchor.DrawSize));
        _WorldWidget = utils_world_space_widget::CreateAndAttach_ToUnrealComponent(Root, Spec);
        if (ck::EnsureIfNot(ck::IsValid(_WorldWidget), f"[CampUiPresenter] could not create the world widget for station [{InStation}]"))
        { return; }

        _Board = InBoard;
        _Controller.FocusStation(InStation, 0.0f);
        utils_world_space_widget::Request_SetEnabled(_WorldWidget, true);
        AcquireProfile();
        OpenInputHost();
    }

    private void OpenInputHost()
    {
        auto Host = Cast<UMars_WorldBoardHost_Widget>(WidgetBlueprint::CreateWidget(UMars_WorldBoardHost_Widget, _Controller));
        if (ck::EnsureIfNot(ck::IsValid(Host), "[CampUiPresenter] could not create the board host widget"))
        { CloseBoard(EMars_CampBoardClose::Teardown); return; }
        Host.OnClosed.AddUFunction(this, n"OnHostClosed");
        Host.OnBackRequested.AddUFunction(this, n"UI_Back");
        _Host = Cast<UMars_WorldBoardHost_Widget>(utils_u_i_layout::PushWidgetToLayer_Instance(_Controller,
            GameplayTags::UI_Layer_GameMenu, Host));
        if (ck::EnsureIfNot(ck::IsValid(_Host), "[CampUiPresenter] UI.Layer.GameMenu refused the board host widget"))
        { CloseBoard(EMars_CampBoardClose::Teardown); return; }

        RefreshBoardInput();
    }

    // The layer dropped the host underneath us (world teardown, a layer clear): the board goes with it.
    UFUNCTION()
    private void OnHostClosed()
    {
        if (ck::Is_NOT_Valid(_Host))
        { return; }
        _Host = nullptr;
        CloseBoard(EMars_CampBoardClose::Teardown);
    }

    UFUNCTION()
    private void OnInputModeChanged(ECk_UI_InputMode InMode)
    { RefreshBoardInput(); }

    // The board takes pointer and key input only while the layout's effective mode is the host's GameAndUI; any
    // screen modal above it (UIOnly) suspends the board until it closes.
    private void RefreshBoardInput()
    {
        if (ck::IsValid(_Frontend) && _Frontend.IsOpen())
        { _Frontend.RefreshInput(); return; }
        const bool Interactive = ck::IsValid(_Board) && ck::IsValid(_Controller) &&
            utils_u_i_layout::Get_EffectiveInputMode(_Controller) == ECk_UI_InputMode::GameAndUI;
        if (Interactive == Interaction.bEnableHitTesting)
        { return; }

        if (!Interactive)
        { UI_ReleaseInput(); }
        Interaction.bEnableHitTesting = Interactive;
        if (Interactive)
        { QueueBoardFocus(); }
    }

    private void AcquireProfile()
    {
        if (ck::IsValid(_Profile))
        { return; }
        _Controller.PushInputComponent(_Controller.InputComp);
        _Profile = Cast<UMars_InputProfile_WorldUI>(_Controller.InputComp.PushProfile(
            UMars_InputProfile_WorldUI, _Controller.GetControlledPawn(), EMars_InputActivationMode::Replace));
        if (ck::EnsureIfNot(ck::IsValid(_Profile), "[CampUiPresenter] could not push the world UI input profile"))
        { return; }
        _Profile.SetPresenter(this);
    }

    private void ReleaseProfile()
    {
        if (ck::IsValid(_Controller) && ck::IsValid(_Profile))
        {
            if (_Controller.InputComp.GetActiveProfile() == _Profile)
            { _Controller.InputComp.PopProfile(); }
            _Controller.InputComp.ClearBindingsForObject(_Profile);
            _Profile.SetPresenter(nullptr);
        }
        _Profile = nullptr;
    }

    private void ResolveGameState()
    {
        if (ck::IsValid(_State))
        { return; }
        _State = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::IsValid(_State))
        { _State.OnPartyStateChanged.AddUFunction(this, n"RefreshState"); }
    }

    UFUNCTION()
    private void QueueFocus(UWidget InTarget)
    { _PendingFocus = InTarget; }

    private void QueueBoardFocus()
    {
        _PendingFocus = nullptr;
        if (ck::IsValid(_Board))
        { _PendingFocus = _Board.GetPreferredFocusTarget(); }
    }

    private bool CanCommit() const
    {
        return ck::IsValid(_Controller) && _Controller.HasAuthority() &&
            GetWorld().GetNetMode() == ENetMode::NM_ListenServer &&
            ck::IsValid(_Flow) && _Flow.GetState() == EMars_LanFlowState::Connected;
    }

    UFUNCTION()
    private void RefreshState()
    {
        ResolveGameState();
        if (ck::IsValid(_Services) && ck::IsValid(_State))
        {
            _Services.SetPartyState(_State.Get_PartyState(), CanCommit());
            _Services.SetStatus(CanCommit()
                ? NSLOCTEXT("MarsCamp", "HostSelection", "Confirm a service here, then use the departure gate.")
                : NSLOCTEXT("MarsCamp", "GuestSelection", "Browse freely. The host confirms the party's service."));
        }

        if (ck::IsValid(_Departure) && ck::IsValid(_State))
        { _Departure.SetPartyState(_State.Get_PartyState(), _State.ServiceCatalog, CanCommit()); }
    }

    UFUNCTION()
    private void HandleAction(EMars_CampUiAction InAction)
    {
        if (InAction == EMars_CampUiAction::Back)
        { UI_Back(); }
        else if (InAction == EMars_CampUiAction::ConfirmService)
        {
            if (ck::IsValid(_Services) && CanCommit())
            { _Controller.Server_CommitService(_Services.GetPreviewServiceId()); }
        }
        else if (InAction == EMars_CampUiAction::Depart)
        {
            if (ck::IsValid(_Departure) && _Board == _Departure && ck::IsValid(_State) && CanCommit() &&
                !_State.Get_PartyState().ServiceId.IsNone() && !_State.Get_PartyState().IsDeparting)
            {
                ShowConfirmation(FMars_ChalkConfirmation_Spec(
                    NSLOCTEXT("MarsCamp", "DepartTitle", "Depart for adventure?"),
                    NSLOCTEXT("MarsCamp", "DepartMessage", "The whole party will leave camp for the selected service."),
                    NSLOCTEXT("MarsCamp", "DepartConfirm", "Depart")));
            }
        }
    }

    private UMars_ChalkConfirmation_Widget CreateConfirmation(const FMars_ChalkConfirmation_Spec& InSpec)
    {
        auto WidgetClass = System::LoadClassAsset_Blocking(ConfirmationClass);
        if (ck::EnsureIfNot(ck::IsValid(WidgetClass), "[CampUiPresenter] the confirmation widget class is unset or did not load"))
        { return nullptr; }

        auto Modal = Cast<UMars_ChalkConfirmation_Widget>(WidgetBlueprint::CreateWidget(WidgetClass, _Controller));
        if (ck::EnsureIfNot(ck::IsValid(Modal), "[CampUiPresenter] could not create the confirmation widget"))
        { return nullptr; }

        Modal.Configure(InSpec);
        Modal.OnClosed.AddUFunction(this, n"OnModalClosed");
        return Modal;
    }

    private UCommonActivatableWidget PushModal(UCommonActivatableWidget InModal)
    {
        auto Pushed = utils_u_i_layout::PushWidgetToLayer_Instance(_Controller, GameplayTags::UI_Layer_Modal, InModal);
        ck::EnsureIfNot(ck::IsValid(Pushed), "[CampUiPresenter] UI.Layer.Modal refused a modal widget");
        return Pushed;
    }

    private void ShowConfirmation(const FMars_ChalkConfirmation_Spec& InSpec)
    {
        if (ck::IsValid(_Confirmation))
        { return; }

        auto Modal = CreateConfirmation(InSpec);
        if (ck::Is_NOT_Valid(Modal))
        { return; }

        Modal.OnResult.AddUFunction(this, n"OnConfirmationResult");
        _Confirmation = Cast<UMars_ChalkConfirmation_Widget>(PushModal(Modal));
    }

    UFUNCTION()
    private void OnConfirmationResult(bool InConfirmed)
    {
        if (!InConfirmed)
        { return; }

        if (CanCommit())
        { _Controller.Server_RequestDepart(); }
    }

    UFUNCTION()
    private void OnModalClosed(UCommonActivatableWidget InModal)
    {
        if (InModal == _Confirmation)
        { _Confirmation = nullptr; }
    }

    private void CloseModals()
    {
        auto Confirmation = _Confirmation;
        _Confirmation = nullptr;
        if (ck::IsValid(Confirmation))
        { Confirmation.DeactivateWidget(); }
    }

    void UI_PointerPressed()
    {
        if (!Interaction.bEnableHitTesting || _PointerHeld)
        { return; }
        _PointerHeld = true;
        Interaction.PressPointerKey(EKeys::LeftMouseButton);
    }

    void UI_PointerReleased()
    {
        if (!_PointerHeld)
        { return; }
        _PointerHeld = false;
        Interaction.ReleasePointerKey(EKeys::LeftMouseButton);
    }

    bool UI_TryAdvanceTitle()
    {
        if (ck::IsValid(_Frontend))
        { return _Frontend.AdvanceTitle(); }
        return false;
    }

    void UI_KeyPressed(FKey InKey)
    {
        if (!Interaction.bEnableHitTesting || _HeldKeys.Contains(InKey))
        { return; }
        if (ck::IsValid(_Frontend))
        { _Frontend.SetNavigationPresentation(); }
        else if (ck::IsValid(_Board))
        { _Board.SetNavigationPresentation(true); }
        _HeldKeys.Add(InKey);
        Interaction.PressKey(InKey);
    }

    void UI_KeyReleased(FKey InKey)
    {
        if (!_HeldKeys.Contains(InKey))
        { return; }
        _HeldKeys.Remove(InKey);
        Interaction.ReleaseKey(InKey);
    }

    UFUNCTION()
    void UI_ReleaseInput()
    {
        UI_PointerReleased();
        auto Keys = _HeldKeys;
        _HeldKeys.Empty();
        for (auto Key : Keys)
        { Interaction.ReleaseKey(Key); }
    }

    UFUNCTION()
    void UI_Back()
    {
        if (ck::IsValid(_Frontend))
        { _Frontend.Back(); return; }
        if (ck::IsValid(_Board))
        { CloseBoard(EMars_CampBoardClose::ReturnToChef); }
    }

    void UI_Scroll(float32 InDelta)
    {
        if (Interaction.bEnableHitTesting)
        { Interaction.ScrollWheel(InDelta); }
    }
}
