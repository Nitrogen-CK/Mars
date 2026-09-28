// Base class for debugger pages. Subclass, override GetPageName + DrawPage, and register the
// page in UMars_DebuggerContent::Initialize.
class UMars_DebugPage_Base : UObject
{
    private TMap<FString, bool> HoverStates;
    private UWorld CachedWorld;
    private APlayerController SelectedPlayerController;

    FString GetPageName()
    {
        return "Base Page";
    }

    void PrepareForDraw(UWorld InWorld, APlayerController InSelectedPlayerController)
    {
        CachedWorld = InWorld;
        SelectedPlayerController = InSelectedPlayerController;
    }

    void DrawPage(float DeltaTime)
    {
        utils_mars_debugger::Text("Override DrawPage() to implement page content");
    }

    void OnPageActivated()
    {
        HoverStates.Empty();
    }

    void OnPageDeactivated() {}

    protected UWorld GetDebugWorld() const
    {
        return CachedWorld;
    }

    // The picked connection's server-side controller - use this, not GetPlayerController(0).
    protected APlayerController GetSelectedPlayerController() const
    {
        return SelectedPlayerController;
    }

    protected FCk_Handle TryGet_PlayerEntity() const
    {
        if (ck::Is_NOT_Valid(CachedWorld) || ck::Is_NOT_Valid(SelectedPlayerController))
        { return FCk_Handle(); }

        auto Pawn = SelectedPlayerController.ControlledPawn;
        if (ck::Is_NOT_Valid(Pawn))
        { return FCk_Handle(); }

        return Pawn.TryGet_ActorEntityHandle();
    }

    //------------------------------------------------------------------------
    // Layout primitives
    //------------------------------------------------------------------------

    protected void DrawSectionHeading(const FString& InTitle)
    {
        mm::HAlign_Fill();
        mm::WithinBorder(FLinearColor(0.1f, 0.1f, 0.12f), 4.0f);
        mm::Padding(10, 4);
        utils_mars_debugger::Text(InTitle, 16, FLinearColor::White, false, true);
        mm::Spacer(0, 4);
    }

    // Key left, value right-aligned.
    protected void DrawKvRow(const FString& InKey, const FString& InValue, const FLinearColor& InValueColor = FLinearColor::White)
    {
        mm::HAlign_Fill();
        mm::BeginHorizontalBox();

        mm::Slot_Auto();
        mm::VAlign_Center();
        utils_mars_debugger::Text(InKey, 13, FLinearColor(0.7f, 0.7f, 0.7f));

        mm::Slot_Fill();
        mm::HAlign_Right();
        mm::VAlign_Center();
        utils_mars_debugger::Text(InValue, 13, InValueColor, false, true);

        mm::EndHorizontalBox();
    }

    // Returns true on the frame the button was clicked.
    protected bool DrawButton(const FString& InButtonId, const FString& InLabel, const FLinearColor& InBaseColor = FLinearColor(0.15f, 0.3f, 0.5f))
    {
        const bool IsHovered = HoverStates.Contains(InButtonId) && HoverStates[InButtonId];
        const auto Color = IsHovered ? BrightenColor(InBaseColor) : InBaseColor;

        mm::Padding(2);
        auto Button = mm::WithinBorder(Color, 4.0f);
        mm::Padding(14, 6);
        utils_mars_debugger::Text(InLabel, 13, FLinearColor::White, false, true);

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
        utils_mars_debugger::Text(InMessage, 0, FLinearColor(1.0f, 1.0f, 0.5f));
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
