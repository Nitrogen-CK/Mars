// Quality rows depend on each other through UGameUserSettings: a preset rewrites every scalability group, and a group
// edit turns the preset mixed, and neither fires the other key's change event. A quality row re-reads itself whenever a
// sibling quality key changes; its own key is refreshed by the native row.
UCLASS(Abstract)
class UMars_SettingsDropdownRow_Widget : UCk_GameSettingsUI_RowWidget_Dropdown
{
    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        utils_game_settings::BindTo_OnSettingChanged(NAME_None,
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnAnySettingChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void Destruct()
    {
        utils_game_settings::UnbindFrom_OnSettingChanged(NAME_None,
            FCk_Delegate_GameSettings_OnSettingChanged(this, n"OnAnySettingChanged"));
    }

    UFUNCTION()
    private void OnAnySettingChanged(FName InKey, FString InValue)
    {
        const FName OwnKey = Get_SettingKey();
        if (InKey == OwnKey || !Get_IsQualityKey(InKey) || !Get_IsQualityKey(OwnKey))
        { return; }

        InjectSetting(this, OwnKey);
    }

    private bool Get_IsQualityKey(FName InKey) const
    {
        return InKey == constants_settings::k_VideoQualityPreset ||
            InKey.ToString().StartsWith("video.sg.");
    }
}
