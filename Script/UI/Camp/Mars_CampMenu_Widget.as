// The camp main menu (Menu layer starting widget of Camp_LayoutConfig_Mars_DA). Rows are UMars_Button_Widget WBP
// instances bound by NAME (Menu_*). Panels are pushed onto the same Menu layer stack; when one pops, this widget
// reactivates and refocuses the Title camera. Host/Join arrive with the joining campaign (design section 1).
UCLASS(Abstract)
class UMars_CampMenu_Widget : UCk_ActivatableWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UCommonButtonBase Menu_Play;

    UPROPERTY(meta = (BindWidget))
    UCommonButtonBase Menu_Customise;

    UPROPERTY(meta = (BindWidget))
    UCommonButtonBase Menu_Settings;

    UPROPERTY(meta = (BindWidget))
    UCommonButtonBase Menu_Quit;

    // Set in the WBP (design D8) - no asset defaults here.
    UPROPERTY(EditDefaultsOnly, Category = "Camp")
    TSoftClassPtr<UMars_CampStationPanel_Widget> CustomisePanelClass;

    UPROPERTY(EditDefaultsOnly, Category = "Camp")
    TSoftClassPtr<UMars_CampStationPanel_Widget> SettingsPanelClass;

    // OnButtonBaseClicked, not OnClicked: UCommonButtonBase::OnClicked() has no reflected surface (trap 32).
    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        if (ck::IsValid(Menu_Play))
        { Menu_Play.OnButtonBaseClicked.AddUFunction(this, n"OnPlayClicked"); }

        if (ck::IsValid(Menu_Customise))
        { Menu_Customise.OnButtonBaseClicked.AddUFunction(this, n"OnCustomiseClicked"); }

        if (ck::IsValid(Menu_Settings))
        { Menu_Settings.OnButtonBaseClicked.AddUFunction(this, n"OnSettingsClicked"); }

        if (ck::IsValid(Menu_Quit))
        { Menu_Quit.OnButtonBaseClicked.AddUFunction(this, n"OnQuitClicked"); }
    }

    UFUNCTION(BlueprintOverride)
    void OnActivated()
    {
        auto PC = Cast<AMars_Camp_PlayerController>(GetOwningPlayer());
        if (ck::IsValid(PC))
        { PC.Request_FocusStation(EMars_CampStation::Title); }
    }

    UFUNCTION()
    private void OnPlayClicked(UCommonButtonBase InButton)
    {
        auto PC = Cast<AMars_Camp_PlayerController>(GetOwningPlayer());
        if (ck::IsValid(PC))
        { PC.Server_RequestPlay(); }
    }

    UFUNCTION()
    private void OnCustomiseClicked(UCommonButtonBase InButton)
    { PushPanel(CustomisePanelClass); }

    UFUNCTION()
    private void OnSettingsClicked(UCommonButtonBase InButton)
    { PushPanel(SettingsPanelClass); }

    UFUNCTION()
    private void OnQuitClicked(UCommonButtonBase InButton)
    { System::QuitGame(GetOwningPlayer(), EQuitPreference::Quit, false); }

    private void PushPanel(TSoftClassPtr<UMars_CampStationPanel_Widget> InClass)
    {
        if (ck::EnsureIfNot(InClass.IsNull() == false, "[Mars_CampMenu] panel class not set in the WBP"))
        { return; }

        utils_u_i_layout::PushWidgetToLayer_Soft(GetOwningPlayer(), GameplayTags::ResolveGameplayTag(n"UI.Layer.Menu"),
            InClass, FCk_Delegate_UI_OnWidgetReady());
    }
}
