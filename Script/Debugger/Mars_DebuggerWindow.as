// Popup window shell (packaged / standalone, and the fallback when the editor tab is unavailable).
// Content is owned by UMars_DebuggerSubsystem; this only renders it.

event void FMars_DebuggerWindow_OnClosed();

class UMars_DebuggerWindow : UMMPopupWindow
{
    default WindowTitle = "Mars Game Debugger";
    default DefaultWindowSize = FVector2D(820, 620);

    private UMars_DebuggerContent Content;

    FMars_DebuggerWindow_OnClosed OnDebuggerClosed;

    void SetContent(UMars_DebuggerContent InContent)
    {
        Content = InContent;
    }

    UFUNCTION(BlueprintOverride)
    void OnWindowClosed()
    {
        Content = nullptr;
        OnDebuggerClosed.Broadcast();
    }

    UFUNCTION(BlueprintOverride)
    void DrawWindow(float DeltaTime)
    {
        if (ck::Is_NOT_Valid(Content))
        {
            utils_mars_debugger::Text("Debugger content unavailable", 14, FLinearColor::Red);
            return;
        }

        Content.DrawDebugger(DeltaTime);
    }
}
