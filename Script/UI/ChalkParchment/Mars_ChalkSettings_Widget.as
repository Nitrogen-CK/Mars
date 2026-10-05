// The native settings screen builds and binds rows from the CkGameSettings registry.
// This subclass owns the game's catalogue and presentation, not persistence.
enum EMars_ChalkSettingsGroup
{
    Audio,
    Video,
    Controls
}

event void FMars_ChalkSettingsWorldBoardClosed();

UCLASS(Abstract)
class UMars_ChalkSettings_Widget : UCk_GameSettingsUI_ScreenWidget
{
    default bIsFocusable = true;
    default bIsBackHandler = true;

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    bool bWorldBoardHost = false;

    FMars_ChalkSettingsWorldBoardClosed OnWorldBoardClosed;

    UPROPERTY(meta = (BindWidgetOptional))
    UImage Scrim;

    UFUNCTION(BlueprintOverride)
    void OnActivated()
    {
        utils_game_settings::BindTo_OnSettingChanged(NAME_None,
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnRowDescriptionChanged"));
        CaptureQualityBaseline();
        _QualityPreviewed = false;
        utils_game_settings::BindTo_OnSettingChanged(n"video.quality_preset",
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnQualityChanged"));
        if (ck::IsValid(Scrim))
        { Scrim.SetVisibility(bWorldBoardHost ? ESlateVisibility::Collapsed : ESlateVisibility::HitTestInvisible); }
    }

    UPROPERTY(meta = (BindWidgetOptional))
    UMars_Button_Widget TabAudio;

    UPROPERTY(meta = (BindWidgetOptional))
    UMars_Button_Widget TabVideo;

    UPROPERTY(meta = (BindWidgetOptional))
    UMars_Button_Widget TabControls;

    UPROPERTY(meta = (BindWidgetOptional))
    UMars_Button_Widget TabAccessibility;

    UPROPERTY(meta = (BindWidgetOptional))
    UMars_Button_Widget RestoreDefaults;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget BindingsRow;

    UPROPERTY(meta = (BindWidgetOptional))
    UMars_Button_Widget ViewBindings;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock SectionText;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock HelpTitle;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock HelpDescription;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock PendingText;

    private EMars_ChalkSettingsGroup _SelectedGroup = EMars_ChalkSettingsGroup::Audio;
    private UCommonButtonGroupBase _TabGroup;
    private TArray<UCk_GameSettingsUI_RowWidgetBase> _Rows;
    private FName _HelpKey;
    private bool _QualityPreviewed = false;
    private TArray<int> _QualityBaseline;
    private float32 _ResolutionBaseline = 1.0f;
    private int _LandscapeBaseline = 3;

    UFUNCTION(BlueprintOverride)
    void OnRowGenerated(UCk_GameSettingsUI_RowWidgetBase InRow, FName InCategory)
    {
        _Rows.AddUnique(InRow);
        InRow.SetToolTipText(FText());
    }

    UFUNCTION()
    private void OnRowDescriptionChanged(FName InKey, FString InValue)
    {
        // The registry broadcasts wildcard listeners after per-key listeners,
        // so native row refresh has finished writing its default tooltip.
        for (auto Row : _Rows)
        {
            if (ck::IsValid(Row) && Row.Get_SettingKey() == InKey)
            { Row.SetToolTipText(FText()); }
        }
    }

    // Observe the small native row pool; never move focus or change capture.
    // Native Apply has no public pending-state event, so sample its truth here.
    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        if (!IsActivated())
        { return; }
        if (ck::IsValid(PendingText))
        { PendingText.SetVisibility(Get_PendingStatusVisibility()); }

        FName FocusKey;
        for (auto Row : _Rows)
        {
            if (ck::Is_NOT_Valid(Row) || !Row.IsVisible())
            { continue; }
            if (Row.IsHovered())
            {
                ShowHelpForKey(Row.Get_SettingKey());
                return;
            }
            if (Row.HasFocusedDescendants())
            { FocusKey = Row.Get_SettingKey(); }
        }
        if (!FocusKey.IsNone())
        { ShowHelpForKey(FocusKey); }
    }

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        _TabGroup = Cast<UCommonButtonGroupBase>(NewObject(this, UCommonButtonGroupBase));
        _TabGroup.SetSelectionRequired(true);
        _TabGroup.OnSelectedButtonBaseChanged.AddUFunction(this, n"OnTabSelectionChanged");

        AddTab(TabAudio);
        AddTab(TabVideo);
        AddTab(TabControls);
        if (ck::IsValid(TabAccessibility))
        { TabAccessibility.SetIsEnabled(false); }
        if (ck::IsValid(ViewBindings))
        { ViewBindings.SetIsEnabled(false); }
        if (ck::IsValid(RestoreDefaults))
        { RestoreDefaults.OnButtonBaseClicked.AddUFunction(this, n"OnRestoreDefaults"); }
        if (ck::IsValid(_ApplyButton))
        { _ApplyButton.OnButtonBaseClicked.AddUFunction(this, n"OnApplyQualityBaseline"); }

        Request_SetActiveCategory(n"General");
        RefreshGroupPresentation();
        if (ck::IsValid(PendingText))
        { PendingText.SetText(NSLOCTEXT("MarsSettings", "PendingChanges", "Unsaved changes")); }
    }

    UFUNCTION(BlueprintOverride)
    UWidget BP_GetDesiredFocusTarget() const
    { return GetPreferredFocusTarget(); }

    UWidget GetPreferredFocusTarget() const
    {
        if (_SelectedGroup == EMars_ChalkSettingsGroup::Video)
        { return TabVideo; }
        if (_SelectedGroup == EMars_ChalkSettingsGroup::Controls)
        { return TabControls; }
        return TabAudio;
    }

    UComboBoxString GetOpenDropdown() const
    {
        for (auto Row : _Rows)
        {
            if (ck::Is_NOT_Valid(Row) || !Row.IsVisible())
            { continue; }
            auto DropdownRow = Cast<UCk_GameSettingsUI_RowWidget_Dropdown>(Row);
            if (ck::Is_NOT_Valid(DropdownRow))
            { continue; }
            auto Combo = DropdownRow._ValueComboBox;
            if (ck::IsValid(Combo) && Combo.IsOpen())
            { return Combo; }
        }
        return nullptr;
    }

    UFUNCTION(BlueprintOverride)
    void OnDeactivated()
    {
        utils_game_settings::UnbindFrom_OnSettingChanged(NAME_None,
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnRowDescriptionChanged"));
        utils_game_settings::UnbindFrom_OnSettingChanged(n"video.quality_preset",
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnQualityChanged"));
        // Native cancellation precedes this event. Its scalar preset cannot
        // restore a mixed (-1) configuration, so restore the captured group.
        if (_QualityPreviewed)
        { RestoreQualityBaseline(); }
        _QualityPreviewed = false;
        if (bWorldBoardHost)
        { OnWorldBoardClosed.Broadcast(); }
    }

    UFUNCTION(BlueprintOverride)
    TArray<FName> Get_CuratedKeysForCategory(FName InCategory)
    { return InCategory == n"General" ? GetGroupKeys() : TArray<FName>(); }

    private TArray<FName> GetGroupKeys() const
    {
        TArray<FName> Keys;

        if (_SelectedGroup == EMars_ChalkSettingsGroup::Audio)
        {
            Keys.Add(n"audio.master");
            Keys.Add(n"audio.music");
            Keys.Add(n"audio.sfx");
            Keys.Add(n"audio.voice");
        }
        else if (_SelectedGroup == EMars_ChalkSettingsGroup::Video)
        {
            Keys.Add(n"video.quality_preset");
            Keys.Add(n"video.vsync");
            Keys.Add(n"video.fps_cap");
            Keys.Add(n"video.sg.view_distance");
        }
        else
        {
            Keys.Add(n"controls.look_sensitivity");
            Keys.Add(n"controls.invert_y");
            Keys.Add(n"controls.sprint_toggle");
        }
        return Keys;
    }

    private void SetGroup(EMars_ChalkSettingsGroup InGroup)
    {
        bool bChanged = _SelectedGroup != InGroup;
        _SelectedGroup = InGroup;
        if (bChanged)
        {
            RefreshGroupPresentation();
            Request_RebuildRows();
        }
    }

    // Row WBPs may call this on hover or when a child control gains focus.
    // Pooled rows from another tab cannot change the visible help panel.
    UFUNCTION(BlueprintCallable)
    void ShowHelpForKey(FName InKey)
    {
        if (_HelpKey == InKey || !Get_IsKeyVisible(InKey))
        { return; }

        FCk_GameSettings_SettingDefinition Definition;
        if (!utils_game_settings::Get_SettingDefinition(InKey, Definition))
        { return; }
        _HelpKey = InKey;

        if (ck::IsValid(HelpTitle))
        { HelpTitle.SetText(Definition.Get_DisplayName()); }
        if (ck::IsValid(HelpDescription))
        {
            auto Description = Definition.Get_Description();
            if (InKey == n"audio.master")
            { Description = NSLOCTEXT("MarsSettings", "MasterHelp", "Adjusts the volume of all game audio."); }
            else if (InKey == n"audio.music")
            { Description = NSLOCTEXT("MarsSettings", "MusicHelp", "Adjusts music in menus, camp and expeditions. Sound effects and voices are unchanged."); }
            else if (InKey == n"audio.sfx")
            { Description = NSLOCTEXT("MarsSettings", "SfxHelp", "Adjusts footsteps, interactions and other sound effects."); }
            else if (InKey == n"audio.voice")
            { Description = NSLOCTEXT("MarsSettings", "VoiceHelp", "Adjusts audio routed through the voice channel."); }
            HelpDescription.SetText(Description.IsEmpty()
                ? NSLOCTEXT("MarsSettings", "NoSettingDescription", "Apply saves this setting. Cancel restores its previous value.")
                : Description);
        }
    }

    private bool Get_IsKeyVisible(FName InKey)
    {
        return GetGroupKeys().Contains(InKey);
    }

    // Apply, Cancel and reactivation share the native pending-changes session.
    UFUNCTION(BlueprintPure)
    ESlateVisibility Get_PendingStatusVisibility() const
    {
        return utils_game_settings::Get_HasPendingChanges()
            ? ESlateVisibility::SelfHitTestInvisible
            : ESlateVisibility::Collapsed;
    }

    private void RefreshGroupPresentation()
    {
        _HelpKey = NAME_None;
        FText GroupTitle;
        FText RestoreText;
        if (_SelectedGroup == EMars_ChalkSettingsGroup::Audio)
        {
            GroupTitle = NSLOCTEXT("MarsSettings", "AudioGroup", "AUDIO");
            RestoreText = NSLOCTEXT("MarsSettings", "RestoreAudio", "Restore audio defaults");
        }
        else if (_SelectedGroup == EMars_ChalkSettingsGroup::Video)
        {
            GroupTitle = NSLOCTEXT("MarsSettings", "VideoGroup", "VIDEO");
            RestoreText = NSLOCTEXT("MarsSettings", "RestoreVideo", "Restore video defaults");
        }
        else
        {
            GroupTitle = NSLOCTEXT("MarsSettings", "ControlsGroup", "CONTROLS");
            RestoreText = NSLOCTEXT("MarsSettings", "RestoreControls", "Restore controls defaults");
        }

        if (ck::IsValid(RestoreDefaults))
        {
            RestoreDefaults.ButtonText = RestoreText;
            RestoreDefaults.RefreshLabel();
        }
        if (ck::IsValid(BindingsRow))
        { BindingsRow.SetVisibility(_SelectedGroup == EMars_ChalkSettingsGroup::Controls
            ? ESlateVisibility::SelfHitTestInvisible : ESlateVisibility::Collapsed); }

        if (ck::IsValid(SectionText))
        { SectionText.SetText(GroupTitle); }
        if (ck::IsValid(HelpTitle))
        { HelpTitle.SetText(GroupTitle); }
        if (ck::IsValid(HelpDescription))
        { HelpDescription.SetText(NSLOCTEXT("MarsSettings", "SelectSettingHelp", "Select a setting for details.")); }
    }

    UFUNCTION()
    private void OnTabSelectionChanged(UCommonButtonBase InButton, int ButtonIndex)
    {
        if (ButtonIndex == 0)
        { SetGroup(EMars_ChalkSettingsGroup::Audio); }
        else if (ButtonIndex == 1)
        { SetGroup(EMars_ChalkSettingsGroup::Video); }
        else if (ButtonIndex == 2)
        { SetGroup(EMars_ChalkSettingsGroup::Controls); }
    }

    private void AddTab(UMars_Button_Widget InTab)
    {
        if (ck::Is_NOT_Valid(InTab))
        { return; }
        InTab.SetIsSelectable(true);
        _TabGroup.AddWidget(InTab);
    }

    UFUNCTION()
    private void OnRestoreDefaults(UCommonButtonBase InButton)
    {
        // Reset participates in the same pending session as a row edit;
        // Cancel must also undo a whole-category reset.
        if (_SelectedGroup == EMars_ChalkSettingsGroup::Video)
        {
            // External values are owned by GameUserSettings: request explicit
            // game defaults through their setters, never the provider reset API.
            utils_game_settings::Request_SetSettingValue_Int32(FCk_Request_GameSettings_SetValue_Int32(n"video.quality_preset", 3));
            utils_game_settings::Request_SetSettingValue_Bool(FCk_Request_GameSettings_SetValue_Bool(n"video.vsync", false));
            utils_game_settings::Request_SetSettingValue_Float(FCk_Request_GameSettings_SetValue_Float(n"video.fps_cap", 60.0f));
            utils_game_settings::Request_SetSettingValue_Int32(FCk_Request_GameSettings_SetValue_Int32(n"video.sg.view_distance", 3));
            Request_RebuildRows();
        }
        else
        {
            for (auto Key : GetGroupKeys())
            { utils_game_settings::Request_ResetToDefault(FCk_Request_GameSettings_ResetToDefault(Key)); }
        }
    }

    UFUNCTION()
    private void OnQualityChanged(FName InKey, FString InValue)
    {
        if (utils_game_settings::Get_HasPendingChanges())
        { _QualityPreviewed = true; }
    }

    UFUNCTION()
    private void OnApplyQualityBaseline(UCommonButtonBase InButton)
    {
        CaptureQualityBaseline();
        _QualityPreviewed = false;
    }

    private void CaptureQualityBaseline()
    {
        auto Settings = UGameUserSettings::GetGameUserSettings();
        _QualityBaseline.Reset();
        _QualityBaseline.Add(Settings.GetViewDistanceQuality());
        _QualityBaseline.Add(Settings.GetShadowQuality());
        _QualityBaseline.Add(Settings.GetGlobalIlluminationQuality());
        _QualityBaseline.Add(Settings.GetReflectionQuality());
        _QualityBaseline.Add(Settings.GetAntiAliasingQuality());
        _QualityBaseline.Add(Settings.GetTextureQuality());
        _QualityBaseline.Add(Settings.GetVisualEffectQuality());
        _QualityBaseline.Add(Settings.GetPostProcessingQuality());
        _QualityBaseline.Add(Settings.GetFoliageQuality());
        _QualityBaseline.Add(Settings.GetShadingQuality());
        _ResolutionBaseline = Settings.GetResolutionScaleNormalized();
        // Landscape has no reflected GameUserSettings accessor. Capture the
        // applied scalability level without raising its console priority.
        _LandscapeBaseline = FConsoleVariable("sg.LandscapeQuality", 3).GetInt();
    }

    private void RestoreQualityBaseline()
    {
        auto Settings = UGameUserSettings::GetGameUserSettings();
        // Seed the inaccessible landscape field through the engine preset,
        // then restore each exposed field before applying the group once.
        Settings.SetOverallScalabilityLevel(_LandscapeBaseline);
        Settings.SetViewDistanceQuality(_QualityBaseline[0]);
        Settings.SetShadowQuality(_QualityBaseline[1]);
        Settings.SetGlobalIlluminationQuality(_QualityBaseline[2]);
        Settings.SetReflectionQuality(_QualityBaseline[3]);
        Settings.SetAntiAliasingQuality(_QualityBaseline[4]);
        Settings.SetTextureQuality(_QualityBaseline[5]);
        Settings.SetVisualEffectQuality(_QualityBaseline[6]);
        Settings.SetPostProcessingQuality(_QualityBaseline[7]);
        Settings.SetFoliageQuality(_QualityBaseline[8]);
        Settings.SetShadingQuality(_QualityBaseline[9]);
        Settings.SetResolutionScaleNormalized(_ResolutionBaseline);
        Settings.ApplyNonResolutionSettings();
        Settings.SaveSettings();
    }

    UFUNCTION(BlueprintOverride)
    bool OnHandleBackAction()
    {
        if (bWorldBoardHost)
        { DeactivateWidget(); }
        else
        { utils_u_i_layout::RemoveWidgetSelf(this); }
        return true;
    }
}
