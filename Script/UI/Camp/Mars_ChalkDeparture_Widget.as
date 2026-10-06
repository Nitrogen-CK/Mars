// The departure post shows the host's committed service; it never selects a service itself.
UCLASS(Abstract)
class UMars_ChalkDeparture_Widget : UMars_WorldBoard_Widget
{
    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock ServiceTitle;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock Status;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Depart;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Back;

    private bool _CanDepart = false;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        Depart.OnButtonBaseClicked.AddUFunction(this, n"OnDepartClicked");
        Back.OnButtonBaseClicked.AddUFunction(this, n"OnBackClicked");
        Depart.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
        Back.OnButtonBaseHovered.AddUFunction(this, n"OnButtonHovered");
        Depart.SetIsEnabled(false);
    }

    // A server travel cannot be taken back: Back leaves the board while the party departs.
    void SetPartyState(FMars_CampPartyState InParty, UMars_ServiceCatalog InCatalog, bool InCanDepart)
    {
        auto Service = ck::IsValid(InCatalog) ? InCatalog.Find(InParty.ServiceId) : nullptr;
        _CanDepart = InCanDepart && !InParty.IsDeparting && ck::IsValid(Service);
        ServiceTitle.SetText(ck::IsValid(Service)
            ? Service.Title
            : NSLOCTEXT("MarsCamp", "DepartureNoService", "No service selected"));
        Status.SetText(InParty.IsDeparting
            ? NSLOCTEXT("MarsCamp", "DepartureInProgress", "The party is departing.")
            : ck::Is_NOT_Valid(Service)
                ? NSLOCTEXT("MarsCamp", "DepartureChooseService", "Choose and confirm a service at the contract board first.")
                : InCanDepart
                    ? NSLOCTEXT("MarsCamp", "DepartureReady", "The host may depart with the party.")
                    : NSLOCTEXT("MarsCamp", "DepartureHostOnly", "Only the host can depart with the party."));
        Depart.SetIsEnabled(_CanDepart);
        Back.SetVisibility(InParty.IsDeparting
            ? ESlateVisibility::Collapsed
            : ESlateVisibility::Visible);
    }

    UWidget GetPreferredFocusTarget() const override
    { return _CanDepart ? Cast<UWidget>(Depart) : Cast<UWidget>(Back); }

    void SetNavigationPresentation(bool InNavigation) override
    {
        Depart.SetNavigationPresentation(InNavigation);
        Back.SetNavigationPresentation(InNavigation);
    }

    UFUNCTION()
    private void OnDepartClicked(UCommonButtonBase InButton)
    {
        if (_CanDepart)
        { OnActionRequested.Broadcast(EMars_CampUiAction::Depart); }
    }

    UFUNCTION()
    private void OnBackClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_CampUiAction::Back); }

    UFUNCTION()
    private void OnButtonHovered(UCommonButtonBase InButton)
    { SetNavigationPresentation(false); }
}
