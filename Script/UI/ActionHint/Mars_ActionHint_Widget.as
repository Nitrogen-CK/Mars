UCLASS(Abstract)
class UMars_ActionHint_Widget : UCk_UserWidget_UE
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

        Report_MissingIcon(InputAction);
    }

    // Names the broken link once per widget when the key glyph cannot render: key resolution (profile / applied
    // contexts), brush lookup (CommonInput controller data for the current input type), or CommonUI collapsing the
    // action widget (e.g. Enhanced Input support off in CommonInputSettings).
    private bool _HasReportedMissingIcon = false;

    private void Report_MissingIcon(UInputAction InAction)
    {
        if (_HasReportedMissingIcon || ck::Is_NOT_Valid(HintIcon))
        { return; }

        const auto Key = HintIcon.Get_ResolvedKey();
        const auto Brush = UCk_Utils_KeyIcon_UE::Get_BrushForKey(GetOwningPlayer(), Key);
        const auto HasBrush = ck::IsValid(Brush.ResourceObject);
        const auto IconCollapsed = HintIcon.GetVisibility() == ESlateVisibility::Collapsed;
        if (Key.IsValid() && HasBrush && IconCollapsed == false)
        { return; }

        _HasReportedMissingIcon = true;
        const FString KeyName = Key.IsValid() ? Key.ToString() : "Invalid";
        ck::Warning(f"[Mars_ActionHint] No key icon for [{InAction.GetName()}]: ResolvedKey=[{KeyName}] BrushFound=[{HasBrush}] IconCollapsed=[{IconCollapsed}]");
    }
}
