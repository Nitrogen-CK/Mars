// Base of the widgets that show an input action's key glyph (action hints, interact prompts).
UCLASS(Abstract)
class UMars_KeyGlyph_Widget : UCk_UserWidget_UE
{
    private bool _HasReportedMissingIcon = false;

    // Names the broken link once per widget when the key glyph cannot render: key resolution (profile / applied
    // contexts) or brush lookup (CommonInput controller data for the current input type). CommonUI collapsing its own
    // action widget is not a missing glyph: the brush renders through this widget regardless, so it is only reported.
    protected void Report_MissingIcon(UCk_InputActionWidget_UE InIcon, UInputAction InAction)
    {
        if (_HasReportedMissingIcon || ck::Is_NOT_Valid(InIcon))
        { return; }

        const auto Key = InIcon.Get_ResolvedKey();
        const auto Brush = UCk_Utils_KeyIcon_UE::Get_BrushForKey(GetOwningPlayer(), Key);
        const auto HasBrush = ck::IsValid(Brush.ResourceObject);
        const auto IconCollapsed = InIcon.GetVisibility() == ESlateVisibility::Collapsed;
        if (Key.IsValid() && HasBrush)
        { return; }

        _HasReportedMissingIcon = true;
        // No key resolved at all: the profile or the applied contexts are wrong for this action, a wiring defect.
        if (ck::EnsureIfNot(Key.IsValid(), f"[{GetClass().GetName()}] No key resolved for [{InAction.GetName()}]: IconCollapsed=[{IconCollapsed}]"))
        { return; }

        // A key with no glyph art is a content gap, not a defect: an axis (Mouse2D, a stick) has no glyph by design, and a
        // button's missing art is the artist's. Said once per widget.
        ck::Trace(f"[{GetClass().GetName()}] No key icon for [{InAction.GetName()}]: ResolvedKey=[{Key.ToString()}] BrushFound=[{HasBrush}] IconCollapsed=[{IconCollapsed}]");
    }
}
