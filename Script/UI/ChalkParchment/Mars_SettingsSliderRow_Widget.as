// The native row owns typed values, capture and pending changes. The game
// supplies the volume suffix and filled-track presentation in AngelScript.
UCLASS(Abstract)
class UMars_SettingsSliderRow_Widget : UCk_GameSettingsUI_RowWidget_Slider
{
    UPROPERTY(meta = (BindWidgetOptional))
    USizeBox FillSize;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget FocusCorners;

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Style")
    float32 ThumbSize = 40.0f;

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        if (ck::Is_NOT_Valid(_ValueSlider))
        { return; }

        const float32 Value = _ValueSlider.GetValue();
        const FName Key = Get_SettingKey();
        if (ck::IsValid(FocusCorners))
        { FocusCorners.SetVisibility(_ValueSlider.IsHovered() || _ValueSlider.HasAnyUserFocus()
            ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed); }
        if (ck::IsValid(_ValueText) && Key.ToString().StartsWith("audio."))
        {
            const FText Label = FText::FromString(f"{Math::RoundToInt(Value * 100.0f)}%");
            if (!_ValueText.GetText().EqualTo(Label))
            { _ValueText.SetText(Label); }
        }

        if (ck::IsValid(FillSize))
        {
            // IndentHandle=false: SSlider's thumb centre travels from half a
            // thumb to width minus half a thumb. Match that actual geometry.
            const float32 Width = Math::Max(0.0f, float32(_ValueSlider.GetCachedGeometry().GetLocalSize().X) - ThumbSize);
            const float32 Fraction = _ValueSlider.GetNormalizedValue();
            FillSize.SetWidthOverride(Width * Fraction);
            FillSize.SetVisibility(Fraction > 0.0f ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Hidden);
        }
    }
}
