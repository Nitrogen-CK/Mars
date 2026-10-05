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

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Style")
    FLinearColor ThumbIdle = FLinearColor(1.0f, 1.0f, 1.0f);

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Style")
    FLinearColor ThumbHovered = FLinearColor(0.55f, 0.72f, 0.30f);

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Style")
    FLinearColor ThumbPressed = FLinearColor(0.20f, 0.34f, 0.10f);

    private bool _Captured = false;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        _ValueSlider.OnMouseCaptureBegin.AddUFunction(this, n"OnCaptureStarted");
        _ValueSlider.OnMouseCaptureEnd.AddUFunction(this, n"OnCaptureStopped");
        _ValueSlider.OnControllerCaptureBegin.AddUFunction(this, n"OnCaptureStarted");
        _ValueSlider.OnControllerCaptureEnd.AddUFunction(this, n"OnCaptureStopped");
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    { _Captured = false; }

    UFUNCTION(BlueprintOverride)
    void Destruct()
    { _Captured = false; }

    UFUNCTION()
    private void OnCaptureStarted()
    { _Captured = true; }

    UFUNCTION()
    private void OnCaptureStopped()
    { _Captured = false; }

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        if (ck::Is_NOT_Valid(_ValueSlider))
        { return; }

        const float32 Value = _ValueSlider.GetValue();
        const FName Key = Get_SettingKey();
        if (ck::IsValid(FocusCorners))
        { FocusCorners.SetVisibility(ESlateVisibility::Collapsed); }
        _ValueSlider.SetSliderHandleColor(_Captured ? ThumbPressed :
            (_ValueSlider.IsHovered() || _ValueSlider.HasAnyUserFocus()) ? ThumbHovered : ThumbIdle);
        if (ck::IsValid(_ValueText) && Key.ToString().StartsWith("audio."))
        {
            const FText Label = FText::FromString(f"{Math::RoundToInt(Value * 100.0f)}%");
            if (!_ValueText.GetText().EqualTo(Label))
            { _ValueText.SetText(Label); }
        }
        else if (ck::IsValid(_ValueText) && Key == n"controls.look_sensitivity")
        {
            const FText Label = FText::FromString(f"{Value :.2}");
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
