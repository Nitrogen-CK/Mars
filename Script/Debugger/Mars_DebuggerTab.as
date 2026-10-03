// Dockable editor tab: Tools > Mars Debug Tools, or Mars.Debugger.Toggle.
// Content lives on the GameInstance subsystem; outside PIE the tab shows a placeholder.

#if editor
class UMars_DebuggerEditorTab : UMMEditorUtilityTab
{
    default TabTitle = "[Mars] Game Debugger";
    default Category = "Mars Debug Tools";
    default Icon = n"ClassIcon.GameplayDebuggerCategoryReplicator";

    UFUNCTION(BlueprintOverride)
    void DrawTab(float DeltaTime)
    {
        auto Content = utils_mars_debugger::GetContent();
        if (ck::IsValid(Content))
        {
            Content.DrawDebugger(DeltaTime);
            return;
        }

        mm::HAlign_Fill();
        mm::VAlign_Fill();
        mm::BeginVerticalBox();

        mm::Slot_Fill();
        mm::HAlign_Center();
        mm::VAlign_Center();
        mm::WithinBorder(FLinearColor(0.15f, 0.15f, 0.15f), 4.0f);
        mm::Padding(20, 15);
        mm::BeginVerticalBox();

        mm::HAlign_Center();
        utils_mars_debugger::Text("Mars Game Debugger", FMars_Debugger_TextStyle(20, FLinearColor::White, EMars_Debugger_TextWeight::Bold));
        mm::Spacer(0, 10);
        mm::HAlign_Center();
        utils_mars_debugger::Text("Start Play-In-Editor to use the debugger.", FMars_Debugger_TextStyle(14, FLinearColor(0.6f, 0.6f, 0.6f)));

        mm::EndVerticalBox();
        mm::EndVerticalBox();
    }
}
#endif
