enum EMars_ButtonState
{
    Enabled,
    Disabled,
    // Disabled with the busy marker shown: the action is already in flight.
    Busy
}

// Unstyled CommonUI button for menus. Style is picked per instance/WBP (Style property); the label collapses when empty.
UCLASS(Abstract)
class UMars_Button_Widget : UCommonButtonBase
{
    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock Text;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget FocusCorners;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget SpoonFocus;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget SelectedMarker;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget BusyMarker;

    UPROPERTY(EditAnywhere, Category = "Mars")
    FText ButtonText;

    UPROPERTY(EditAnywhere, Category = "Mars")
    bool bShowSpoonFocus = false;

    private bool _HasFocus = false;
    private bool _IsHovered = false;
    private bool _NavigationPresentation = true;
    private bool _IsBusy = false;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        OnButtonBaseFocused.AddUFunction(this, n"HandleFocused");
        OnButtonBaseUnfocused.AddUFunction(this, n"HandleUnfocused");
        OnButtonBaseHovered.AddUFunction(this, n"HandleHovered");
        OnButtonBaseUnhovered.AddUFunction(this, n"HandleUnhovered");
        OnButtonBaseSelected.AddUFunction(this, n"HandleSelectionChanged");
        OnButtonBaseUnselected.AddUFunction(this, n"HandleSelectionChanged");
        RefreshIndicators();
    }

    UFUNCTION(BlueprintOverride)
    void PreConstruct(bool bIsDesignTime)
    {
        RefreshLabel();
        RefreshIndicators();
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        _HasFocus = false;
        _IsHovered = false;
        _NavigationPresentation = true;
        RefreshLabel();
        RefreshTextStyle();
        RefreshIndicators();
    }

    UFUNCTION(BlueprintOverride)
    void Destruct()
    {
        _HasFocus = false;
        _IsHovered = false;
        RefreshIndicators();
    }

    UFUNCTION(BlueprintOverride)
    void OnCurrentTextStyleChanged()
    { RefreshTextStyle(); }

    void SetActionState(EMars_ButtonState InState)
    {
        _IsBusy = InState == EMars_ButtonState::Busy;
        SetIsEnabled(InState == EMars_ButtonState::Enabled);
        RefreshIndicators();
    }

    // Public so an owner can re-apply after setting ButtonText at runtime (PreConstruct has already run by then).
    void RefreshLabel()
    {
        if (ck::Is_NOT_Valid(Text))
        { return; }

        Text.SetText(ButtonText);
        Text.SetVisibility(ButtonText.IsEmpty()
            ? ESlateVisibility::Collapsed
            : ESlateVisibility::SelfHitTestInvisible);
    }

    private void RefreshTextStyle()
    {
        if (ck::Is_NOT_Valid(Text) || ck::Is_NOT_Valid(GetCurrentTextStyle()))
        { return; }

        Text.SetStyle(GetCurrentTextStyleClass());
    }

    UFUNCTION()
    private void HandleFocused(UCommonButtonBase InButton)
    {
        _HasFocus = true;
        RefreshIndicators();
    }

    UFUNCTION()
    private void HandleUnfocused(UCommonButtonBase InButton)
    {
        _HasFocus = false;
        RefreshIndicators();
    }

    UFUNCTION()
    private void HandleSelectionChanged(UCommonButtonBase InButton)
    { RefreshIndicators(); }

    // A world-board owner arbitrates pointer versus navigation presentation for its buttons.
    // This changes decoration only; hovering never takes keyboard or text-entry focus.
    void SetNavigationPresentation(bool InNavigation)
    {
        _NavigationPresentation = InNavigation;
        RefreshIndicators();
    }

    void ResetInteractionPresentation()
    {
        _HasFocus = false;
        _IsHovered = false;
        _NavigationPresentation = true;
        RefreshIndicators();
    }

    UFUNCTION()
    private void HandleHovered(UCommonButtonBase InButton)
    {
        _IsHovered = true;
        RefreshIndicators();
    }

    UFUNCTION()
    private void HandleUnhovered(UCommonButtonBase InButton)
    {
        _IsHovered = false;
        RefreshIndicators();
    }

    private void RefreshIndicators()
    {
        const bool ShowFocus = GetIsEnabled() && !_IsBusy &&
            (_NavigationPresentation ? _HasFocus : _IsHovered);
        if (ck::IsValid(FocusCorners))
        {
            FocusCorners.SetVisibility(ShowFocus
                ? ESlateVisibility::HitTestInvisible
                : ESlateVisibility::Collapsed);
        }

        if (ck::IsValid(SpoonFocus))
        {
            SpoonFocus.SetVisibility(ShowFocus && bShowSpoonFocus
                ? ESlateVisibility::HitTestInvisible
                : ESlateVisibility::Collapsed);
        }

        if (ck::IsValid(SelectedMarker))
        {
            SelectedMarker.SetVisibility(GetSelected()
                ? ESlateVisibility::HitTestInvisible
                : ESlateVisibility::Collapsed);
        }

        if (ck::IsValid(BusyMarker))
        {
            BusyMarker.SetVisibility(_IsBusy
                ? ESlateVisibility::HitTestInvisible
                : ESlateVisibility::Collapsed);
        }
    }
}
