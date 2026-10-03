UCLASS(Abstract)
class UMars_ActionHint_Widget : UMars_KeyGlyph_Widget
{
    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock HintText;

    UPROPERTY(meta = (BindWidget))
    UCk_InputActionWidget_UE HintIcon;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock HoldLabel;

    void OnVisualUpdate(FMars_ActionHint_Spec InSpec)
    {
        auto InputAction = InSpec.InputAction.Get();
        if (ck::EnsureIfNot(ck::IsValid(InputAction), "[Mars_ActionHint] Hint has no resolvable InputAction"))
        { return; }

        if (ck::IsValid(HintText))
        { HintText.SetText(InSpec.Text); }

        if (ck::IsValid(HintIcon))
        { HintIcon.SetEnhancedInputAction(InputAction); }

        if (ck::IsValid(HoldLabel))
        {
            HoldLabel.SetText(InSpec.HoldLabel);
            HoldLabel.SetVisibility(InSpec.HoldLabel.IsEmpty() ? ESlateVisibility::Collapsed : ESlateVisibility::HitTestInvisible);
        }

        Report_MissingIcon(HintIcon, InputAction);
    }
}
