UCLASS(Abstract)
class UMars_SettingsDropdownRow_Widget : UCk_GameSettingsUI_RowWidget_Dropdown
{
    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        const FName Key = Get_SettingKey();
        if ((Key != n"video.quality_preset" && Key != n"video.sg.view_distance") ||
            ck::Is_NOT_Valid(_ValueComboBox) || _ValueComboBox.IsOpen())
        { return; }

        // View distance can make the group mixed without changing the preset
        // key. Show that derived state, rather than retaining a false preset.
        // A preset also changes view distance through GameUserSettings, without
        // emitting the individual key's change event. Keep both rows truthful.
        const int Quality = utils_game_settings::Get_SettingValue_Int32(Key, -1);
        if (Quality < 0 && Key == n"video.quality_preset")
        {
            const FString Label = NSLOCTEXT("MarsSettings", "CustomQuality", "Custom").ToString();
            if (_ValueComboBox.FindOptionIndex(Label) < 0)
            { _ValueComboBox.AddOption(Label); }
            if (_ValueComboBox.GetSelectedOption() != Label)
            { _ValueComboBox.SetSelectedOption(Label); }
            // This display-only trailing item has no definition option. The
            // native row rejects its index instead of applying a fake preset.
        }
        else if (Quality >= 0 && _ValueComboBox.GetSelectedIndex() != Quality)
        { _ValueComboBox.SetSelectedIndex(Quality); }
    }
}
