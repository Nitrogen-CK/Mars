// One camp station screen (Customise, Settings...). Activation focuses the station camera; Back (button or the
// CommonUI back action) removes the panel, which reactivates the camp menu below it on the Menu layer.
UCLASS(Abstract)
class UMars_CampStationPanel_Widget : UCk_ActivatableWidget_UE
{
    default bIsBackHandler = true;
    default bIsBackActionDisplayedInActionBar = true;

    UPROPERTY(meta = (BindWidget))
    UCommonButtonBase Menu_Back;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock TitleText;

    UPROPERTY(EditDefaultsOnly, Category = "Camp")
    EMars_CampStation Station = EMars_CampStation::Wardrobe;

    UPROPERTY(EditDefaultsOnly, Category = "Camp")
    FText Title;

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        if (ck::IsValid(Menu_Back))
        { Menu_Back.OnButtonBaseClicked.AddUFunction(this, n"OnBackClicked"); }

        if (ck::IsValid(TitleText))
        { TitleText.SetText(Title); }
    }

    UFUNCTION(BlueprintOverride)
    void OnActivated()
    {
        auto PC = Cast<AMars_Camp_PlayerController>(GetOwningPlayer());
        if (ck::IsValid(PC))
        { PC.Request_FocusStation(Station); }
    }

    UFUNCTION(BlueprintOverride)
    bool OnHandleBackAction()
    {
        utils_u_i_layout::RemoveWidgetSelf(this);
        return true;
    }

    UFUNCTION()
    private void OnBackClicked(UCommonButtonBase InButton)
    { utils_u_i_layout::RemoveWidgetSelf(this); }
}
