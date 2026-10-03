// Shared debugger content: owns the pages, draws the header, page tabs, player picker and the
// active page. Created per GameInstance by UMars_DebuggerSubsystem; rendered by the popup
// window or the editor tab.
class UMars_DebuggerContent : UObject
{
    private TArray<UMars_DebugPage_Base> Pages;
    private int32 CurrentPageIndex = 0;
    private TMap<int32, bool> TabHoverStates;
    private TMap<int32, bool> PlayerTabHoverStates;
    private bool Initialized = false;

    // Index into the operating world's PlayerController list. Re-clamped every draw.
    private int32 SelectedPlayerIndex = 0;

    private bool _HadValidWorld = false;
    private UMars_DebuggerSubsystem _OwningSubsystem;

    void SetOwningSubsystem(UMars_DebuggerSubsystem InSubsystem)
    {
        _OwningSubsystem = InSubsystem;
    }

    void Initialize()
    {
        if (Initialized)
        { return; }

        Initialized = true;
        Pages.Add(NewObject(this, UMars_DebugPage_Player));
        Pages.Add(NewObject(this, UMars_DebugPage_Monsters));
        Pages.Add(NewObject(this, UMars_DebugPage_Interaction));
        ActivateCurrentPage();
    }

    void Shutdown()
    {
        if (Pages.IsValidIndex(CurrentPageIndex))
        { Pages[CurrentPageIndex].OnPageDeactivated(); }

        Pages.Empty();
        TabHoverStates.Empty();
        PlayerTabHoverStates.Empty();
        _HadValidWorld = false;
        Initialized = false;
    }

    // The authority (server/standalone) world, so every Request_* reaches the server. Falls back
    // to the local world on a pure client (inspection only).
    UWorld GetOperatingWorld() const
    {
        auto EngineSubsystem = Subsystem::GetEngineSubsystem(UMars_DebuggerEngineSubsystem);
        if (ck::IsValid(EngineSubsystem))
        {
            auto Authority = EngineSubsystem.GetAuthorityWorld();
            if (ck::IsValid(Authority))
            { return Authority; }

            auto AnyGame = EngineSubsystem.GetAnyGameWorld();
            if (ck::IsValid(AnyGame))
            { return AnyGame; }
        }

        if (ck::IsValid(_OwningSubsystem))
        {
            auto LiveWorld = _OwningSubsystem.GetWorld();
            if (ck::IsValid(LiveWorld) && LiveWorld.IsGameWorld())
            { return LiveWorld; }
        }

        return nullptr;
    }

    void DrawDebugger(float DeltaTime)
    {
        if (Pages.IsEmpty())
        { return; }

        auto OperatingWorld = GetOperatingWorld();
        const bool HasWorld = ck::IsValid(OperatingWorld) && OperatingWorld.IsGameWorld();

        if (_HadValidWorld == false && HasWorld)
        { ActivateCurrentPage(); }
        _HadValidWorld = HasWorld;

        mm::Slot_Fill();
        mm::HAlign_Fill();
        mm::VAlign_Fill();
        mm::BeginVerticalBox();

        DrawHeader();
        mm::Spacer(0, 8);
        DrawTabs();
        mm::Spacer(0, 8);

        if (HasWorld == false)
        {
            DrawPageContainer(DeltaTime, nullptr, false);
            mm::EndVerticalBox();
            return;
        }

        // Page draws + click handlers resolve Gameplay::* / authority against the operating world.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(OperatingWorld);
        const bool OperatingIsAuthority = System::IsServer();

        DrawPlayerPicker(OperatingIsAuthority);
        mm::Spacer(0, 8);
        DrawPageContainer(DeltaTime, OperatingWorld, true);

        mm::EndVerticalBox();
    }

    private void ActivateCurrentPage()
    {
        if (Pages.IsValidIndex(CurrentPageIndex) == false)
        { return; }

        auto OperatingWorld = GetOperatingWorld();
        if (ck::Is_NOT_Valid(OperatingWorld) || OperatingWorld.IsGameWorld() == false)
        { return; }

        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(OperatingWorld);
        Pages[CurrentPageIndex].PrepareForDraw(OperatingWorld, ResolveSelectedPlayerController());
        Pages[CurrentPageIndex].OnPageActivated();
    }

    private void DrawHeader()
    {
        mm::Slot_Auto();
        mm::WithinBorder(FLinearColor(0.1f, 0.1f, 0.1f), 0.0f);
        mm::Padding(10);
        mm::BeginHorizontalBox();

        mm::Slot_Fill();
        mm::VAlign_Center();
        utils_mars_debugger::Text("Mars Game Debugger", 20, FLinearColor::White, false, true);

        mm::EndHorizontalBox();
    }

    private void DrawTabs()
    {
        mm::Slot_Auto();
        mm::BeginHorizontalBox();

        for (int32 Index = 0; Index < Pages.Num(); ++Index)
        { DrawTab(Index); }

        mm::EndHorizontalBox();
    }

    private void DrawTab(int32 InTabIndex)
    {
        mm::Padding(2, 0);

        const bool IsActive = InTabIndex == CurrentPageIndex;
        const bool IsHovered = TabHoverStates.Contains(InTabIndex) && TabHoverStates[InTabIndex];

        mm::WithinBorder(GetTabColor(IsActive, IsHovered), 4.0f);
        mm::Padding(12, 8);

        auto TabButton = mm::WithinBorder(FLinearColor::Transparent);
        mm::Padding(0);
        utils_mars_debugger::Text(Pages[InTabIndex].GetPageName(), 14, FLinearColor::White, false, IsActive);

        TabHoverStates.FindOrAdd(InTabIndex) = TabButton.IsHovered();

        if (TabButton.WasClicked() && InTabIndex != CurrentPageIndex)
        { SwitchToPage(InTabIndex); }
    }

    private void DrawPageContainer(float DeltaTime, UWorld InOperatingWorld, bool HasWorld)
    {
        mm::Slot_Fill();
        mm::HAlign_Fill();
        mm::VAlign_Fill();
        mm::WithinBorder(FLinearColor(0.08f, 0.08f, 0.08f), 4.0f);
        mm::Padding(15);
        mm::HAlign_Fill();
        mm::VAlign_Fill();
        mm::BeginVerticalBox();

        if (HasWorld == false)
        {
            mm::Slot_Auto();
            utils_mars_debugger::Text("Not in-game. Debugger features are unavailable.", 16, FLinearColor::Red, false, true);
            mm::EndVerticalBox();
            return;
        }

        auto CurrentPage = Pages[CurrentPageIndex];
        CurrentPage.PrepareForDraw(InOperatingWorld, ResolveSelectedPlayerController());
        CurrentPage.DrawPage(DeltaTime);

        mm::EndVerticalBox();
    }

    // The selected PC is that connection's SERVER-side controller: mutations are
    // server-authoritative and replicate down to its owning client.
    private void DrawPlayerPicker(bool InOperatingIsAuthority)
    {
        auto PCs = EnumeratePlayerControllers();
        SelectedPlayerIndex = PCs.Num() == 0 ? 0 : Math::Clamp(SelectedPlayerIndex, 0, PCs.Num() - 1);

        mm::Slot_Auto();
        mm::WithinBorder(FLinearColor(0.07f, 0.07f, 0.09f), 4.0f);
        mm::Padding(8, 6);
        mm::BeginHorizontalBox();

        mm::Slot_Auto();
        mm::VAlign_Center();
        utils_mars_debugger::Text("Target player:", 13, FLinearColor(0.7f, 0.7f, 0.7f), false, true);
        mm::Spacer(8, 0);

        if (PCs.Num() == 0)
        {
            mm::Slot_Auto();
            mm::VAlign_Center();
            utils_mars_debugger::Text("(no players in world yet)", 12, FLinearColor(0.6f, 0.6f, 0.6f));
            mm::EndHorizontalBox();
            return;
        }

        for (int32 Index = 0; Index < PCs.Num(); ++Index)
        { DrawPlayerTab(Index, PCs[Index]); }

        mm::Slot_Fill();
        mm::HAlign_Right();
        mm::VAlign_Center();
        if (InOperatingIsAuthority)
        { utils_mars_debugger::Text("authority - mutations apply", 11, FLinearColor(0.5f, 0.9f, 0.5f)); }
        else
        { utils_mars_debugger::Text("no authority world - inspection only", 11, FLinearColor(1.0f, 0.8f, 0.4f)); }

        mm::EndHorizontalBox();
    }

    private void DrawPlayerTab(int32 InIndex, APlayerController InPC)
    {
        mm::Padding(2, 0);

        const bool IsActive = InIndex == SelectedPlayerIndex;
        const bool IsHovered = PlayerTabHoverStates.Contains(InIndex) && PlayerTabHoverStates[InIndex];

        mm::WithinBorder(GetTabColor(IsActive, IsHovered), 4.0f);
        mm::Padding(10, 5);

        auto TabButton = mm::WithinBorder(FLinearColor::Transparent);
        mm::Padding(0);
        const FString Label = InPC.IsLocalController() ? "Host" : f"Client {InIndex}";
        utils_mars_debugger::Text(Label, 12, FLinearColor::White, false, IsActive);

        PlayerTabHoverStates.FindOrAdd(InIndex) = TabButton.IsHovered();

        if (TabButton.WasClicked())
        { SelectedPlayerIndex = InIndex; }
    }

    // Must be called within the operating-world scope.
    private TArray<APlayerController> EnumeratePlayerControllers() const
    {
        TArray<APlayerController> Result;
        for (int32 Index = 0; Index < 8; ++Index)
        {
            auto PC = Gameplay::GetPlayerController(Index);
            if (ck::Is_NOT_Valid(PC))
            { break; }
            Result.Add(PC);
        }
        return Result;
    }

    // Must be called within the operating-world scope.
    private APlayerController ResolveSelectedPlayerController() const
    {
        auto PC = Gameplay::GetPlayerController(SelectedPlayerIndex);
        if (ck::IsValid(PC))
        { return PC; }
        return Gameplay::GetPlayerController(0);
    }

    private FLinearColor GetTabColor(bool InIsActive, bool InIsHovered) const
    {
        if (InIsActive)
        { return InIsHovered ? FLinearColor(0.2f, 0.45f, 0.7f) : FLinearColor(0.15f, 0.35f, 0.6f); }

        return InIsHovered ? FLinearColor(0.2f, 0.2f, 0.25f) : FLinearColor(0.1f, 0.1f, 0.1f);
    }

    private void SwitchToPage(int32 InNewPageIndex)
    {
        if (Pages.IsValidIndex(CurrentPageIndex))
        { Pages[CurrentPageIndex].OnPageDeactivated(); }

        CurrentPageIndex = InNewPageIndex;
        ActivateCurrentPage();
    }
}
