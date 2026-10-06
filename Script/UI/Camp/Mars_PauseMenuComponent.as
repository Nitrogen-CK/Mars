enum EMars_PauseClose
{
    // Hand input back to the gameplay profile underneath.
    Resume,
    // Drop every profile; the owner is being torn down or re-pointed.
    Teardown
}

// Local-only pause owner shared by gameplay and a playable camp chef. The CkUI layout owns the input mode.
class UMars_PauseMenuComponent : UActorComponent
{
    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    TSoftClassPtr<UMars_ChalkPause_Widget> PauseClass = assets::Pause_Mars_WBP_Class();

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    TSoftClassPtr<UCommonActivatableWidget> SettingsClass = TSoftClassPtr<UCommonActivatableWidget>(FSoftObjectPath(
        "/Game/Mars/UI/Widgets/ChalkParchment/Settings_Mars_WBP.Settings_Mars_WBP_C"));

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    TSoftClassPtr<UMars_ChalkConfirmation_Widget> ConfirmationClass = assets::Confirmation_Mars_WBP_Class();

    private UMars_ChalkPause_Widget _Pause;
    private UMars_ChalkConfirmation_Widget _Confirmation;
    private UMars_InputProfile_Pause _PauseProfile;
    private EMars_ChalkPauseAction _ConfirmationAction;

    UFUNCTION(BlueprintOverride)
    void EndPlay(EEndPlayReason InReason)
    { ClosePause(EMars_PauseClose::Teardown); }

    UFUNCTION()
    void OpenPause()
    {
        auto Controller = GetController();
        if (ck::Is_NOT_Valid(Controller) || !Controller.IsLocalController() || ck::IsValid(_Pause) ||
            ck::Is_NOT_Valid(Cast<UMars_InputProfile_Gameplay>(Controller.InputComp.GetActiveProfile())))
        { return; }

        auto WidgetClass = System::LoadClassAsset_Blocking(PauseClass);
        if (ck::EnsureIfNot(ck::IsValid(WidgetClass), "[PauseMenu] the pause widget class is unset or did not load"))
        { return; }

        auto PauseWidget = Cast<UMars_ChalkPause_Widget>(WidgetBlueprint::CreateWidget(WidgetClass, Controller));
        if (ck::EnsureIfNot(ck::IsValid(PauseWidget), "[PauseMenu] could not create the pause widget"))
        { return; }

        PauseWidget.SetCanReturnToCamp(CanReturnToCamp(Controller));
        PauseWidget.OnActionRequested.AddUFunction(this, n"OnPauseAction");

        _PauseProfile = Cast<UMars_InputProfile_Pause>(Controller.InputComp.PushProfile(
            UMars_InputProfile_Pause, Controller.GetControlledPawn(), EMars_InputActivationMode::Replace));
        if (ck::EnsureIfNot(ck::IsValid(_PauseProfile), "[PauseMenu] could not push the pause input profile"))
        { return; }

        _Pause = Cast<UMars_ChalkPause_Widget>(utils_u_i_layout::PushWidgetToLayer_Instance(Controller,
            GameplayTags::UI_Layer_Menu, PauseWidget));
        if (ck::EnsureIfNot(ck::IsValid(_Pause), "[PauseMenu] UI.Layer.Menu refused the pause widget"))
        {
            Controller.InputComp.PopProfile();
            _PauseProfile = nullptr;
        }
    }

    UFUNCTION()
    void ClosePause(EMars_PauseClose InClose)
    {
        if (ck::Is_NOT_Valid(_Pause) && ck::Is_NOT_Valid(_PauseProfile))
        { return; }

        auto Controller = GetController();
        if (ck::IsValid(Controller))
        {
            if (ck::IsValid(_Confirmation))
            { _Confirmation.DeactivateWidget(); }
            if (ck::IsValid(_Pause))
            { utils_u_i_layout::RemoveWidget(Controller, _Pause); }

            if (ck::IsValid(_PauseProfile) && Controller.InputComp.GetActiveProfile() == _PauseProfile)
            {
                Controller.InputComp.PopProfile(InClose == EMars_PauseClose::Resume
                    ? EMars_InputDeactivationMode::Pop
                    : EMars_InputDeactivationMode::PopAll);
            }
        }

        _Confirmation = nullptr;
        _Pause = nullptr;
        _PauseProfile = nullptr;
    }

    private AMars_Master_PlayerController GetController() const
    { return Cast<AMars_Master_PlayerController>(GetOwner()); }

    private bool CanReturnToCamp(AMars_Master_PlayerController InController) const
    {
        return ck::IsValid(Cast<AMars_Gameplay_PlayerController>(InController)) &&
            InController.HasAuthority() && InController.IsLocalController() &&
            InController.GetWorld().GetNetMode() == ENetMode::NM_ListenServer;
    }

    UFUNCTION()
    private void OnPauseAction(EMars_ChalkPauseAction InAction)
    {
        auto Controller = GetController();
        if (ck::Is_NOT_Valid(Controller) || ck::Is_NOT_Valid(_Pause))
        { return; }

        if (InAction == EMars_ChalkPauseAction::Resume)
        { ClosePause(EMars_PauseClose::Resume); }
        else if (InAction == EMars_ChalkPauseAction::Settings)
        {
            utils_u_i_layout::PushWidgetToLayer_Soft(Controller, GameplayTags::UI_Layer_Menu, SettingsClass,
                FCk_Delegate_UI_OnWidgetReady());
        }
        else if (InAction == EMars_ChalkPauseAction::ReturnToCamp && CanReturnToCamp(Controller))
        {
            ShowPauseConfirmation(InAction, FMars_ChalkConfirmation_Spec(
                NSLOCTEXT("MarsPause", "ReturnTitle", "Return to camp?"),
                NSLOCTEXT("MarsPause", "ReturnMessage", "The party will leave this expedition."),
                NSLOCTEXT("MarsPause", "ReturnConfirm", "Return")));
        }
        else if (InAction == EMars_ChalkPauseAction::Leave)
        {
            ShowPauseConfirmation(InAction, FMars_ChalkConfirmation_Spec(
                NSLOCTEXT("MarsPause", "LeaveTitle", "Leave to menu?"),
                NSLOCTEXT("MarsPause", "LeaveMessage", "Leave this session and return to the camp menu."),
                NSLOCTEXT("MarsPause", "LeaveConfirm", "Leave")));
        }
    }

    private void ShowPauseConfirmation(EMars_ChalkPauseAction InAction, const FMars_ChalkConfirmation_Spec& InSpec)
    {
        if (ck::IsValid(_Confirmation))
        { return; }

        auto Controller = GetController();
        auto WidgetClass = System::LoadClassAsset_Blocking(ConfirmationClass);
        if (ck::EnsureIfNot(ck::IsValid(WidgetClass), "[PauseMenu] the confirmation widget class is unset or did not load"))
        { return; }

        auto Modal = Cast<UMars_ChalkConfirmation_Widget>(WidgetBlueprint::CreateWidget(WidgetClass, Controller));
        if (ck::EnsureIfNot(ck::IsValid(Modal), "[PauseMenu] could not create the confirmation widget"))
        { return; }

        Modal.Configure(InSpec);
        Modal.OnResult.AddUFunction(this, n"OnPauseConfirmationResult");
        Modal.OnClosed.AddUFunction(this, n"OnConfirmationClosed");
        _ConfirmationAction = InAction;
        _Confirmation = Cast<UMars_ChalkConfirmation_Widget>(utils_u_i_layout::PushWidgetToLayer_Instance(Controller,
            GameplayTags::UI_Layer_Modal, Modal));
        ck::EnsureIfNot(ck::IsValid(_Confirmation), "[PauseMenu] UI.Layer.Modal refused the confirmation widget");
    }

    UFUNCTION()
    private void OnPauseConfirmationResult(bool InConfirmed)
    {
        auto Controller = GetController();
        if (!InConfirmed || ck::Is_NOT_Valid(Controller))
        { return; }

        const auto ConfirmedAction = _ConfirmationAction;
        ClosePause(EMars_PauseClose::Resume);
        if (ConfirmedAction == EMars_ChalkPauseAction::ReturnToCamp && CanReturnToCamp(Controller))
        { Cast<AMars_Gameplay_PlayerController>(Controller).Server_ReturnToCamp(); }
        else if (ConfirmedAction == EMars_ChalkPauseAction::Leave)
        {
            auto Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
            if (ck::IsValid(Flow))
            { Flow.ReturnToMenu(); }
        }
    }

    UFUNCTION()
    private void OnConfirmationClosed(UCommonActivatableWidget InModal)
    {
        if (InModal == _Confirmation)
        { _Confirmation = nullptr; }
    }
}
