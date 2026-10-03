//--------------------------------------------------------------------------------------------------------------------------
// Mars Game Debugger - EmmsUI immediate-mode debugger.
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

    // Editor tab first; popup window in packaged/standalone, where every game world has the GameInstance subsystem.
    void Open()
    {
        if (UCk_Utils_EditorOnly_UE::TryInvokeEditorTab(EditorTabId))
        { return; }

        auto Subsystem = Subsystem::GetGameInstanceSubsystem(UMars_DebuggerSubsystem);
        if (ck::EnsureIfNot(ck::IsValid(Subsystem), "[Mars.Debugger] no editor tab and no UMars_DebuggerSubsystem to open the popup from"))
        { return; }

        Subsystem.OpenPopupWindow();
    }

    void Close()
    {
        if (UCk_Utils_EditorOnly_UE::TryCloseEditorTab(EditorTabId))
        { return; }

        // Outside a game world there is no subsystem, and so no popup to close.
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
        if (ck::EnsureIfNot(ck::IsValid(EngineSubsystem), "[Mars.Debugger] the UMars_DebuggerEngineSubsystem is missing"))
        { return nullptr; }

        return EngineSubsystem.GetContent();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Engine subsystem - survives PIE so the editor tab can keep rendering, and tracks every live
// game instance (listen server + each PIE client) so the debugger can find the authority world.
//--------------------------------------------------------------------------------------------------------------------------

class UMars_DebuggerEngineSubsystem : UScriptEngineSubsystem
{
    private UMars_DebuggerContent StoredContent;

    // The GameInstance subsystems, not their worlds: a world is resolved live through its subsystem, so no reference
    // outlives a map travel. Each subsystem unregisters itself in Deinitialize.
    private TArray<UMars_DebuggerSubsystem> RegisteredSubsystems;

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

    void RegisterSubsystem(UMars_DebuggerSubsystem InSubsystem)
    {
        RegisteredSubsystems.AddUnique(InSubsystem);
    }

    void UnregisterSubsystem(UMars_DebuggerSubsystem InSubsystem)
    {
        RegisteredSubsystems.Remove(InSubsystem);
    }

    // Decided live (scoped) rather than cached: a world's net mode may not be settled at registration.
    UWorld GetAuthorityWorld()
    {
        for (auto RegisteredSubsystem : RegisteredSubsystems)
        {
            auto World = Get_GameWorld(RegisteredSubsystem);
            if (ck::Is_NOT_Valid(World))
            { continue; }

            const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(World);
            if (System::IsServer())
            { return World; }
        }

        return nullptr;
    }

    // Pure-client fallback (packaged client): inspection only.
    UWorld GetAnyGameWorld()
    {
        for (auto RegisteredSubsystem : RegisteredSubsystems)
        {
            auto World = Get_GameWorld(RegisteredSubsystem);
            if (ck::IsValid(World))
            { return World; }
        }

        return nullptr;
    }

    // The subsystem's current world when it is a game world, else null.
    private UWorld Get_GameWorld(UMars_DebuggerSubsystem InSubsystem) const
    {
        if (ck::Is_NOT_Valid(InSubsystem))
        { return nullptr; }

        auto World = InSubsystem.GetWorld();
        if (ck::Is_NOT_Valid(World) || World.IsGameWorld() == false)
        { return nullptr; }

        return World;
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
        if (ck::EnsureIfNot(ck::IsValid(EngineSubsystem), "[Mars.Debugger] the UMars_DebuggerEngineSubsystem is missing"))
        { return; }

        EngineSubsystem.SetContent(Content);
        EngineSubsystem.RegisterSubsystem(this);
    }

    UFUNCTION(BlueprintOverride)
    void Deinitialize()
    {
        ClosePopupWindow();

        // Engine shutdown may already have torn the engine subsystem down.
        auto EngineSubsystem = Subsystem::GetEngineSubsystem(UMars_DebuggerEngineSubsystem);
        if (ck::IsValid(EngineSubsystem))
        {
            EngineSubsystem.UnregisterSubsystem(this);
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
