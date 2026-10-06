// The scalability levels UGameUserSettings holds before a preset is previewed.
struct FMars_ScalabilityLevels
{
    UPROPERTY()
    int32 ViewDistance = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 Shadow = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 GlobalIllumination = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 Reflection = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 AntiAliasing = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 Texture = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 VisualEffect = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 PostProcessing = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 Foliage = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 Shading = constants_settings::k_EpicQualityLevel;

    UPROPERTY()
    int32 Landscape = constants_settings::k_EpicQualityLevel;
}

struct FMars_QualityBaseline
{
    UPROPERTY()
    int32 Preset = constants_settings::k_MixedQualityPreset;

    UPROPERTY()
    float32 ResolutionScale = 1.0f;

    UPROPERTY()
    FMars_ScalabilityLevels Levels;
}

enum EMars_SettingsPresentation
{
    // Pushed on a CkUI layer over the game, behind the scrim; Back removes it.
    Screen,
    // Rendered on a vestibule world board; the presenter activates it, and Back only deactivates it.
    WorldBoard
}

event void FMars_ChalkSettingsWorldBoardClosed();

// The native screen builds and binds rows from the CkGameSettings registry; this subclass owns the tab rail, the help
// panel and the pending-changes presentation.
UCLASS(Abstract)
class UMars_ChalkSettings_Widget : UCk_GameSettingsUI_ScreenWidget
{
    default bIsFocusable = true;
    default bIsBackHandler = true;

    EMars_SettingsPresentation Presentation = EMars_SettingsPresentation::Screen;

    FMars_ChalkSettingsWorldBoardClosed OnWorldBoardClosed;

    UPROPERTY(meta = (BindWidgetOptional))
    UImage Scrim;

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

    private TArray<FName> _TabOrder;
    private TArray<UMars_Button_Widget> _TabButtons;
    private UCommonButtonGroupBase _TabGroup;
    private FName _ActiveCategory;
    private TArray<UCk_GameSettingsUI_RowWidgetBase> _Rows;
    private FName _HelpKey;
    private bool _QualityPreviewed = false;
    private FMars_QualityBaseline _QualityBaseline;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        _TabGroup = Cast<UCommonButtonGroupBase>(NewObject(this, UCommonButtonGroupBase));
        _TabGroup.SetSelectionRequired(true);
        _TabGroup.OnSelectedButtonBaseChanged.AddUFunction(this, n"OnTabSelectionChanged");

        AddTab(TabAudio, constants_settings::k_Category_Audio);
        AddTab(TabVideo, constants_settings::k_Category_Video);
        AddTab(TabControls, constants_settings::k_Category_Controls);
        if (ck::IsValid(TabAccessibility))
        { TabAccessibility.SetIsEnabled(false); }
        if (ck::IsValid(ViewBindings))
        { ViewBindings.SetIsEnabled(false); }
        if (ck::IsValid(RestoreDefaults))
        { RestoreDefaults.OnButtonBaseClicked.AddUFunction(this, n"OnRestoreDefaults"); }
        if (ck::IsValid(_ApplyButton))
        { _ApplyButton.OnButtonBaseClicked.AddUFunction(this, n"OnApplyClicked"); }

        SelectCategory(constants_settings::k_Category_Audio);
        if (ck::IsValid(PendingText))
        { PendingText.SetText(NSLOCTEXT("MarsSettings", "PendingChanges", "Unsaved changes")); }
    }

    UFUNCTION(BlueprintOverride)
    void OnActivated()
    {
        utils_game_settings::BindTo_OnSettingChanged(NAME_None,
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnAnySettingChanged"));
        utils_game_settings::BindTo_OnSettingChanged(constants_settings::k_VideoQualityPreset,
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnQualityChanged"));
        CaptureQualityBaseline();
        _QualityPreviewed = false;
        RefreshPendingStatus();
        if (ck::IsValid(Scrim))
        {
            Scrim.SetVisibility(Presentation == EMars_SettingsPresentation::WorldBoard
                ? ESlateVisibility::Collapsed
                : ESlateVisibility::HitTestInvisible);
        }
    }

    UFUNCTION(BlueprintOverride)
    void OnDeactivated()
    {
        utils_game_settings::UnbindFrom_OnSettingChanged(NAME_None,
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnAnySettingChanged"));
        utils_game_settings::UnbindFrom_OnSettingChanged(constants_settings::k_VideoQualityPreset,
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnQualityChanged"));
        // The native cancel has already re-applied the prior preset through the video pack, which ignores a mixed
        // prior; only a mixed group needs restoring here.
        if (_QualityPreviewed && _QualityBaseline.Preset == constants_settings::k_MixedQualityPreset)
        { RestoreQualityBaseline(); }
        _QualityPreviewed = false;
        if (Presentation == EMars_SettingsPresentation::WorldBoard)
        { OnWorldBoardClosed.Broadcast(); }
    }

    // A dropdown open on a world board; its popup menu consumes Escape, so the presenter forwards Back to it.
    UComboBoxString GetOpenDropdown() const
    {
        for (auto Row : _Rows)
        {
            auto DropdownRow = Cast<UCk_GameSettingsUI_RowWidget_Dropdown>(Row);
            if (ck::IsValid(DropdownRow) && DropdownRow.IsVisible() && ck::IsValid(DropdownRow._ValueComboBox) &&
                DropdownRow._ValueComboBox.IsOpen())
            { return DropdownRow._ValueComboBox; }
        }

        return nullptr;
    }

    UFUNCTION(BlueprintOverride)
    void OnRowGenerated(UCk_GameSettingsUI_RowWidgetBase InRow, FName InCategory)
    {
        _Rows.AddUnique(InRow);
        InRow.SetToolTipText(FText());
    }

    // The native row re-applies the definition's description as its tooltip on every refresh; the help panel shows it.
    UFUNCTION()
    private void OnAnySettingChanged(FName InKey, FString InValue)
    {
        for (auto Row : _Rows)
        {
            if (ck::IsValid(Row) && Row.Get_SettingKey() == InKey)
            { Row.SetToolTipText(FText()); }
        }
        RefreshPendingStatus();
    }

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        if (!IsActivated())
        { return; }

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
    UWidget BP_GetDesiredFocusTarget() const
    { return GetPreferredFocusTarget(); }

    UWidget GetPreferredFocusTarget() const
    {
        const int32 Index = _TabOrder.FindIndex(_ActiveCategory);
        return _TabButtons.IsValidIndex(Index) ? _TabButtons[Index] : nullptr;
    }

    UFUNCTION(BlueprintOverride)
    TArray<FName> Get_CuratedKeysForCategory(FName InCategory)
    { return Get_CuratedKeys(InCategory); }

    private TArray<FName> Get_CuratedKeys(FName InCategory) const
    {
        TArray<FName> Keys;

        if (InCategory == constants_settings::k_Category_Audio)
        {
            Keys.Add(constants_settings::k_AudioMaster);
            Keys.Add(constants_settings::k_AudioMusic);
            Keys.Add(constants_settings::k_AudioSfx);
            Keys.Add(constants_settings::k_AudioVoice);
        }
        else if (InCategory == constants_settings::k_Category_Video)
        {
            Keys.Add(constants_settings::k_VideoQualityPreset);
            Keys.Add(constants_settings::k_VideoViewDistance);
            Keys.Add(constants_settings::k_VideoShadow);
            Keys.Add(constants_settings::k_VideoEffects);
            Keys.Add(constants_settings::k_VideoVSync);
            Keys.Add(constants_settings::k_VideoFpsCap);
        }
        else if (InCategory == constants_settings::k_Category_Controls)
        {
            Keys.Add(constants_settings::k_LookSensitivity);
            Keys.Add(constants_settings::k_InvertY);
            Keys.Add(constants_settings::k_SprintToggle);
        }

        return Keys;
    }

    UFUNCTION(BlueprintCallable)
    void ShowHelpForKey(FName InKey)
    {
        if (_HelpKey == InKey || !Get_HasRowForKey(InKey))
        { return; }

        FCk_GameSettings_SettingDefinition Definition;
        if (ck::EnsureIfNot(utils_game_settings::Get_SettingDefinition(InKey, Definition),
            f"[Settings] a visible row is bound to unregistered key {InKey.ToString()}"))
        { return; }
        _HelpKey = InKey;

        if (ck::IsValid(HelpTitle))
        { HelpTitle.SetText(Definition.Get_DisplayName()); }
        if (ck::IsValid(HelpDescription))
        {
            auto Description = Definition.Get_Description();
            if (InKey == constants_settings::k_AudioMaster)
            { Description = NSLOCTEXT("MarsSettings", "MasterHelp", "Adjusts the volume of all game audio."); }
            else if (InKey == constants_settings::k_AudioMusic)
            { Description = NSLOCTEXT("MarsSettings", "MusicHelp", "Adjusts music in menus, camp and expeditions. Sound effects and voices are unchanged."); }
            else if (InKey == constants_settings::k_AudioSfx)
            { Description = NSLOCTEXT("MarsSettings", "SfxHelp", "Adjusts footsteps, interactions and other sound effects."); }
            else if (InKey == constants_settings::k_AudioVoice)
            { Description = NSLOCTEXT("MarsSettings", "VoiceHelp", "Adjusts audio routed through the voice channel."); }
            HelpDescription.SetText(Description.IsEmpty()
                ? NSLOCTEXT("MarsSettings", "NoSettingDescription", "Apply saves this setting. Cancel restores its previous value.")
                : Description);
        }
    }

    private void RefreshPendingStatus()
    {
        if (ck::Is_NOT_Valid(PendingText))
        { return; }

        PendingText.SetVisibility(utils_game_settings::Get_HasPendingChanges()
            ? ESlateVisibility::SelfHitTestInvisible
            : ESlateVisibility::Collapsed);
    }

    private void SelectCategory(FName InCategory)
    {
        if (_ActiveCategory == InCategory)
        { return; }

        _ActiveCategory = InCategory;
        Request_SetActiveCategory(InCategory);
        RefreshCategoryPresentation();
    }

    private void RefreshCategoryPresentation()
    {
        _HelpKey = NAME_None;
        FText CategoryTitle;
        FText RestoreText;
        if (_ActiveCategory == constants_settings::k_Category_Audio)
        {
            CategoryTitle = NSLOCTEXT("MarsSettings", "AudioGroup", "AUDIO");
            RestoreText = NSLOCTEXT("MarsSettings", "RestoreAudio", "Restore audio defaults");
        }
        else if (_ActiveCategory == constants_settings::k_Category_Video)
        {
            CategoryTitle = NSLOCTEXT("MarsSettings", "VideoGroup", "VIDEO");
            RestoreText = NSLOCTEXT("MarsSettings", "RestoreVideo", "Restore video defaults");
        }
        else
        {
            CategoryTitle = NSLOCTEXT("MarsSettings", "ControlsGroup", "CONTROLS");
            RestoreText = NSLOCTEXT("MarsSettings", "RestoreControls", "Restore controls defaults");
        }

        if (ck::IsValid(RestoreDefaults))
        {
            RestoreDefaults.ButtonText = RestoreText;
            RestoreDefaults.RefreshLabel();
        }
        if (ck::IsValid(BindingsRow))
        { BindingsRow.SetVisibility(_ActiveCategory == constants_settings::k_Category_Controls
            ? ESlateVisibility::SelfHitTestInvisible : ESlateVisibility::Collapsed); }

        if (ck::IsValid(SectionText))
        { SectionText.SetText(CategoryTitle); }
        if (ck::IsValid(HelpTitle))
        { HelpTitle.SetText(CategoryTitle); }
        if (ck::IsValid(HelpDescription))
        { HelpDescription.SetText(NSLOCTEXT("MarsSettings", "SelectSettingHelp", "Select a setting for details.")); }
    }

    UFUNCTION()
    private void OnTabSelectionChanged(UCommonButtonBase InButton, int32 ButtonIndex)
    {
        if (!_TabOrder.IsValidIndex(ButtonIndex))
        { return; }

        SelectCategory(_TabOrder[ButtonIndex]);
    }

    private void AddTab(UMars_Button_Widget InTab, FName InCategory)
    {
        if (ck::Is_NOT_Valid(InTab))
        { return; }

        InTab.SetIsSelectable(true);
        _TabOrder.Add(InCategory);
        _TabButtons.Add(InTab);
        _TabGroup.AddWidget(InTab);
    }

    UFUNCTION()
    private void OnRestoreDefaults(UCommonButtonBase InButton)
    {
        for (auto Key : Get_CuratedKeys(_ActiveCategory))
        { ResetToDeclaredDefault(Key); }
    }

    // The registry refuses to reset an External key (UGameUserSettings owns its value), so a video key is set to the
    // default its Mars definition declares through the same request a row commit uses.
    private void ResetToDeclaredDefault(FName InKey)
    {
        FCk_GameSettings_SettingDefinition Definition;
        if (ck::EnsureIfNot(utils_game_settings::Get_SettingDefinition(InKey, Definition),
            f"[Settings] cannot reset unregistered key {InKey.ToString()}"))
        { return; }

        if (Definition.Get_PersistencePolicy() == ECk_GameSettings_PersistencePolicy::Provider)
        {
            utils_game_settings::Request_ResetToDefault(FCk_Request_GameSettings_ResetToDefault(InKey));
            return;
        }

        const FString Default = Definition.Get_DefaultValue();
        switch (Definition.Get_ValueType())
        {
            case ECk_GameSettings_ValueType::Bool:
                utils_game_settings::Request_SetSettingValue_Bool(
                    FCk_Request_GameSettings_SetValue_Bool(InKey, Default == "true"));
                break;
            case ECk_GameSettings_ValueType::Int32:
                utils_game_settings::Request_SetSettingValue_Int32(
                    FCk_Request_GameSettings_SetValue_Int32(InKey, int32(String::Conv_StringToInt64(Default))));
                break;
            case ECk_GameSettings_ValueType::Float:
                utils_game_settings::Request_SetSettingValue_Float(
                    FCk_Request_GameSettings_SetValue_Float(InKey, float32(String::Conv_StringToDouble(Default))));
                break;
            case ECk_GameSettings_ValueType::String:
                utils_game_settings::Request_SetSettingValue_String(
                    FCk_Request_GameSettings_SetValue_String(InKey, Default));
                break;
        }
    }

    UFUNCTION()
    private void OnQualityChanged(FName InKey, FString InValue)
    {
        if (utils_game_settings::Get_HasUnappliedChange(constants_settings::k_VideoQualityPreset))
        { _QualityPreviewed = true; }
    }

    UFUNCTION()
    private void OnApplyClicked(UCommonButtonBase InButton)
    {
        CaptureQualityBaseline();
        _QualityPreviewed = false;
        RefreshPendingStatus();
    }

    private void CaptureQualityBaseline()
    {
        auto Settings = UGameUserSettings::GetGameUserSettings();
        _QualityBaseline.Preset = Settings.GetOverallScalabilityLevel();
        _QualityBaseline.ResolutionScale = Settings.GetResolutionScaleNormalized();
        _QualityBaseline.Levels.ViewDistance = Settings.GetViewDistanceQuality();
        _QualityBaseline.Levels.Shadow = Settings.GetShadowQuality();
        _QualityBaseline.Levels.GlobalIllumination = Settings.GetGlobalIlluminationQuality();
        _QualityBaseline.Levels.Reflection = Settings.GetReflectionQuality();
        _QualityBaseline.Levels.AntiAliasing = Settings.GetAntiAliasingQuality();
        _QualityBaseline.Levels.Texture = Settings.GetTextureQuality();
        _QualityBaseline.Levels.VisualEffect = Settings.GetVisualEffectQuality();
        _QualityBaseline.Levels.PostProcessing = Settings.GetPostProcessingQuality();
        _QualityBaseline.Levels.Foliage = Settings.GetFoliageQuality();
        _QualityBaseline.Levels.Shading = Settings.GetShadingQuality();
        // Landscape has no GameUserSettings accessor; the console variable holds the applied level.
        _QualityBaseline.Levels.Landscape = FConsoleVariable("sg.LandscapeQuality", constants_settings::k_EpicQualityLevel).GetInt();
    }

    // Saved as well as applied: the previewed preset already reached GameUserSettings.ini through the video pack.
    private void RestoreQualityBaseline()
    {
        auto Settings = UGameUserSettings::GetGameUserSettings();
        const auto Levels = _QualityBaseline.Levels;
        // The preset is the only writer of the landscape level; every exposed group is overwritten below.
        Settings.SetOverallScalabilityLevel(Levels.Landscape);
        Settings.SetViewDistanceQuality(Levels.ViewDistance);
        Settings.SetShadowQuality(Levels.Shadow);
        Settings.SetGlobalIlluminationQuality(Levels.GlobalIllumination);
        Settings.SetReflectionQuality(Levels.Reflection);
        Settings.SetAntiAliasingQuality(Levels.AntiAliasing);
        Settings.SetTextureQuality(Levels.Texture);
        Settings.SetVisualEffectQuality(Levels.VisualEffect);
        Settings.SetPostProcessingQuality(Levels.PostProcessing);
        Settings.SetFoliageQuality(Levels.Foliage);
        Settings.SetShadingQuality(Levels.Shading);
        Settings.SetResolutionScaleNormalized(_QualityBaseline.ResolutionScale);
        Settings.ApplyNonResolutionSettings();
        Settings.SaveSettings();
    }

    UFUNCTION(BlueprintOverride)
    bool OnHandleBackAction()
    {
        if (Presentation == EMars_SettingsPresentation::WorldBoard)
        { DeactivateWidget(); }
        else
        { utils_u_i_layout::RemoveWidgetSelf(this); }
        return true;
    }
}
