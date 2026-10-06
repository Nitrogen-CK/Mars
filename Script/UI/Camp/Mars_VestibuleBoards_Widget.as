// The main menu board: a title page, then the four menu actions.
UCLASS(Abstract)
class UMars_VestibuleMain_Widget : UMars_WorldBoard_Widget
{
    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Start;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Host;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Join;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Settings;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Quit;

    UPROPERTY(meta = (BindWidget))
    UWidget MenuActions;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock Status;

    private bool _TitleActive = true;
    private EMars_CampUiAction _PreferredReturnAction = EMars_CampUiAction::Host;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        Start.OnButtonBaseClicked.AddUFunction(this, n"OnStartClicked");
        Host.OnButtonBaseClicked.AddUFunction(this, n"OnHostClicked");
        Join.OnButtonBaseClicked.AddUFunction(this, n"OnJoinClicked");
        Settings.OnButtonBaseClicked.AddUFunction(this, n"OnSettingsClicked");
        Quit.OnButtonBaseClicked.AddUFunction(this, n"OnQuitClicked");
        Start.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
        Host.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
        Join.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
        Settings.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
        Quit.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        Start.ButtonText = NSLOCTEXT("MarsVestibule", "Start", "Press any key");
        Host.ButtonText = NSLOCTEXT("MarsVestibule", "Host", "Host");
        Join.ButtonText = NSLOCTEXT("MarsVestibule", "Join", "Join");
        Settings.ButtonText = NSLOCTEXT("MarsVestibule", "Settings", "Settings");
        Quit.ButtonText = NSLOCTEXT("MarsVestibule", "Quit", "Quit");
        Start.RefreshLabel();
        Host.RefreshLabel();
        Join.RefreshLabel();
        Settings.RefreshLabel();
        Quit.RefreshLabel();
        Start.SetVisibility(_TitleActive ? ESlateVisibility::Visible : ESlateVisibility::Collapsed);
        MenuActions.SetVisibility(_TitleActive ? ESlateVisibility::Collapsed : ESlateVisibility::SelfHitTestInvisible);
        SetNavigationPresentation(false);
    }

    bool AdvanceFromTitle()
    {
        if (!_TitleActive)
        { return false; }
        ShowMenu();
        return true;
    }

    void ShowMenu()
    {
        _TitleActive = false;
        Start.SetVisibility(ESlateVisibility::Collapsed);
        MenuActions.SetVisibility(ESlateVisibility::SelfHitTestInvisible);
        OnFocusRequested.Broadcast(GetPreferredFocusTarget());
    }

    void SetPreferredReturnAction(EMars_CampUiAction InAction)
    {
        if (InAction == EMars_CampUiAction::Host || InAction == EMars_CampUiAction::Join ||
            InAction == EMars_CampUiAction::Settings || InAction == EMars_CampUiAction::Quit)
        { _PreferredReturnAction = InAction; }
    }

    UWidget GetPreferredFocusTarget() const override
    {
        if (_TitleActive)
        { return Start; }
        if (_PreferredReturnAction == EMars_CampUiAction::Join)
        { return Join; }
        if (_PreferredReturnAction == EMars_CampUiAction::Settings)
        { return Settings; }
        if (_PreferredReturnAction == EMars_CampUiAction::Quit)
        { return Quit; }
        return Host;
    }

    void SetStatus(FText InStatus)
    {
        if (ck::IsValid(Status))
        { Status.SetText(InStatus); }
    }

    void SetActionState(EMars_ButtonState InState)
    {
        Host.SetActionState(InState);
        Join.SetActionState(InState);
        Settings.SetActionState(InState);
        Quit.SetActionState(InState);
    }

    void SetNavigationPresentation(bool InNavigation) override
    {
        Start.SetNavigationPresentation(InNavigation);
        Host.SetNavigationPresentation(InNavigation);
        Join.SetNavigationPresentation(InNavigation);
        Settings.SetNavigationPresentation(InNavigation);
        Quit.SetNavigationPresentation(InNavigation);
    }

    UFUNCTION()
    private void OnStartClicked(UCommonButtonBase InButton)
    { AdvanceFromTitle(); }

    UFUNCTION()
    private void OnHostClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_CampUiAction::Host); }

    UFUNCTION()
    private void OnJoinClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_CampUiAction::Join); }

    UFUNCTION()
    private void OnSettingsClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_CampUiAction::Settings); }

    UFUNCTION()
    private void OnQuitClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_CampUiAction::Quit); }

    UFUNCTION()
    private void OnButtonHovered(UCommonButtonBase InButton)
    { SetNavigationPresentation(false); }
}

// The join form can be a screen modal or a world board. In world mode the presenter owns navigation and Back.
UCLASS(Abstract)
class UMars_VestibuleJoin_Widget : UCk_ActivatableWidget_UE
{
    default bIsFocusable = true;
    default bIsBackHandler = true;

    UPROPERTY(meta = (BindWidget))
    UMars_ChalkInput_Widget Address;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget JoinSubmit;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Back;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock Status;

    FMars_CampUiActionRequested OnActionRequested;
    FMars_ChalkModalClosed OnClosed;
    FMars_WorldBoardFocusRequested OnFocusRequested;

    bool bWorldBoardPresentation = false;

    private bool _Busy = false;
    private EMars_ButtonState _RequestedSubmitState = EMars_ButtonState::Enabled;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        JoinSubmit.OnButtonBaseClicked.AddUFunction(this, n"OnJoinClicked");
        Back.OnButtonBaseClicked.AddUFunction(this, n"OnBackClicked");
        Address.OnChanged.AddUFunction(this, n"OnAddressChanged");
        Address.OnCommitted.AddUFunction(this, n"OnAddressCommitted");
        auto FilteredInput = Cast<UCk_FilteredEditableTextBox>(Address.Input);
        if (ck::EnsureIfNot(ck::IsValid(FilteredInput), "[VestibuleJoin] Address requires a Ck filtered text box"))
        { return; }
        FilteredInput.Request_SetMaxLength(21); // 255.255.255.255:65535
        FilteredInput.OnValidateCharacter_BP = FCk_ValidateCharacterDelegate_BP(this, n"AllowAddressCharacter");
    }

    UFUNCTION()
    private bool AllowAddressCharacter(const FString& InCharacter) const
    {
        if (InCharacter.Len() != 1) { return false; }
        const int Code = int(InCharacter[0]);
        return (Code >= 48 && Code <= 57) || Code == 46 || Code == 58;
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        JoinSubmit.ButtonText = NSLOCTEXT("MarsVestibule", "JoinSubmit", "Join camp");
        Back.ButtonText = NSLOCTEXT("MarsVestibule", "JoinBack", "Back");
        JoinSubmit.RefreshLabel();
        Back.RefreshLabel();
        Address.LabelText = NSLOCTEXT("MarsVestibule", "HostAddress", "Host address");
        Address.HintText = NSLOCTEXT("MarsVestibule", "AddressHint", "192.168.1.42:7777");
        Address.RefreshPresentation();
        Address.SetError(FText());
        SetStatus(FText(), EMars_ButtonState::Enabled);
    }

    UFUNCTION(BlueprintOverride)
    void OnDeactivated()
    { OnClosed.Broadcast(this); }

    UFUNCTION(BlueprintOverride)
    UWidget BP_GetDesiredFocusTarget() const
    { return GetPreferredFocusTarget(); }

    UWidget GetPreferredFocusTarget() const
    { return Address.Input; }

    void RequestAddressFocus()
    { OnFocusRequested.Broadcast(GetPreferredFocusTarget()); }

    UFUNCTION(BlueprintOverride)
    bool OnHandleBackAction()
    {
        RequestClose();
        return true;
    }

    FString GetJoinAddress() const
    { return Address.GetValue().ToString(); }

    void SetAddress(FString InAddress)
    {
        Address.SetValue(FText::FromString(InAddress));
        RefreshSubmitState();
    }

    void SetError(FText InError)
    { Address.SetError(InError); }

    void SetStatus(FText InStatus, EMars_ButtonState InSubmitState)
    {
        _Busy = InSubmitState == EMars_ButtonState::Busy;
        _RequestedSubmitState = InSubmitState;
        Status.SetText(InStatus);
        Address.SetIsEnabled(!_Busy);
        RefreshSubmitState();
    }

    private bool CanSubmitAddress() const
    {
        if (_RequestedSubmitState != EMars_ButtonState::Enabled)
        { return false; }
        auto Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        return ck::IsValid(Flow) && Flow.IsValidDirectAddress(GetJoinAddress());
    }

    private void RefreshSubmitState()
    {
        if (_RequestedSubmitState != EMars_ButtonState::Enabled)
        {
            JoinSubmit.SetActionState(_RequestedSubmitState);
            return;
        }
        JoinSubmit.SetActionState(CanSubmitAddress()
            ? EMars_ButtonState::Enabled
            : EMars_ButtonState::Disabled);
    }

    private void RequestClose()
    {
        if (bWorldBoardPresentation)
        {
            OnActionRequested.Broadcast(EMars_CampUiAction::Back);
            return;
        }
        if (_Busy)
        {
            OnActionRequested.Broadcast(EMars_CampUiAction::Back);
            return;
        }

        DeactivateWidget();
    }

    UFUNCTION()
    private void OnJoinClicked(UCommonButtonBase InButton)
    {
        if (CanSubmitAddress())
        { OnActionRequested.Broadcast(EMars_CampUiAction::Join); }
    }

    UFUNCTION()
    private void OnBackClicked(UCommonButtonBase InButton)
    { RequestClose(); }

    UFUNCTION()
    private void OnAddressChanged(FText InText)
    {
        Address.SetError(FText());
        RefreshSubmitState();
    }

    UFUNCTION()
    private void OnAddressCommitted(FText InText, ETextCommit InMethod)
    {
        if (InMethod == ETextCommit::OnEnter && CanSubmitAddress())
        { OnActionRequested.Broadcast(EMars_CampUiAction::Join); }
    }
}

// The host and quit boards share this shape; the presenter sets the copy and reads the result.
UCLASS(Abstract)
class UMars_VestibuleAction_Widget : UMars_WorldBoard_Widget
{
    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock TitleText;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock MessageText;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock Status;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Primary;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Secondary;

    FMars_ChalkConfirmationResult OnResult;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        Primary.OnButtonBaseClicked.AddUFunction(this, n"OnPrimaryClicked");
        Secondary.OnButtonBaseClicked.AddUFunction(this, n"OnSecondaryClicked");
        Primary.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
        Secondary.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
    }

    // The secondary (Back / Stay) label is the safe default and takes focus.
    void Configure(const FMars_ChalkConfirmation_Spec& InSpec)
    {
        TitleText.SetText(InSpec.Title);
        MessageText.SetText(InSpec.Message);
        Primary.ButtonText = InSpec.ConfirmLabel;
        Primary.RefreshLabel();
        Secondary.ButtonText = InSpec.CancelLabel;
        Secondary.RefreshLabel();
    }

    void SetStatus(FText InStatus, EMars_ButtonState InPrimaryState)
    {
        Status.SetText(InStatus);
        Primary.SetActionState(InPrimaryState);
    }

    UWidget GetPreferredFocusTarget() const override
    { return Secondary; }

    void SetNavigationPresentation(bool InNavigation) override
    {
        Primary.SetNavigationPresentation(InNavigation);
        Secondary.SetNavigationPresentation(InNavigation);
    }

    UFUNCTION()
    private void OnPrimaryClicked(UCommonButtonBase InButton)
    { OnResult.Broadcast(true); }

    UFUNCTION()
    private void OnSecondaryClicked(UCommonButtonBase InButton)
    { OnResult.Broadcast(false); }

    UFUNCTION()
    private void OnButtonHovered(UCommonButtonBase InButton)
    { SetNavigationPresentation(false); }
}
