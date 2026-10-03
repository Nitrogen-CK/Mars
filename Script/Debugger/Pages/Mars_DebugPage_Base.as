// Base class for debugger pages. Subclass, override GetPageName + DrawPage, and register the page in
// UMars_DebuggerContent::Initialize.
class UMars_DebugPage_Base : UObject
{
    private TMap<FString, bool> HoverStates;

    // Weak: the content outlives map travel, and a strong ref would keep the old world alive.
    private TWeakObjectPtr<APlayerController> SelectedPlayerController;

    FString GetPageName()
    {
        return "Base Page";
    }

    void PrepareForDraw(APlayerController InSelectedPlayerController)
    {
        SelectedPlayerController = InSelectedPlayerController;
    }

    void DrawPage(float DeltaTime)
    {
        utils_mars_debugger::Text("Override DrawPage() to implement page content", FMars_Debugger_TextStyle());
    }

    void OnPageActivated()
    {
        HoverStates.Empty();
    }

    void OnPageDeactivated() {}

    // The picked connection's server-side controller - use this, not GetPlayerController(0).
    protected APlayerController GetSelectedPlayerController() const
    {
        return SelectedPlayerController.Get();
    }

    protected FCk_Handle TryGet_PlayerEntity() const
    {
        auto PC = GetSelectedPlayerController();
        if (ck::Is_NOT_Valid(PC))
        { return FCk_Handle(); }

        auto Pawn = PC.ControlledPawn;
        if (ck::Is_NOT_Valid(Pawn))
        { return FCk_Handle(); }

        return Pawn.TryGet_ActorEntityHandle();
    }

    // "-" before the state machine has entered its first state.
    protected FString Get_StateClassName(TSubclassOf<UCk_SmState_EntityScript> InStateClass) const
    {
        if (ck::Is_NOT_Valid(InStateClass))
        { return "-"; }

        return InStateClass.Get().GetName().ToString();
    }

    //------------------------------------------------------------------------
    // Layout primitives
    //------------------------------------------------------------------------

    protected void DrawSectionHeading(const FString& InTitle)
    {
        mm::HAlign_Fill();
        mm::WithinBorder(FLinearColor(0.1f, 0.1f, 0.12f), 4.0f);
        mm::Padding(10, 4);
        utils_mars_debugger::Text(InTitle, FMars_Debugger_TextStyle(16, FLinearColor::White, EMars_Debugger_TextWeight::Bold));
        mm::Spacer(0, 4);
    }

    // Key left, value right-aligned.
    protected void DrawKvRow(const FString& InKey, const FString& InValue, const FLinearColor& InValueColor = FLinearColor::White)
    {
        mm::HAlign_Fill();
        mm::BeginHorizontalBox();

        mm::Slot_Auto();
        mm::VAlign_Center();
        utils_mars_debugger::Text(InKey, FMars_Debugger_TextStyle(13, FLinearColor(0.7f, 0.7f, 0.7f)));

        mm::Slot_Fill();
        mm::HAlign_Right();
        mm::VAlign_Center();
        utils_mars_debugger::Text(InValue, FMars_Debugger_TextStyle(13, InValueColor, EMars_Debugger_TextWeight::Bold));

        mm::EndHorizontalBox();
    }

    // Draws the button and returns true on the frame it was clicked.
    protected bool DrawButton_WasClicked(const FString& InButtonId, const FString& InLabel, const FLinearColor& InBaseColor = FLinearColor(0.15f, 0.3f, 0.5f))
    {
        const bool IsHovered = HoverStates.Contains(InButtonId) && HoverStates[InButtonId];
        const auto Color = IsHovered ? BrightenColor(InBaseColor) : InBaseColor;

        mm::Padding(2);
        auto Button = mm::WithinBorder(Color, 4.0f);
        mm::Padding(14, 6);
        utils_mars_debugger::Text(InLabel, FMars_Debugger_TextStyle(13, FLinearColor::White, EMars_Debugger_TextWeight::Bold));

        HoverStates.FindOrAdd(InButtonId) = Button.IsHovered();
        return Button.WasClicked();
    }

    protected void BeginPageScrollBox()
    {
        mm::Slot_Fill();
        mm::BeginScrollBox();
        mm::BeginVerticalBox();
    }

    protected void EndPageScrollBox()
    {
        mm::EndVerticalBox();
        mm::EndScrollBox();
    }

    protected void DrawWarningBox(const FString& InMessage)
    {
        mm::WithinBorder(FLinearColor(0.3f, 0.3f, 0.1f), 4.0f);
        mm::Padding(10, 5);
        mm::HAlign_Center();
        auto Style = FMars_Debugger_TextStyle();
        Style.Color = FLinearColor(1.0f, 1.0f, 0.5f);
        utils_mars_debugger::Text(InMessage, Style);
    }

    protected FLinearColor BrightenColor(const FLinearColor& InColor, float InAmount = 0.15f) const
    {
        return FLinearColor(
            Math::Min(InColor.R + InAmount, 1.0f),
            Math::Min(InColor.G + InAmount, 1.0f),
            Math::Min(InColor.B + InAmount, 1.0f),
            InColor.A);
    }

    protected FString BoolText(bool InValue) const
    {
        return InValue ? "yes" : "no";
    }
}
