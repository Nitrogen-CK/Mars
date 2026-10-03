// The camp main menu (Menu layer starting widget of Camp_LayoutConfig_Mars_DA). Rows are UMars_Button_Widget WBP
// instances bound by NAME (Menu_*). Panels are pushed onto the same Menu layer stack; when one pops, this widget
// reactivates and refocuses the Title camera.
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

    // Set in the WBP.
    UPROPERTY(EditDefaultsOnly, Category = "Camp")
    TSoftClassPtr<UMars_CampStationPanel_Widget> CustomisePanelClass;

    UPROPERTY(EditDefaultsOnly, Category = "Camp")
    TSoftClassPtr<UMars_CampStationPanel_Widget> SettingsPanelClass;

    // Once per widget: CommonUI re-runs Construct each time a pooled widget is shown again, which would bind twice.
    // OnButtonBaseClicked, not OnClicked: UCommonButtonBase::OnClicked() has no reflected surface.
    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        Menu_Play.OnButtonBaseClicked.AddUFunction(this, n"OnPlayClicked");
        Menu_Customise.OnButtonBaseClicked.AddUFunction(this, n"OnCustomiseClicked");
        Menu_Settings.OnButtonBaseClicked.AddUFunction(this, n"OnSettingsClicked");
        Menu_Quit.OnButtonBaseClicked.AddUFunction(this, n"OnQuitClicked");
    }

    UFUNCTION(BlueprintOverride)
    void OnActivated()
    {
        auto PC = Get_CampPlayerController();
        if (ck::IsValid(PC))
        { PC.FocusStation(EMars_CampStation::Title); }
    }

    UFUNCTION()
    private void OnPlayClicked(UCommonButtonBase InButton)
    {
        auto PC = Get_CampPlayerController();
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

    // The camp layout is only ever shown to a camp player controller.
    private AMars_Camp_PlayerController Get_CampPlayerController() const
    {
        auto PC = Cast<AMars_Camp_PlayerController>(GetOwningPlayer());
        ck::EnsureIfNot(ck::IsValid(PC), "[Mars_CampMenu] the owning player is not an AMars_Camp_PlayerController");
        return PC;
    }
}
