//--------------------------------------------------------------------------------------------------------------------------
// Mars Game Debugger - EmmsUI immediate-mode debugger (ported from BusterBlock's).
//
// Open it with the console (Mars.Debugger.Toggle), the Mars_Debugger cheat, or F9 in gameplay.
// In the editor it docks as a tab (Tools > Mars Debug Tools); elsewhere it is a popup window.
// All page draws run inside the AUTHORITY world's scope, so a Request_* from a button reaches
// the server even when the tab was opened from a client PIE window.
//--------------------------------------------------------------------------------------------------------------------------

UFUNCTION()
void Mars_ToggleDebuggerFunc(const TArray<FString>& Args)
{
    utils_mars_debugger::Toggle();
}

UFUNCTION()
void Mars_OpenDebuggerFunc(const TArray<FString>& Args)
{
    utils_mars_debugger::Open();
}

UFUNCTION()
void Mars_CloseDebuggerFunc(const TArray<FString>& Args)
{
    utils_mars_debugger::Close();
}

const FConsoleCommand Mars_ToggleDebuggerCommand("Mars.Debugger.Toggle", n"Mars_ToggleDebuggerFunc");
const FConsoleCommand Mars_OpenDebuggerCommand("Mars.Debugger.Open", n"Mars_OpenDebuggerFunc");
const FConsoleCommand Mars_CloseDebuggerCommand("Mars.Debugger.Close", n"Mars_CloseDebuggerFunc");

namespace utils_mars_debugger
{
    const FName EditorTabId = n"Mars_DebuggerEditorTab";

    void Toggle()
    {
        if (IsOpen())
        {
            Close();
            return;
        }

        Open();
    }

    // Editor tab first; popup window in packaged/standalone.
    void Open()
    {
        if (UCk_Utils_EditorOnly_UE::TryInvokeEditorTab(EditorTabId))
        { return; }

        auto Subsystem = Subsystem::GetGameInstanceSubsystem(UMars_DebuggerSubsystem);
        if (ck::IsValid(Subsystem))
        { Subsystem.OpenPopupWindow(); }
    }

    void Close()
    {
        if (UCk_Utils_EditorOnly_UE::TryCloseEditorTab(EditorTabId))
        { return; }

        auto Subsystem = Subsystem::GetGameInstanceSubsystem(UMars_DebuggerSubsystem);
        if (ck::IsValid(Subsystem))
        { Subsystem.ClosePopupWindow(); }
    }

    bool IsOpen()
    {
        if (UCk_Utils_EditorOnly_UE::Get_IsEditorTabOpen(EditorTabId))
        { return true; }

        auto Subsystem = Subsystem::GetGameInstanceSubsystem(UMars_DebuggerSubsystem);
        return ck::IsValid(Subsystem) && Subsystem.IsPopupWindowOpen();
    }

    UMars_DebuggerContent GetContent()
    {
        auto EngineSubsystem = Subsystem::GetEngineSubsystem(UMars_DebuggerEngineSubsystem);
        if (ck::Is_NOT_Valid(EngineSubsystem))
        { return nullptr; }

        return EngineSubsystem.GetContent();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Engine subsystem - survives PIE so the editor tab can keep rendering, and tracks every live
// game world (listen server + each PIE client) so the debugger can find the authority one.
//--------------------------------------------------------------------------------------------------------------------------

class UMars_DebuggerEngineSubsystem : UScriptEngineSubsystem
{
    private UMars_DebuggerContent StoredContent;
    private TArray<UWorld> RegisteredWorlds;

    void SetContent(UMars_DebuggerContent InContent)
    {
        StoredContent = InContent;
    }

    UMars_DebuggerContent GetContent()
    {
        return StoredContent;
    }

    void ClearContent(UMars_DebuggerContent InContent)
    {
        if (StoredContent == InContent)
        { StoredContent = nullptr; }
    }

    void RegisterWorld(UWorld InWorld)
    {
        if (ck::IsValid(InWorld))
        { RegisteredWorlds.AddUnique(InWorld); }
    }

    void UnregisterWorld(UWorld InWorld)
    {
        RegisteredWorlds.Remove(InWorld);
    }

    // Decided live (scoped) rather than cached: a world's net mode may not be settled at registration.
    UWorld GetAuthorityWorld()
    {
        for (int32 Index = 0; Index < RegisteredWorlds.Num(); ++Index)
        {
            auto RegisteredWorld = RegisteredWorlds[Index];
            if (ck::Is_NOT_Valid(RegisteredWorld) || RegisteredWorld.IsGameWorld() == false)
            { continue; }

            const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(RegisteredWorld);
            if (System::IsServer())
            { return RegisteredWorld; }
        }
        return nullptr;
    }

    // Pure-client fallback (packaged client): inspection only.
    UWorld GetAnyGameWorld()
    {
        for (int32 Index = 0; Index < RegisteredWorlds.Num(); ++Index)
        {
            auto RegisteredWorld = RegisteredWorlds[Index];
            if (ck::IsValid(RegisteredWorld) && RegisteredWorld.IsGameWorld())
            { return RegisteredWorld; }
        }
        return nullptr;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// GameInstance subsystem - owns the content and the popup window.
//--------------------------------------------------------------------------------------------------------------------------

class UMars_DebuggerSubsystem : UScriptGameInstanceSubsystem
{
    private UMars_DebuggerContent Content;
    private UMars_DebuggerWindow PopupWindow;

    UFUNCTION(BlueprintOverride)
    bool ShouldCreateSubsystem(UObject InOuter) const
    {
        auto OuterWorld = InOuter.GetWorld();
        if (ck::Is_NOT_Valid(OuterWorld))
        { return false; }

        return OuterWorld.WorldType == EWorldType::Game || OuterWorld.WorldType == EWorldType::PIE;
    }

    UFUNCTION(BlueprintOverride)
    void Initialize()
    {
        Content = NewObject(this, UMars_DebuggerContent);
        Content.SetOwningSubsystem(this);
        Content.Initialize();

        auto EngineSubsystem = Subsystem::GetEngineSubsystem(UMars_DebuggerEngineSubsystem);
        if (ck::IsValid(EngineSubsystem))
        {
            EngineSubsystem.SetContent(Content);
            EngineSubsystem.RegisterWorld(GetWorld());
        }
    }

    UFUNCTION(BlueprintOverride)
    void Deinitialize()
    {
        ClosePopupWindow();

        auto EngineSubsystem = Subsystem::GetEngineSubsystem(UMars_DebuggerEngineSubsystem);
        if (ck::IsValid(EngineSubsystem))
        {
            EngineSubsystem.UnregisterWorld(GetWorld());
            EngineSubsystem.ClearContent(Content);
        }

        if (ck::IsValid(Content))
        {
            Content.Shutdown();
            Content = nullptr;
        }
    }

    bool IsPopupWindowOpen() const
    {
        return ck::IsValid(PopupWindow);
    }

    void OpenPopupWindow()
    {
        if (ck::IsValid(PopupWindow))
        { return; }

        PopupWindow = mm::SpawnPopupWindow(UMars_DebuggerWindow);
        PopupWindow.OnDebuggerClosed.AddUFunction(this, n"OnPopupWindowClosed");
        PopupWindow.SetContent(Content);
    }

    void ClosePopupWindow()
    {
        if (ck::Is_NOT_Valid(PopupWindow))
        { return; }

        PopupWindow.OnDebuggerClosed.UnbindObject(this);
        PopupWindow.CloseWindow();
        PopupWindow = nullptr;
    }

    UFUNCTION()
    private void OnPopupWindowClosed()
    {
        PopupWindow = nullptr;
    }
}
