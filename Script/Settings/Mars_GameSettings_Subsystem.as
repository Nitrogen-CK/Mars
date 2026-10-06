// Mars's settings catalogue. A world subsystem on purpose: by OnWorldBeginPlay every GameInstance subsystem, including
// the CkGameSettings registry, is initialized, and the registration guards make repeat worlds a no-op.
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
        if (!utils_game_settings::Get_IsSettingRegistered(constants_settings::k_VideoVSync))
        { RegisterVideo(); }

        if (!utils_game_settings::Get_IsSettingRegistered(constants_settings::k_LookSensitivity))
        { RegisterControls(); }

        // The audio pack owns its definitions and sound-class handlers; it skips keys that already exist.
        if (!utils_game_settings::Get_IsSettingRegistered(constants_settings::k_AudioMaster) ||
            !utils_game_settings::Get_IsSettingRegistered(constants_settings::k_AudioMusic) ||
            !utils_game_settings::Get_IsSettingRegistered(constants_settings::k_AudioSfx) ||
            !utils_game_settings::Get_IsSettingRegistered(constants_settings::k_AudioVoice))
        { utils_game_settings::Request_RegisterAudioPack(); }

        // Runs after the Mars video keys exist so the pack only binds their UGameUserSettings accessors.
        if (!utils_game_settings::Get_IsSettingRegistered(constants_settings::k_VideoFoliage))
        { utils_game_settings::Request_RegisterVideoPack(); }
    }

    private void RegisterVideo()
    {
        auto VSync = MakeVideoDefinition(constants_settings::k_VideoVSync, ECk_GameSettings_ValueType::Bool, "false");
        VSync.Set_DisplayName(NSLOCTEXT("MarsSettings", "VSync", "VSync"));
        VSync.Set_Description(NSLOCTEXT("MarsSettings", "VSyncDescription", "Synchronizes frames with your display to reduce screen tearing."));

        TArray<FCk_GameSettings_SettingOption> QualityLevelOptions;
        QualityLevelOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityLow", "Low"), "0"));
        QualityLevelOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityMedium", "Medium"), "1"));
        QualityLevelOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityHigh", "High"), "2"));
        QualityLevelOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityEpic", "Epic"), "3"));
        QualityLevelOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "QualityCinematic", "Cinematic"), "4"));

        auto Shadow = MakeVideoDefinition(constants_settings::k_VideoShadow, ECk_GameSettings_ValueType::Int32, "3");
        Shadow.Set_DisplayName(NSLOCTEXT("MarsSettings", "ShadowQuality", "Shadows"));
        Shadow.Set_MinValue("0");
        Shadow.Set_MaxValue("4");
        Shadow.Set_Options(QualityLevelOptions);
        Shadow.Set_Description(NSLOCTEXT("MarsSettings", "ShadowDescription", "Controls shadow detail. Lower settings can improve performance."));

        auto Effects = MakeVideoDefinition(constants_settings::k_VideoEffects, ECk_GameSettings_ValueType::Int32, "3");
        Effects.Set_DisplayName(NSLOCTEXT("MarsSettings", "EffectsQuality", "Effects"));
        Effects.Set_MinValue("0");
        Effects.Set_MaxValue("4");
        Effects.Set_Options(QualityLevelOptions);
        Effects.Set_Description(NSLOCTEXT("MarsSettings", "EffectsDescription", "Controls visual effect quality. Lower settings can reduce GPU load."));

        auto QualityPreset = MakeVideoDefinition(constants_settings::k_VideoQualityPreset, ECk_GameSettings_ValueType::Int32, "3");
        QualityPreset.Set_DisplayName(NSLOCTEXT("MarsSettings", "OverallQuality", "Graphics quality"));
        QualityPreset.Set_MinValue(f"{constants_settings::k_MixedQualityPreset}");
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
        // What the accessor reports once any group below is edited away from the preset. Choosing it is a no-op:
        // the video pack ignores a negative preset.
        QualityOptions.Add(FCk_GameSettings_SettingOption(
            NSLOCTEXT("MarsSettings", "PresetCustom", "Custom"), f"{constants_settings::k_MixedQualityPreset}"));
        QualityPreset.Set_Options(QualityOptions);
        QualityPreset.Set_Description(NSLOCTEXT("MarsSettings", "OverallQualityDescription",
            "Sets the overall graphics quality preset. Individual quality settings can be adjusted afterward."));

        auto ViewDistance = MakeVideoDefinition(constants_settings::k_VideoViewDistance, ECk_GameSettings_ValueType::Int32, "3");
        ViewDistance.Set_DisplayName(NSLOCTEXT("MarsSettings", "ViewDistance", "View distance"));
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

        // Labelled presets over the pack's External float contract, where zero means unlimited.
        auto FpsCap = MakeVideoDefinition(constants_settings::k_VideoFpsCap, ECk_GameSettings_ValueType::Float, "60");
        FpsCap.Set_DisplayName(NSLOCTEXT("MarsSettings", "FpsCap", "Frame rate limit"));
        FpsCap.Set_Description(NSLOCTEXT("MarsSettings", "FpsCapDescription", "Limits frames per second. A lower cap can reduce GPU load; Unlimited removes the cap."));
        FpsCap.Set_MinValue("0");
        TArray<FCk_GameSettings_SettingOption> FpsOptions;
        TArray<int32> Caps;
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
        // A cap saved outside the menu's list stays selectable rather than being rewritten to fit the menu.
        const float SavedCap = UGameUserSettings::GetGameUserSettings().GetFrameRateLimit();
        const bool SavedCapIsListed = Caps.Contains(int32(SavedCap)) && float(int32(SavedCap)) == SavedCap;
        if (SavedCap > 0.0f && !SavedCapIsListed)
        {
            FpsOptions.Add(FCk_GameSettings_SettingOption(
                FText::FromString(f"{SavedCap} FPS (Custom)"), f"{SavedCap}"));
        }
        FpsCap.Set_Options(FpsOptions);

        TArray<FCk_GameSettings_SettingDefinition> Definitions;
        Definitions.Add(QualityPreset);
        Definitions.Add(VSync);
        Definitions.Add(ViewDistance);
        Definitions.Add(Shadow);
        Definitions.Add(Effects);
        Definitions.Add(FpsCap);
        utils_game_settings::Request_RegisterSettings(Definitions);
    }

    private void RegisterControls()
    {
        auto Tags = GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(constants_settings::k_Category_Controls));

        auto Sensitivity = FCk_GameSettings_SettingDefinition(
            constants_settings::k_LookSensitivity, ECk_GameSettings_ValueType::Float, "1.0");
        Sensitivity.Set_DisplayName(NSLOCTEXT("MarsSettings", "LookSensitivity", "Look sensitivity"));
        Sensitivity.Set_Description(NSLOCTEXT("MarsSettings", "LookSensitivityDescription",
            "Scales mouse and controller camera movement."));
        Sensitivity.Set_MinValue("0.1");
        Sensitivity.Set_MaxValue("3.0");
        Sensitivity.Set_OptionalStepSize(0.05f);
        Sensitivity.Set_OptionalDisplayPrecision(2);
        Sensitivity.Set_CategoryTags(Tags);

        auto InvertY = FCk_GameSettings_SettingDefinition(
            constants_settings::k_InvertY, ECk_GameSettings_ValueType::Bool, "false");
        InvertY.Set_DisplayName(NSLOCTEXT("MarsSettings", "InvertY", "Invert vertical look"));
        InvertY.Set_Description(NSLOCTEXT("MarsSettings", "InvertYDescription",
            "Reverses vertical camera movement."));
        InvertY.Set_CategoryTags(Tags);

        auto SprintToggle = FCk_GameSettings_SettingDefinition(
            constants_settings::k_SprintToggle, ECk_GameSettings_ValueType::Bool, "false");
        SprintToggle.Set_DisplayName(NSLOCTEXT("MarsSettings", "SprintMode", "Sprint mode"));
        SprintToggle.Set_Description(NSLOCTEXT("MarsSettings", "SprintModeDescription",
            "Hold sprints while the button is held. Toggle switches sprint with each press."));
        TArray<FCk_GameSettings_SettingOption> SprintOptions;
        SprintOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "SprintHold", "Hold"), "false"));
        SprintOptions.Add(FCk_GameSettings_SettingOption(NSLOCTEXT("MarsSettings", "SprintToggle", "Toggle"), "true"));
        SprintToggle.Set_Options(SprintOptions);
        SprintToggle.Set_CategoryTags(Tags);

        TArray<FCk_GameSettings_SettingDefinition> Controls;
        Controls.Add(Sensitivity);
        Controls.Add(InvertY);
        Controls.Add(SprintToggle);
        utils_game_settings::Request_RegisterSettings(Controls);
    }

    // The video pack's contract for a game-owned video.* key: UGameUserSettings holds the value, the store never does.
    private FCk_GameSettings_SettingDefinition MakeVideoDefinition(
        FName InKey, ECk_GameSettings_ValueType InType, FString InDefault)
    {
        auto Definition = FCk_GameSettings_SettingDefinition(InKey, InType, InDefault);
        Definition.Set_PersistencePolicy(ECk_GameSettings_PersistencePolicy::External);
        Definition.Set_ApplyBindingType(ECk_GameSettings_ApplyBindingType::Handler);
        Definition.Set_CategoryTags(GameplayTag::MakeContainerFromTag(
            GameplayTags::ResolveGameplayTag(constants_settings::k_Category_Video)));
        return Definition;
    }
}
