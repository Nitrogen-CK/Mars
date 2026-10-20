// The mortar station's meter on the HUD: the batch's progress, and under it the timing bar. Shown only while the HUD's
// player operates a station that carries a Mortar; it reads the kernel every frame (the timing window moves every frame)
// and writes nothing to it.
//
//   Crush   the green Window pans along the bar and the Marker stands where a strike is judged: press as the green
//           crosses the marker.
//   Grind   the bar fills from the left while the pestle is held down; no marker.
//   Done    the bar is full.
//
// Window and Marker are children of a canvas panel (the bar) and are placed by their anchors alone, in bar lengths, so the
// layout holds at any size; the WBP gives them zero offsets.
//
// A one-off: the shared gameplay HUD binds this mortar meter directly. A second station with an operator meter should not
// follow it; give the station's assembly an operator HUD widget class instead.
UCLASS(Abstract)
class UMars_MortarMeter_Widget : UCk_UserWidget_UE
{
    // Everything drawn. Collapsed while there is no mortar to show: the widget itself stays visible so it keeps ticking.
    UPROPERTY(meta = (BindWidget))
    UWidget Body;

    UPROPERTY(meta = (BindWidget))
    UProgressBar Progress;

    UPROPERTY(meta = (BindWidget))
    UWidget Window;

    UPROPERTY(meta = (BindWidget))
    UWidget Marker;

    UPROPERTY(meta = (BindWidget))
    UTextBlock Prompt;

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Mortar")
    FText CrushPrompt = NSLOCTEXT("MarsMortar", "CrushPrompt", "Crush: click on the green");

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Mortar")
    FText GrindPrompt = NSLOCTEXT("MarsMortar", "GrindPrompt", "Grind: hold");

    UPROPERTY(EditDefaultsOnly, Category = "Mars|Mortar")
    FText DonePrompt = NSLOCTEXT("MarsMortar", "DonePrompt", "Ground");

    // The marker's half width, in bar lengths.
    private const float32 k_MarkerHalfWidth = 0.004f;

    private FCk_Handle_Operator _Operator;
    private bool _IsShown = false;
    // The phase the prompt was last written for; unset until written.
    private TOptional<EMars_Mortar_Phase> _PromptPhase;

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        _IsShown = false;
        _PromptPhase.Reset();
        Body.SetVisibility(ESlateVisibility::Collapsed);
    }

    UFUNCTION(BlueprintOverride)
    void OnValidContextInjected(FCk_Handle InContextEntity)
    {
        _Operator = InContextEntity.As_Operator(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION(BlueprintOverride)
    void OnContextCleared()
    {
        _Operator = FCk_Handle_Operator();
        Set_Shown(false);
    }

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        const auto Mortar = TryGet_Mortar();
        if (ck::Is_NOT_Valid(Mortar))
        {
            Set_Shown(false);
            return;
        }

        Set_Shown(true);
        Progress.SetPercent(Mortar.Get_Progress());

        const auto Batch = Mortar.Get_Batch();
        if (Batch.Phase == EMars_Mortar_Phase::Crush)
        {
            const auto Bar = Mortar.Get_Window();
            Place_OnBar(Window, Bar.Centre - Bar.HalfWidth, Bar.Centre + Bar.HalfWidth);
            Place_OnBar(Marker, Bar.Marker - k_MarkerHalfWidth, Bar.Marker + k_MarkerHalfWidth);
            Marker.SetVisibility(ESlateVisibility::HitTestInvisible);
        }
        else
        {
            Place_OnBar(Window, 0.0f, Batch.Phase == EMars_Mortar_Phase::Done ? 1.0f : Batch.GrindProgress);
            Marker.SetVisibility(ESlateVisibility::Collapsed);
        }

        if (_PromptPhase.IsSet() && _PromptPhase.GetValue() == Batch.Phase)
        { return; }

        _PromptPhase = Batch.Phase;
        Prompt.SetText(Get_PromptText(Batch.Phase));
    }

    // The mortar of the station the HUD's player operates and is working; invalid otherwise.
    private FCk_Handle_Mortar TryGet_Mortar() const
    {
        if (ck::Is_NOT_Valid(_Operator))
        { return FCk_Handle_Mortar(); }

        FCk_Handle Station = _Operator.Get_Station();
        if (ck::Is_NOT_Valid(Station))
        { return FCk_Handle_Mortar(); }

        const auto Mortar = Station.As_Mortar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Mortar) || Mortar.Get_IsEngaged() == false)
        { return FCk_Handle_Mortar(); }

        return Mortar;
    }

    private void Set_Shown(bool InShown)
    {
        if (InShown == _IsShown)
        { return; }

        _IsShown = InShown;
        _PromptPhase.Reset();
        Body.SetVisibility(InShown ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed);
    }

    // InWidget spans the bar from InLeft to InRight (bar lengths, clamped to the bar) and its full height.
    private void Place_OnBar(UWidget InWidget, float32 InLeft, float32 InRight)
    {
        auto BarSlot = Cast<UCanvasPanelSlot>(InWidget.Slot);
        if (ck::EnsureIfNot(ck::IsValid(BarSlot), "[Mars_MortarMeter] Window/Marker must be children of a canvas panel"))
        { return; }

        auto Anchors = FAnchors();
        Anchors.Minimum = FVector2D(Math::Clamp(InLeft, 0.0f, 1.0f), 0.0);
        Anchors.Maximum = FVector2D(Math::Clamp(InRight, 0.0f, 1.0f), 1.0);
        BarSlot.SetAnchors(Anchors);
    }

    private FText Get_PromptText(EMars_Mortar_Phase InPhase) const
    {
        if (InPhase == EMars_Mortar_Phase::Crush)
        { return CrushPrompt; }

        if (InPhase == EMars_Mortar_Phase::Grind)
        { return GrindPrompt; }

        return DonePrompt;
    }
}
