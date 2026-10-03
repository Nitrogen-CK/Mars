// Base of the widgets that show an input action's key glyph (action hints, interact prompts).
UCLASS(Abstract)
class UMars_KeyGlyph_Widget : UCk_UserWidget_UE
{
    private bool _HasReportedMissingIcon = false;

    // Names the broken link once per widget when the key glyph cannot render: key resolution (profile / applied
    // contexts), brush lookup (CommonInput controller data for the current input type), or CommonUI collapsing the
    // action widget (e.g. Enhanced Input support off in CommonInputSettings).
    protected void Report_MissingIcon(UCk_InputActionWidget_UE InIcon, UInputAction InAction)
    {
        if (_HasReportedMissingIcon || ck::Is_NOT_Valid(InIcon))
        { return; }

        const auto Key = InIcon.Get_ResolvedKey();
        const auto Brush = UCk_Utils_KeyIcon_UE::Get_BrushForKey(GetOwningPlayer(), Key);
        const auto HasBrush = ck::IsValid(Brush.ResourceObject);
        const auto IconCollapsed = InIcon.GetVisibility() == ESlateVisibility::Collapsed;
        if (Key.IsValid() && HasBrush && IconCollapsed == false)
        { return; }

        _HasReportedMissingIcon = true;
        const FString KeyName = Key.IsValid() ? Key.ToString() : "Invalid";
        ck::Warning(f"[{GetClass().GetName()}] No key icon for [{InAction.GetName()}]: ResolvedKey=[{KeyName}] BrushFound=[{HasBrush}] IconCollapsed=[{IconCollapsed}]");
    }
}
