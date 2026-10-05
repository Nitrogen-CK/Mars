// Author the small Mars video catalogue before the native pack binds its
// UGameUserSettings accessors. The registry lives in the GameInstance; this
// world subsystem starts after it and runs only once per registry lifetime.
class UMars_GameSettings_Subsystem : UScriptWorldSubsystem
{
    UFUNCTION(BlueprintOverride)
    bool ShouldCreateSubsystem(UObject InOuter) const
    {
        auto OuterWorld = InOuter.GetWorld();
        if (ck::Is_NOT_Valid(OuterWorld))
        { return false; }

        return OuterWorld.WorldType == EWorldType::Game ||
            OuterWorld.WorldType == EWorldType::PIE;
    }

    UFUNCTION(BlueprintOverride)
    void OnWorldBeginPlay()
    {
        if (!utils_game_settings::Get_IsSettingRegistered(n"video.vsync"))
        {
            auto VSync = MakeVideoDefinition(n"video.vsync", ECk_GameSettings_ValueType::Bool,
                "false", NSLOCTEXT("MarsSettings", "VSync", "VSync"));
            VSync.Set_Description(NSLOCTEXT("MarsSettings", "VSyncDescription", "Synchronizes frames with your display to reduce screen tearing."));

            auto Shadow = MakeVideoDefinition(n"video.sg.shadow", ECk_GameSettings_ValueType::Int32,
                "3", NSLOCTEXT("MarsSettings", "ShadowQuality", "Shadows"));
            Shadow.Set_MinValue("0");
            Shadow.Set_MaxValue("4");
            TArray<FCk_GameSettings_SettingOption> ShadowOptions;
            ShadowOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityLow", "Low"), "0"));
            ShadowOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityMedium", "Medium"), "1"));
            ShadowOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityHigh", "High"), "2"));
            ShadowOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityEpic", "Epic"), "3"));
            ShadowOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityCinematic", "Cinematic"), "4"));
            Shadow.Set_Options(ShadowOptions);
            Shadow.Set_Description(NSLOCTEXT("MarsSettings", "ShadowDescription", "Controls shadow detail. Lower settings can improve performance."));

            auto QualityPreset = MakeVideoDefinition(n"video.quality_preset", ECk_GameSettings_ValueType::Int32,
                "3", NSLOCTEXT("MarsSettings", "OverallQuality", "Graphics quality"));
            QualityPreset.Set_MinValue("-1");
            TArray<FCk_GameSettings_SettingOption> QualityOptions;
            QualityOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "PresetLow", "Low"), "0"));
            QualityOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "PresetMedium", "Medium"), "1"));
            QualityOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "PresetHigh", "High"), "2"));
            QualityOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "PresetUltra", "Ultra"), "3"));
            if (UGameUserSettings::GetGameUserSettings().GetOverallScalabilityLevel() == 4)
            {
                QualityOptions.Add(FCk_GameSettings_SettingOption(
                    NSLOCTEXT("MarsSettings", "PresetCustomCinematic", "Cinematic (Current)"), "4"));
            }
            QualityPreset.Set_MaxValue(QualityOptions.Num() > 4 ? "4" : "3");
            QualityPreset.Set_Options(QualityOptions);
            QualityPreset.Set_Description(NSLOCTEXT("MarsSettings", "OverallQualityDescription",
                "Sets the overall graphics quality preset. Individual quality settings can be adjusted afterward."));
            QualityPreset.Set_OptionalRowClassOverride(SettingsDropdownRowClass());

            auto ViewDistance = MakeVideoDefinition(n"video.sg.view_distance", ECk_GameSettings_ValueType::Int32,
                "3", NSLOCTEXT("MarsSettings", "ViewDistance", "View distance"));
            ViewDistance.Set_MinValue("0");
            TArray<FCk_GameSettings_SettingOption> DistanceOptions;
            DistanceOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "DistanceNear", "Near"), "0"));
            DistanceOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "DistanceMedium", "Medium"), "1"));
            DistanceOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "DistanceFar", "Far"), "2"));
            DistanceOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "DistanceVeryFar", "Very Far"), "3"));
            if (UGameUserSettings::GetGameUserSettings().GetViewDistanceQuality() == 4)
            {
                DistanceOptions.Add(FCk_GameSettings_SettingOption(
                    NSLOCTEXT("MarsSettings", "DistanceCustomCinematic", "Cinematic (Current)"), "4"));
            }
            ViewDistance.Set_MaxValue(DistanceOptions.Num() > 4 ? "4" : "3");
            ViewDistance.Set_Options(DistanceOptions);
            ViewDistance.Set_Description(NSLOCTEXT("MarsSettings", "ViewDistanceDescription",
                "Controls how far detailed objects remain visible."));
            ViewDistance.Set_OptionalRowClassOverride(SettingsDropdownRowClass());

            auto Effects = MakeVideoDefinition(n"video.sg.effects", ECk_GameSettings_ValueType::Int32,
                "3", NSLOCTEXT("MarsSettings", "EffectsQuality", "Effects"));
            Effects.Set_MinValue("0");
            Effects.Set_MaxValue("4");
            Effects.Set_Options(ShadowOptions);
            Effects.Set_Description(NSLOCTEXT("MarsSettings", "EffectsDescription", "Controls visual effect quality. Lower settings can reduce GPU load."));

            // The concept uses labelled presets. Keep the native external float
            // contract, including zero for unlimited, behind the selector.
            auto FpsCap = MakeVideoDefinition(n"video.fps_cap", ECk_GameSettings_ValueType::Float,
                "60", NSLOCTEXT("MarsSettings", "FpsCap", "Frame rate limit"));
            FpsCap.Set_Description(NSLOCTEXT("MarsSettings", "FpsCapDescription", "Limits frames per second. A lower cap can reduce GPU load; Unlimited removes the cap."));
            FpsCap.Set_MinValue("0");
            TArray<FCk_GameSettings_SettingOption> FpsOptions;
            TArray<int> Caps;
            Caps.Add(30);
            Caps.Add(45);
            Caps.Add(60);
            Caps.Add(90);
            Caps.Add(120);
            Caps.Add(144);
            Caps.Add(165);
            Caps.Add(240);
            for (auto Cap : Caps)
            {
                FpsOptions.Add(FCk_GameSettings_SettingOption(
                    FText::FromString(f"{Cap} FPS"), f"{Cap}"));
            }
            FpsOptions.Add(FCk_GameSettings_SettingOption(
                NSLOCTEXT("MarsSettings", "FpsUnlimited", "Unlimited"), "0"));
            // Do not rewrite an existing user preference just to fit the menu.
            const float SavedCap = UGameUserSettings::GetGameUserSettings().GetFrameRateLimit();
            if (SavedCap > 0.0f && SavedCap != 30.0f && SavedCap != 45.0f &&
                SavedCap != 60.0f && SavedCap != 90.0f && SavedCap != 120.0f &&
                SavedCap != 144.0f && SavedCap != 165.0f && SavedCap != 240.0f)
            {
                FpsOptions.Add(FCk_GameSettings_SettingOption(
                    FText::FromString(f"{SavedCap} FPS (Custom)"), f"{SavedCap}"));
            }
            FpsCap.Set_Options(FpsOptions);
            FpsCap.Set_OptionalRowClassOverride(SettingsDropdownRowClass());

            TArray<FCk_GameSettings_SettingDefinition> Definitions;
            Definitions.Add(QualityPreset);
            Definitions.Add(VSync);
            Definitions.Add(ViewDistance);
            Definitions.Add(Shadow);
            Definitions.Add(Effects);
            Definitions.Add(FpsCap);
            if (!utils_game_settings::Request_RegisterSettings(Definitions))
            { return; }
        }

        // A menu preference uses the registry's own machine-scope ini storage.
        // It has no external video accessor or runtime apply handler.
        if (!utils_game_settings::Get_IsSettingRegistered(n"menu.reduced_motion"))
        {
            auto ReducedMotion = FCk_GameSettings_SettingDefinition(
                n"menu.reduced_motion", ECk_GameSettings_ValueType::Bool, "false");
            ReducedMotion.Set_DisplayName(NSLOCTEXT("MarsSettings", "ReducedMotion", "Reduced Motion"));
            ReducedMotion.Set_Description(NSLOCTEXT("MarsSettings", "ReducedMotionDescription",
                "Cuts menu camera transitions to a brief fade."));
            if (!utils_game_settings::Request_RegisterSetting(ReducedMotion))
            { return; }
        }

        if (!utils_game_settings::Get_IsSettingRegistered(n"controls.look_sensitivity"))
        {
            auto Sensitivity = FCk_GameSettings_SettingDefinition(
                n"controls.look_sensitivity", ECk_GameSettings_ValueType::Float, "1.0");
            Sensitivity.Set_DisplayName(NSLOCTEXT("MarsSettings", "LookSensitivity", "Look sensitivity"));
            Sensitivity.Set_Description(NSLOCTEXT("MarsSettings", "LookSensitivityDescription",
                "Scales mouse and controller camera movement."));
            Sensitivity.Set_MinValue("0.1");
            Sensitivity.Set_MaxValue("3.0");
            Sensitivity.Set_OptionalStepSize(0.05f);
            Sensitivity.Set_OptionalDisplayPrecision(2);
            Sensitivity.Set_OptionalRowClassOverride(TSoftClassPtr<UCk_GameSettingsUI_RowWidgetBase>(
                FSoftObjectPath("/Game/Mars/UI/Widgets/ChalkParchment/SettingsSliderRow_Mars_WBP.SettingsSliderRow_Mars_WBP_C")));

            auto InvertY = FCk_GameSettings_SettingDefinition(
                n"controls.invert_y", ECk_GameSettings_ValueType::Bool, "false");
            InvertY.Set_DisplayName(NSLOCTEXT("MarsSettings", "InvertY", "Invert vertical look"));
            InvertY.Set_Description(NSLOCTEXT("MarsSettings", "InvertYDescription",
                "Reverses vertical camera movement."));

            auto SprintToggle = FCk_GameSettings_SettingDefinition(
                n"controls.sprint_toggle", ECk_GameSettings_ValueType::Bool, "false");
            SprintToggle.Set_DisplayName(NSLOCTEXT("MarsSettings", "SprintMode", "Sprint mode"));
            SprintToggle.Set_Description(NSLOCTEXT("MarsSettings", "SprintModeDescription",
                "Hold sprints while the button is held. Toggle switches sprint with each press."));
            TArray<FCk_GameSettings_SettingOption> SprintOptions;
            SprintOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "SprintHold", "Hold"), "false"));
            SprintOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "SprintToggle", "Toggle"), "true"));
            SprintToggle.Set_Options(SprintOptions);
            SprintToggle.Set_OptionalRowClassOverride(SettingsDropdownRowClass());

            TArray<FCk_GameSettings_SettingDefinition> Controls;
            Controls.Add(Sensitivity);
            Controls.Add(InvertY);
            Controls.Add(SprintToggle);
            if (!utils_game_settings::Request_RegisterSettings(Controls))
            { return; }
        }

        // Audio definitions and sound-class apply handlers are owned by the native pack.
        // They must not be pre-registered here: the pack skips existing keys.
        if (!utils_game_settings::Get_IsSettingRegistered(n"audio.master") ||
            !utils_game_settings::Get_IsSettingRegistered(n"audio.music") ||
            !utils_game_settings::Get_IsSettingRegistered(n"audio.sfx") ||
            !utils_game_settings::Get_IsSettingRegistered(n"audio.voice"))
        { utils_game_settings::Request_RegisterAudioPack(); }

        // The pack can be retried after a failed or interrupted registration;
        // foliage is the last pack-owned quality key to register.
        if (!utils_game_settings::Get_IsSettingRegistered(n"video.sg.foliage"))
        { utils_game_settings::Request_RegisterVideoPack(); }

    }

    private FCk_GameSettings_SettingDefinition MakeVideoDefinition(
        FName InKey, ECk_GameSettings_ValueType InType, FString InDefault, FText InName)
    {
        auto Definition = FCk_GameSettings_SettingDefinition(InKey, InType, InDefault);
        Definition.Set_PersistencePolicy(ECk_GameSettings_PersistencePolicy::External);
        Definition.Set_ApplyBindingType(ECk_GameSettings_ApplyBindingType::Handler);
        Definition.Set_DisplayName(InName);
        return Definition;
    }

    private TSoftClassPtr<UCk_GameSettingsUI_RowWidgetBase> SettingsDropdownRowClass() const
    {
        return TSoftClassPtr<UCk_GameSettingsUI_RowWidgetBase>(FSoftObjectPath(
            "/Game/Mars/UI/Widgets/ChalkParchment/SettingsDropdownRow_Mars_WBP.SettingsDropdownRow_Mars_WBP_C"));
    }
}
