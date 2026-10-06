// The native row owns the typed value, capture and the readout; this subclass owns the filled track, the thumb tint
// and the focus corners.
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

    private bool _Captured = false;
    private bool _InFocusPath = false;

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
    {
        _Captured = false;
        _InFocusPath = false;
        RefreshFocusCorners();
    }

    UFUNCTION(BlueprintOverride)
    void Destruct()
    {
        _Captured = false;
        _InFocusPath = false;
    }

    UFUNCTION(BlueprintOverride)
    void OnAddedToFocusPath(FFocusEvent InFocusEvent)
    {
        _InFocusPath = true;
        RefreshFocusCorners();
    }

    UFUNCTION(BlueprintOverride)
    void OnRemovedFromFocusPath(FFocusEvent InFocusEvent)
    {
        _InFocusPath = false;
        RefreshFocusCorners();
    }

    UFUNCTION()
    private void OnCaptureStarted()
    { _Captured = true; }

    UFUNCTION()
    private void OnCaptureStopped()
    { _Captured = false; }

    private void RefreshFocusCorners()
    {
        if (ck::Is_NOT_Valid(FocusCorners))
        { return; }

        FocusCorners.SetVisibility(_InFocusPath
            ? ESlateVisibility::HitTestInvisible
            : ESlateVisibility::Collapsed);
    }

    // Hover has no slider event and the fill follows the laid-out geometry, so both stay per-frame.
    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        if (ck::Is_NOT_Valid(_ValueSlider))
        { return; }

        _ValueSlider.SetSliderHandleColor(_Captured ? constants_ui_colors::k_MossDeep :
            (_ValueSlider.IsHovered() || _InFocusPath) ? constants_ui_colors::k_Moss : ThumbIdle);

        if (ck::IsValid(FillSize))
        {
            // IndentHandle=false: the thumb centre travels from half a thumb to width minus half a thumb.
            const float32 Width = Math::Max(0.0f, float32(_ValueSlider.GetCachedGeometry().GetLocalSize().X) - ThumbSize);
            const float32 Fraction = _ValueSlider.GetNormalizedValue();
            FillSize.SetWidthOverride(Width * Fraction);
            FillSize.SetVisibility(Fraction > 0.0f ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Hidden);
        }
    }
}
