enum EMars_CampBoardClose
{
    // Blend the view back to the possessed chef.
    ReturnToChef,
    // Drop the board only; the view is someone else's to move (possession change, world teardown).
    Teardown,
    // A forced gameplay view (Devour) takes ownership without a menu blend-out.
    GameplayTakeover
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
    TSoftClassPtr<UMars_ChalkService_Widget> ServiceClass = mars::Mars_StewardService_Config.WidgetClass;

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    TSoftClassPtr<UMars_ChalkDeparture_Widget> DepartureClass = assets::Departure_Mars_WBP_Class();

    private AMars_Camp_PlayerController _Controller;
    private UMars_LanFlow_Subsystem _Flow;
    private AMars_Camp_GameState _State;
    private UMars_WorldBoardHost_Widget _Host;
    private UMars_VestibulePresentation _Frontend;
    private UMars_WorldBoard_Widget _Board;
    private FCk_Handle_WorldSpaceWidget _WorldWidget;
    private FCk_Handle_WorldSpaceWidget _ServiceWorldWidget;
    private UMars_InputProfile_WorldUI _Profile;
    private UMars_ChalkService_Widget _Services;
    private UMars_ChalkDeparture_Widget _Departure;
    private UMars_ChalkConfirmation_Widget _Confirmation;
    private UWidget _PendingFocus;
    private TArray<FKey> _HeldKeys;
    private bool _PointerHeld = false;
    private bool _VestibuleRequested = false;
    private FCk_Handle_PlayerViewpoint _StationViewpoint;
    private FCk_Handle _StationViewOwner;
    private FCk_Handle_Transform _ServiceViewNode;
    private FCk_Handle_Transform _DepartureViewNode;
    private FName _AwaitingServiceId;
    private TArray<TWeakObjectPtr<UPrimitiveComponent>> _MenuHiddenPrimitives;

    void Initialize(AMars_Camp_PlayerController InController)
    {
        _Controller = InController;
        _Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        if (ck::IsValid(_Flow))
        { _Flow.OnStateChanged.AddUFunction(this, n"RefreshState"); }
        ResolveGameState();
        EnsureServiceSurface();

        auto Layout = utils_u_i_layout::Get_LayoutSubsystem(_Controller);
        if (ck::EnsureIfNot(ck::IsValid(Layout), "[CampUiPresenter] the local player has no UI layout subsystem"))
        { return; }
        Layout.OnLayoutCreated_BP.AddUFunction(this, n"OnLayoutCreated");
        Layout.OnInputModeChanged.AddUFunction(this, n"OnInputModeChanged");
    }

    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaSeconds)
    {
        EnsureServiceSurface();
        if (ck::IsValid(_Board) && ck::IsValid(_StationViewpoint) &&
            _StationViewpoint.Get_Camera().Has_Layer(UMars_CameraLayer_Devour))
        { CloseBoard(EMars_CampBoardClose::GameplayTakeover); }
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
        if (ck::IsValid(_ServiceWorldWidget))
        { utils_entity_lifetime::Request_DestroyEntity(_ServiceWorldWidget.H()); }
        _ServiceWorldWidget = FCk_Handle_WorldSpaceWidget();
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
            EnsureServiceSurface();
            if (ck::Is_NOT_Valid(_Services))
            { return; }
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
        _AwaitingServiceId = NAME_None;
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
        if (ck::IsValid(_Services))
        {
            _Services.SetVisibility(ESlateVisibility::HitTestInvisible);
            _Services.SetNavigationPresentation(false);
        }
        ReleaseProfile();

        ReleaseStationView(InClose == EMars_CampBoardClose::GameplayTakeover);
        RestoreChefPresentation();
        RefreshServiceStatus();
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

    private void EnsureServiceSurface()
    {
        if (ck::IsValid(_ServiceWorldWidget) || ck::Is_NOT_Valid(_Controller) ||
            ck::Is_NOT_Valid(_State) || ck::Is_NOT_Valid(_State.ServiceCatalog))
        { return; }
        auto Anchor = FindBoardAnchor(EMars_CampStation::Contracts);
        if (ck::Is_NOT_Valid(Anchor))
        { return; }
        if (ck::Is_NOT_Valid(_Services))
        {
            _Services = Cast<UMars_ChalkService_Widget>(CreateBoardWidget(System::LoadClassAsset_Blocking(ServiceClass)));
            if (ck::Is_NOT_Valid(_Services))
            { return; }
            _Services.OnActionRequested.AddUFunction(this, n"HandleAction");
            _Services.OnFocusRequested.AddUFunction(this, n"QueueFocus");
            _Services.SetCatalog(_State.ServiceCatalog);
            _Services.SetVisibility(ESlateVisibility::HitTestInvisible);
            _Services.SetNavigationPresentation(false);
        }
        auto Spec = FCk_WorldSpaceWidget_Spec(_Services, ECk_UI_Widget_ViewportOperation::DoNothing, 0);
        Spec.Set_RenderMode(ECk_WorldSpaceWidget_RenderMode::WorldComponent);
        Spec.Set_WorldComponentInfo(FCk_WorldSpaceWidget_WorldComponentInfo(Anchor.DrawSize));
        // The fixed parchment anchor owns its surface, independent of the active board/camera/input lifetime.
        _ServiceWorldWidget = utils_world_space_widget::CreateAndAttach_ToUnrealComponent(Anchor.Root, Spec);
        if (ck::EnsureIfNot(ck::IsValid(_ServiceWorldWidget), "[CampUiPresenter] could not create persistent parchment"))
        { return; }
        utils_world_space_widget::Request_SetEnabled(_ServiceWorldWidget, true);
        RefreshState();
    }

    private AMars_CampBoardAnchor FindBoardAnchor(EMars_CampStation InStation)
    {
        auto Anchor = utils_camp_station::TryGet_BoardAnchor(GetWorld(), InStation);
        if (ck::Is_NOT_Valid(Anchor))
        { return nullptr; }

        if (ck::EnsureIfNot(Anchor.DrawSize.X > 0 && Anchor.DrawSize.Y > 0,
            f"[CampUiPresenter] the board anchor for station [{InStation}] has no draw size"))
        { return nullptr; }

        return Anchor;
    }

    private void OpenBoard(UMars_WorldBoard_Widget InBoard, EMars_CampStation InStation)
    {
        CloseBoard(EMars_CampBoardClose::Teardown);
        auto Anchor = FindBoardAnchor(InStation);
        if (ck::Is_NOT_Valid(Anchor))
        { return; }

        if (InBoard == _Services)
        { _Services.SetVisibility(ESlateVisibility::Visible); }
        else
        {
            SetActorLocation(Anchor.GetActorLocation());
            SetActorRotation(Anchor.GetActorRotation());
            SetActorScale3D(Anchor.GetActorScale3D());
            auto Spec = FCk_WorldSpaceWidget_Spec(InBoard, ECk_UI_Widget_ViewportOperation::DoNothing, 0);
            Spec.Set_RenderMode(ECk_WorldSpaceWidget_RenderMode::WorldComponent);
            Spec.Set_WorldComponentInfo(FCk_WorldSpaceWidget_WorldComponentInfo(Anchor.DrawSize));
            _WorldWidget = utils_world_space_widget::CreateAndAttach_ToUnrealComponent(Root, Spec);
            if (ck::EnsureIfNot(ck::IsValid(_WorldWidget), f"[CampUiPresenter] could not create the world widget for station [{InStation}]"))
            { return; }
            utils_world_space_widget::Request_SetEnabled(_WorldWidget, true);
        }

        _Board = InBoard;
        if (AcquireStationView(InStation) == false)
        { CloseBoard(EMars_CampBoardClose::Teardown); return; }
        AcquireProfile();
        OpenInputHost();
    }

    // Each stationary endpoint lives through blend-out under its chef. Switching boards cannot move an outgoing target.
    private bool AcquireStationView(EMars_CampStation InStation)
    {
        const auto Validation = mars::Mars_StewardService_Config.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[CampUiPresenter] invalid service presentation: {Validation.Get_Error()}"))
        { return false; }
        auto Player = ck::ToEntity(_Controller.GetControlledPawn());
        auto Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        auto Endpoint = utils_camp_station::TryGet_Camera(GetWorld(), InStation);
        if (ck::EnsureIfNot(ck::IsValid(Viewpoint) && ck::IsValid(Endpoint), "[CampUiPresenter] station needs a chef viewpoint and endpoint"))
        { return false; }
        if (_StationViewOwner != Player)
        {
            _StationViewOwner = Player;
            _ServiceViewNode = FCk_Handle_Transform();
            _DepartureViewNode = FCk_Handle_Transform();
        }
        auto ViewNode = InStation == EMars_CampStation::Contracts ? _ServiceViewNode : _DepartureViewNode;
        if (ck::Is_NOT_Valid(ViewNode))
        {
            auto Node = utils_entity_lifetime::Request_CreateEntity(Player);
            ViewNode = utils_transform::Add(Node, Endpoint.GetActorTransform(), ECk_Replication::DoesNotReplicate);
            if (InStation == EMars_CampStation::Contracts)
            { _ServiceViewNode = ViewNode; }
            else
            { _DepartureViewNode = ViewNode; }
        }

        _StationViewpoint = Viewpoint;
        HideChefPresentation();
        _StationViewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::CampMenu));
        auto Request = FCk_Request_Camera_AddLayer(UMars_CameraLayer_CampService);
        Request.Set_StackingBehavior(ECk_Camera_StackingBehavior::OneOnly);
        Request.Set_Priority(10);
        Request.Set_BlendInTime(FCk_Time(mars::Mars_StewardService_Config.View.BlendInSeconds));
        Request.Set_CameraTarget(FCk_Camera_Target(ViewNode, ECk_Camera_TargetMode::ViewTarget));
        auto Camera = _StationViewpoint.Get_Camera();
        Camera.Request_AddLayer(Request);
        return true;
    }

    private void ReleaseStationView(bool InImmediate)
    {
        if (ck::IsValid(_StationViewpoint))
        {
            auto Camera = _StationViewpoint.Get_Camera();
            if (ck::IsValid(Camera) && Camera.Get_CanCreateEntity())
            {
                auto Request = FCk_Request_Camera_RemoveLayer(UMars_CameraLayer_CampService);
                Request.Set_BlendOutTime(FCk_Time(InImmediate ? 0.0f : mars::Mars_StewardService_Config.View.BlendOutSeconds));
                Camera.Request_RemoveLayer(Request);
            }
            _StationViewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::CampMenu));
        }
        _StationViewpoint = FCk_Handle_PlayerViewpoint();
    }

    private void HideChefPrimitive(UPrimitiveComponent InPrimitive)
    {
        if (ck::IsValid(InPrimitive) && InPrimitive.bHiddenInGame == false)
        {
            _MenuHiddenPrimitives.Add(TWeakObjectPtr<UPrimitiveComponent>(InPrimitive));
            InPrimitive.SetHiddenInGame(true);
        }
    }

    // The hand chain rides the director, including remote menu targets. Hide its local presentation while reading.
    private void HideChefPresentation()
    {
        auto Chef = Cast<AMars_PlayerCharacter>(_Controller.GetControlledPawn());
        if (ck::Is_NOT_Valid(Chef))
        { return; }
        HideChefPrimitive(Chef.FPHands);
        auto Hands = ck::ToEntity(Chef).As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hands))
        { return; }
        for (auto Entity : utils_fphands::Get_TransformTree(Hands.Get_HandNode()))
        {
            for (auto Component : utils_unreal_component::Get_ComponentsByType(Entity, UPrimitiveComponent))
            { HideChefPrimitive(Cast<UPrimitiveComponent>(Component)); }
        }
    }

    private void RestoreChefPresentation()
    {
        for (auto WeakPrimitive : _MenuHiddenPrimitives)
        {
            auto Primitive = WeakPrimitive.Get();
            if (ck::IsValid(Primitive))
            { Primitive.SetHiddenInGame(false); }
        }
        _MenuHiddenPrimitives.Empty();
    }

    private void OpenInputHost()
    {
        TSubclassOf<UMars_WorldBoardHost_Widget> HostClass = UMars_WorldBoardHost_Widget;
        if (ck::IsValid(_Board))
        { HostClass = UMars_StationWorldBoardHost_Widget; }
        auto Host = Cast<UMars_WorldBoardHost_Widget>(WidgetBlueprint::CreateWidget(HostClass, _Controller));
        if (ck::EnsureIfNot(ck::IsValid(Host), "[CampUiPresenter] could not create the board host widget"))
        { CloseBoard(EMars_CampBoardClose::Teardown); return; }
        Host.bCaptureStationPointer = ck::IsValid(_Board);
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
            RefreshServiceStatus();
        }

        if (ck::IsValid(_Departure) && ck::IsValid(_State))
        { _Departure.SetPartyState(_State.Get_PartyState(), _State.ServiceCatalog, CanCommit()); }

        if (!_AwaitingServiceId.IsNone() && ck::IsValid(_State) && _State.Get_PartyState().ServiceId == _AwaitingServiceId)
        { CloseBoard(EMars_CampBoardClose::ReturnToChef); }
    }

    private void RefreshServiceStatus()
    {
        if (ck::Is_NOT_Valid(_Services) || ck::Is_NOT_Valid(_State))
        { return; }
        const auto Party = _State.Get_PartyState();
        _Services.SetStatus(_Board == _Services
            ? CanCommit()
                ? NSLOCTEXT("MarsCamp", "StewardConfirmToOpen", "Choose a dish, then confirm to open the Spire.")
                : NSLOCTEXT("MarsCamp", "StewardGuestSelection", "The host selects for the party.")
            : Party.ServiceId.IsNone()
                ? NSLOCTEXT("MarsCamp", "StewardIdleNoService", "Speak to the Steward to choose a service.")
                : NSLOCTEXT("MarsCamp", "StewardIdleCommitted", "Service confirmed. The Spire is open."));
    }

    UFUNCTION()
    private void HandleAction(EMars_CampUiAction InAction)
    {
        if (InAction == EMars_CampUiAction::Back)
        { UI_Back(); }
        else if (InAction == EMars_CampUiAction::ConfirmService)
        {
            if (ck::IsValid(_Services) && CanCommit())
            {
                // Wait for the authoritative acknowledgement, including a repeat selection of the current service.
                _AwaitingServiceId = _Services.GetPreviewServiceId();
                _Controller.Server_CommitService(_AwaitingServiceId);
                RefreshState();
            }
        }
        else if (InAction == EMars_CampUiAction::Depart)
        {
            if (ck::IsValid(_Departure) && _Board == _Departure && ck::IsValid(_State) && CanCommit() &&
                !_State.Get_PartyState().ServiceId.IsNone() && _State.Get_PartyState().Departure != EMars_PartyDeparture::Departing)
            {
                ShowConfirmation(FMars_ChalkConfirmation_Spec(
                    NSLOCTEXT("MarsCamp", "DepartTitle", "Depart for adventure?"),
                    NSLOCTEXT("MarsCamp", "DepartMessage", "The whole party will leave camp for the selected service."),
                    NSLOCTEXT("MarsCamp", "DepartConfirm", "Depart")));
            }
        }
    }

    private void ShowConfirmation(const FMars_ChalkConfirmation_Spec& InSpec)
    {
        if (ck::IsValid(_Confirmation))
        { return; }

        _Confirmation = utils_chalk_confirmation::Push(_Controller, System::LoadClassAsset_Blocking(ConfirmationClass), InSpec);
        if (ck::Is_NOT_Valid(_Confirmation))
        { return; }

        _Confirmation.OnResult.AddUFunction(this, n"OnConfirmationResult");
        _Confirmation.OnClosed.AddUFunction(this, n"OnModalClosed");
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
