enum EMars_CampUiAction
{
    Host,
    Join,
    Settings,
    Quit,
    Back,
    ConfirmService,
    Depart
}

event void FMars_CampUiActionRequested(EMars_CampUiAction InAction);
event void FMars_WorldBoardFocusRequested(UWidget InTarget);
event void FMars_ChalkConfirmationResult(bool InConfirmed);
event void FMars_ChalkModalClosed(UCommonActivatableWidget InModal);

// A widget rendered on a world-space board. The presenter routes its actions and drives its focus through the
// board's Slate virtual user; subclasses name their first focus target and their buttons.
UCLASS(Abstract)
class UMars_WorldBoard_Widget : UUserWidget
{
    FMars_CampUiActionRequested OnActionRequested;
    FMars_WorldBoardFocusRequested OnFocusRequested;

    UWidget GetPreferredFocusTarget() const
    { return nullptr; }

    void SetNavigationPresentation(bool InNavigation)
    {
    }
}

// One selectable row of the service list; the button base drives SelectedMarker from the group selection.
UCLASS(Abstract)
class UMars_ChalkServiceRow_Widget : UMars_Button_Widget
{
    default bToggleable = true;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock Title;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock Summary;

    private UMars_ServiceDefinition _Service;

    void SetService(UMars_ServiceDefinition InService)
    {
        _Service = InService;
        Title.SetText(InService.Title);
        Summary.SetText(InService.Summary);
    }

    UMars_ServiceDefinition GetService() const
    { return _Service; }
}

UCLASS(Abstract)
class UMars_ChalkService_Widget : UMars_WorldBoard_Widget
{
    UPROPERTY(meta = (BindWidget))
    UPanelWidget ServiceRows;

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Widgets")
    TSubclassOf<UMars_ChalkServiceRow_Widget> RowClass;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock PreviewTitle;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock PreviewSummary;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock CurrentSelection;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock Status;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Confirm;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Back;

    private UMars_ServiceCatalog _Catalog;
    private FMars_CampPartyState _PartyState;
    private FName _PreviewServiceId;
    private bool _CanCommit = false;
    private bool _ApplyingSelection = false;
    private UCommonButtonGroupBase _RowGroup;
    private TArray<UMars_ChalkServiceRow_Widget> _Rows;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        _RowGroup = Cast<UCommonButtonGroupBase>(NewObject(this, UCommonButtonGroupBase));
        _RowGroup.SetSelectionRequired(true);
        _RowGroup.OnSelectedButtonBaseChanged.AddUFunction(this, n"OnRowSelected");
        Confirm.OnButtonBaseClicked.AddUFunction(this, n"OnConfirmClicked");
        Back.OnButtonBaseClicked.AddUFunction(this, n"OnBackClicked");
        Confirm.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
        Back.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
    }

    UWidget GetPreferredFocusTarget() const override
    { return _Rows.Num() > 0 ? _Rows[0] : Confirm; }

    void SetNavigationPresentation(bool InNavigation) override
    {
        for (auto Row : _Rows)
        { Row.SetNavigationPresentation(InNavigation); }
        Confirm.SetNavigationPresentation(InNavigation);
        Back.SetNavigationPresentation(InNavigation);
    }

    void SetCatalog(UMars_ServiceCatalog InCatalog)
    {
        if (ck::EnsureIfNot(ck::IsValid(RowClass), "[Service] RowClass is unset on the Service WBP"))
        { return; }

        _Catalog = InCatalog;
        _RowGroup.RemoveAll();
        _Rows.Empty();
        ServiceRows.ClearChildren();
        if (ck::IsValid(_Catalog))
        {
            for (auto Service : _Catalog.Services)
            {
                if (ck::Is_NOT_Valid(Service))
                { continue; }

                auto Row = Cast<UMars_ChalkServiceRow_Widget>(WidgetBlueprint::CreateWidget(RowClass, GetOwningPlayer()));
                Row.SetService(Service);
                Row.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
                ServiceRows.AddChild(Row);
                _RowGroup.AddWidget(Row);
                _Rows.Add(Row);
            }
        }

        ReconcilePreview();
    }

    private TOptional<int32> FindRowIndex(FName InServiceId) const
    {
        for (int32 Index = 0; Index < _Rows.Num(); ++Index)
        {
            if (ck::IsValid(_Rows[Index].GetService()) && _Rows[Index].GetService().Id == InServiceId)
            { return TOptional<int32>(Index); }
        }

        return TOptional<int32>();
    }

    // The preview follows the party's committed service until the player browses away from it.
    void SetPartyState(FMars_CampPartyState InState, bool InCanCommit)
    {
        _PartyState = InState;
        _CanCommit = InCanCommit;
        if (_PreviewServiceId.IsNone())
        { _PreviewServiceId = InState.ServiceId; }
        ReconcilePreview();
    }

    void SetStatus(FText InStatus)
    { Status.SetText(InStatus); }

    FName GetPreviewServiceId() const
    { return _PreviewServiceId; }

    private void ReconcilePreview()
    {
        auto RowIndex = FindRowIndex(_PreviewServiceId);
        if (RowIndex.IsSet() == false && _Rows.Num() > 0)
        {
            RowIndex = TOptional<int32>(0);
            _PreviewServiceId = _Rows[0].GetService().Id;
        }

        _ApplyingSelection = true;
        if (RowIndex.IsSet())
        { _RowGroup.SelectButtonAtIndex(RowIndex.GetValue()); }
        else
        { _RowGroup.DeselectAll(); }
        _ApplyingSelection = false;

        RefreshPreview();
    }

    private void RefreshPreview()
    {
        auto Preview = ck::IsValid(_Catalog) ? _Catalog.Find(_PreviewServiceId) : nullptr;
        PreviewTitle.SetText(ck::IsValid(Preview) ? Preview.Title : FText());
        PreviewSummary.SetText(ck::IsValid(Preview) ? Preview.Summary : FText());

        auto Current = ck::IsValid(_Catalog) ? _Catalog.Find(_PartyState.ServiceId) : nullptr;
        CurrentSelection.SetText(ck::IsValid(Current) ? Current.Title : FText());
        Confirm.SetIsEnabled(_CanCommit && !_PartyState.IsDeparting && ck::IsValid(Preview));
    }

    UFUNCTION()
    private void OnRowSelected(UCommonButtonBase InButton, int32 InIndex)
    {
        if (_ApplyingSelection)
        { return; }

        auto Row = Cast<UMars_ChalkServiceRow_Widget>(InButton);
        if (ck::EnsureIfNot(ck::IsValid(Row) && ck::IsValid(Row.GetService()), "[Service] a selected row has no service"))
        { return; }

        _PreviewServiceId = Row.GetService().Id;
        RefreshPreview();
    }

    UFUNCTION()
    private void OnConfirmClicked(UCommonButtonBase InButton)
    {
        if (_CanCommit && !_PartyState.IsDeparting && ck::IsValid(_Catalog) &&
            ck::IsValid(_Catalog.Find(_PreviewServiceId)))
        { OnActionRequested.Broadcast(EMars_CampUiAction::ConfirmService); }
    }

    UFUNCTION()
    private void OnBackClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_CampUiAction::Back); }

    UFUNCTION()
    private void OnButtonHovered(UCommonButtonBase InButton)
    { SetNavigationPresentation(false); }
}

struct FMars_ChalkConfirmation_Spec
{
    FText Title;
    FText Message;
    FText ConfirmLabel;
    // Empty keeps the WBP's label.
    FText CancelLabel;

    FMars_ChalkConfirmation_Spec() {}

    FMars_ChalkConfirmation_Spec(FText InTitle, FText InMessage, FText InConfirmLabel)
    {
        Title = InTitle;
        Message = InMessage;
        ConfirmLabel = InConfirmLabel;
    }

    FMars_ChalkConfirmation_Spec(FText InTitle, FText InMessage, FText InConfirmLabel, FText InCancelLabel)
    {
        Title = InTitle;
        Message = InMessage;
        ConfirmLabel = InConfirmLabel;
        CancelLabel = InCancelLabel;
    }
}

// Screen-space modal. It resolves once, broadcasts the result and deactivates itself; the layer removes it.
UCLASS(Abstract)
class UMars_ChalkConfirmation_Widget : UCk_ActivatableWidget_UE
{
    default bIsFocusable = true;
    default bIsBackHandler = true;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock TitleText;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock MessageText;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Confirm;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Cancel;

    FMars_ChalkConfirmationResult OnResult;
    FMars_ChalkModalClosed OnClosed;

    private bool _Resolved = false;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        Confirm.OnButtonBaseClicked.AddUFunction(this, n"OnConfirmClicked");
        Cancel.OnButtonBaseClicked.AddUFunction(this, n"OnCancelClicked");
    }

    UFUNCTION(BlueprintOverride)
    void OnActivated()
    { _Resolved = false; }

    UFUNCTION(BlueprintOverride)
    void OnDeactivated()
    { OnClosed.Broadcast(this); }

    UFUNCTION(BlueprintOverride)
    UWidget BP_GetDesiredFocusTarget() const
    { return Cancel; }

    UFUNCTION(BlueprintOverride)
    bool OnHandleBackAction()
    {
        Resolve(false);
        return true;
    }

    void Configure(const FMars_ChalkConfirmation_Spec& InSpec)
    {
        TitleText.SetText(InSpec.Title);
        MessageText.SetText(InSpec.Message);
        Confirm.ButtonText = InSpec.ConfirmLabel;
        Confirm.RefreshLabel();
        if (!InSpec.CancelLabel.IsEmpty())
        {
            Cancel.ButtonText = InSpec.CancelLabel;
            Cancel.RefreshLabel();
        }
    }

    void SetMessage(FText InMessage)
    { MessageText.SetText(InMessage); }

    void SetConfirmState(EMars_ButtonState InState)
    { Confirm.SetActionState(InState); }

    private void Resolve(bool InConfirmed)
    {
        if (_Resolved)
        { return; }

        _Resolved = true;
        OnResult.Broadcast(InConfirmed);
        DeactivateWidget();
    }

    UFUNCTION()
    private void OnConfirmClicked(UCommonButtonBase InButton)
    { Resolve(true); }

    UFUNCTION()
    private void OnCancelClicked(UCommonButtonBase InButton)
    { Resolve(false); }
}
