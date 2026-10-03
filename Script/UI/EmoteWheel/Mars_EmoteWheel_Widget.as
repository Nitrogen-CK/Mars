// The emote wheel. Data-driven: one segment widget per entry of the player's EmoteWheel feature, placed on its sector's
// centre line, and the Disk material draws as many sectors as there are entries - so adding an entry to the Definition
// asset needs no layout change. On screen only while the wheel is open; every state change arrives as a feature signal.
//
// Layout units are the wheel's own design space (the WBP's square wheel frame), centre = (0, 0), Y down.
UCLASS(Abstract)
class UMars_EmoteWheel_Widget : UCk_UserWidget_UE
{
    // Paper disk + sector dividers + hovered-sector fill (EmoteWheelDisk_Mars_M).
    UPROPERTY(meta = (BindWidget))
    UImage Disk;

    // Fills the wheel frame; segments are anchored at its centre.
    UPROPERTY(meta = (BindWidget))
    UCanvasPanel SegmentCanvas;

    // Centred in the frame; moved onto the hovered sector and turned to point along it.
    UPROPERTY(meta = (BindWidgetOptional))
    UWidget Selector;

    // The centre cancel button's content (the X and its caption); dimmed while a sector is hovered.
    UPROPERTY(meta = (BindWidgetOptional))
    UWidget CenterCancel;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock HoveredName;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock Instruction;

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel")
    TSubclassOf<UMars_EmoteWheelSegment_Widget> SegmentWidgetClass;

    // Design-time only: the entries the designer preview lays out (the game reads the player's feature).
    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Preview")
    TSoftObjectPtr<UMars_EmoteWheel_Definition> PreviewDefinition;

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Preview")
    int32 PreviewHoveredIndex = 0;

    // Icon centres.
    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Layout")
    float32 SegmentRadius = 136.0f;

    // Label centres - their own ring, outside the icons, so neighbouring sectors never collide.
    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Layout")
    float32 LabelRadius = 212.0f;

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Layout")
    float32 SelectorRadius = 78.0f;

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Style")
    float32 CenterIdleOpacity = 0.7f;

    // Until players pick a colour: the kit's reference red.
    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Style")
    FLinearColor PlayerTint = FLinearColor(0.5841f, 0.0704f, 0.0369f, 1.0f);

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Style")
    FLinearColor HoveredColor = FLinearColor(0.8148f, 0.4125f, 0.0561f, 1.0f);

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Style")
    FLinearColor DisabledHoveredColor = FLinearColor(0.3968f, 0.3231f, 0.2384f, 1.0f);

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Text")
    FText CancelName = NSLOCTEXT("MarsEmoteWheel", "CancelName", "Cancel");

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Text")
    FText PerformInstruction = NSLOCTEXT("MarsEmoteWheel", "PerformInstruction", "Release to perform");

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Text")
    FText CancelInstruction = NSLOCTEXT("MarsEmoteWheel", "CancelInstruction", "Release to cancel");

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Text")
    FText UnavailableInstruction = NSLOCTEXT("MarsEmoteWheel", "UnavailableInstruction", "Not available yet");

    // Sound hooks - unset plays nothing.
    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Audio")
    USoundBase OpenSound;

    // Played on entering an emote sector (not the centre).
    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Audio")
    USoundBase HoverSound;

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Audio")
    USoundBase SelectSound;

    // Played when the wheel closes without a choice.
    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Audio")
    USoundBase CancelSound;

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Material")
    FName SectorCountParameter = n"SectorCount";

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Material")
    FName HoveredIndexParameter = n"HoveredIndex";

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Material")
    FName HoveredColorParameter = n"HoveredColor";

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Material")
    FName DeadZoneParameter = n"DeadZone";

    private FCk_Handle_EmoteWheel _Wheel;
    private TArray<FMars_EmoteWheel_Entry> _Entries;
    private TArray<UMars_EmoteWheelSegment_Widget> _Segments;
    private UMaterialInstanceDynamic _DiskDMI;
    // Unset while the centre (cancel) is hovered.
    private TOptional<int32> _HoveredIndex;
    // Set by OnEmoteChosen, which fires right before OnClosed.
    private bool _ChoseOnClose = false;

    UFUNCTION(BlueprintOverride)
    void PreConstruct(bool bIsDesignTime)
    {
        if (bIsDesignTime == false || PreviewDefinition.IsNull())
        { return; }

        auto Definition = System::LoadAsset_Blocking(PreviewDefinition);
        if (ck::Is_NOT_Valid(Definition))
        { return; }

        Build(Definition.Entries, FMars_EmoteWheel_Spec().DeadZoneRatio);
        Show_Hovered(TOptional<int32>(PreviewHoveredIndex));
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        Clear();
        SetVisibility(ESlateVisibility::Collapsed);
    }

    UFUNCTION(BlueprintOverride)
    void OnValidContextInjected(FCk_Handle InContextEntity)
    {
        _Wheel = InContextEntity.As_EmoteWheel(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Wheel))
        { return; }

        Build(_Wheel.Get_Entries(), _Wheel.Get_DeadZoneRatio());

        _Wheel.BindTo_OnOpened(FMars_Delegate_EmoteWheel_OnOpened(this, n"OnOpened"));
        _Wheel.BindTo_OnClosed(FMars_Delegate_EmoteWheel_OnClosed(this, n"OnClosed"));
        _Wheel.BindTo_OnHoveredChanged(FMars_Delegate_EmoteWheel_OnHoveredChanged(this, n"OnHoveredChanged"));
        _Wheel.BindTo_OnEmoteChosen(FMars_Delegate_EmoteWheel_OnEmoteChosen(this, n"OnEmoteChosen"));

        // The signals are edge-only; converge on what the wheel already shows.
        Show_Hovered(_Wheel.Get_HoveredIndex());
        SetVisibility(_Wheel.Get_IsOpen() ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed);
    }

    UFUNCTION(BlueprintOverride)
    void OnContextCleared()
    {
        if (ck::IsValid(_Wheel))
        {
            _Wheel.UnbindFrom_OnOpened(FMars_Delegate_EmoteWheel_OnOpened(this, n"OnOpened"));
            _Wheel.UnbindFrom_OnClosed(FMars_Delegate_EmoteWheel_OnClosed(this, n"OnClosed"));
            _Wheel.UnbindFrom_OnHoveredChanged(FMars_Delegate_EmoteWheel_OnHoveredChanged(this, n"OnHoveredChanged"));
            _Wheel.UnbindFrom_OnEmoteChosen(FMars_Delegate_EmoteWheel_OnEmoteChosen(this, n"OnEmoteChosen"));
        }

        _Wheel = FCk_Handle_EmoteWheel();
        Clear();
        SetVisibility(ESlateVisibility::Collapsed);
    }

    UFUNCTION()
    private void OnOpened(FCk_Handle_EmoteWheel InWheel)
    {
        _ChoseOnClose = false;
        Show_Hovered(TOptional<int32>());
        SetVisibility(ESlateVisibility::HitTestInvisible);
        PlayUISound(OpenSound);
    }

    UFUNCTION()
    private void OnClosed(FCk_Handle_EmoteWheel InWheel)
    {
        SetVisibility(ESlateVisibility::Collapsed);

        if (_ChoseOnClose == false)
        { PlayUISound(CancelSound); }

        _ChoseOnClose = false;
    }

    UFUNCTION()
    private void OnHoveredChanged(FCk_Handle_EmoteWheel InWheel)
    {
        const auto Hovered = InWheel.Get_HoveredIndex();
        Show_Hovered(Hovered);

        if (Hovered.IsSet())
        { PlayUISound(HoverSound); }
    }

    UFUNCTION()
    private void OnEmoteChosen(FCk_Handle_EmoteWheel InWheel, int32 InIndex, FGameplayTag InEmote)
    {
        _ChoseOnClose = true;
        PlayUISound(SelectSound);
    }

    // One segment per entry on its sector's centre line; the disk draws the same sector count.
    private void Build(const TArray<FMars_EmoteWheel_Entry>& InEntries, float32 InDeadZoneRatio)
    {
        Clear();
        _Entries = InEntries;

        _DiskDMI = Disk.GetDynamicMaterial();
        ck::EnsureIfNot(ck::IsValid(_DiskDMI),
            "[Mars_EmoteWheel] the Disk brush is not a material; set it to EmoteWheelDisk_Mars_M in the widget blueprint");
        if (ck::IsValid(_DiskDMI))
        {
            _DiskDMI.SetScalarParameterValue(SectorCountParameter, float32(_Entries.Num()));
            _DiskDMI.SetScalarParameterValue(DeadZoneParameter, InDeadZoneRatio);
        }

        if (ck::EnsureIfNot(SegmentWidgetClass != nullptr, "[Mars_EmoteWheel] SegmentWidgetClass is not set on the widget blueprint"))
        { return; }

        auto Anchors = FAnchors();
        Anchors.Minimum = FVector2D(0.5, 0.5);
        Anchors.Maximum = FVector2D(0.5, 0.5);

        for (int32 Index = 0; Index < _Entries.Num(); ++Index)
        {
            auto Segment = Cast<UMars_EmoteWheelSegment_Widget>(WidgetBlueprint::CreateWidget(SegmentWidgetClass, GetOwningPlayer()));
            if (ck::EnsureIfNot(ck::IsValid(Segment), f"[Mars_EmoteWheel] Could not create the widget for segment [{Index}]"))
            { continue; }

            Segment.Setup(_Entries[Index], PlayerTint);
            Segment.Set_LabelOffset(utils_emote_wheel::Get_SectorPoint(Index, _Entries.Num(), LabelRadius - SegmentRadius));

            auto CanvasSlot = SegmentCanvas.AddChildToCanvas(Segment);
            CanvasSlot.SetAnchors(Anchors);
            CanvasSlot.SetAlignment(FVector2D(0.5, 0.5));
            CanvasSlot.SetAutoSize(true);
            CanvasSlot.SetPosition(utils_emote_wheel::Get_SectorPoint(Index, _Entries.Num(), SegmentRadius));

            _Segments.Add(Segment);
        }
    }

    private void Clear()
    {
        if (ck::IsValid(SegmentCanvas))
        { SegmentCanvas.ClearChildren(); }

        _Segments.Empty();
        _Entries.Empty();
        _HoveredIndex.Reset();
    }

    // An unset or out-of-range index hovers the centre (cancel).
    private void Show_Hovered(TOptional<int32> InIndex)
    {
        if (_HoveredIndex.IsSet() && _Segments.IsValidIndex(_HoveredIndex.GetValue()))
        { _Segments[_HoveredIndex.GetValue()].Set_Hovered(false); }

        _HoveredIndex.Reset();
        if (InIndex.IsSet() && _Entries.IsValidIndex(InIndex.GetValue()))
        { _HoveredIndex = InIndex; }

        const auto IsHovering = _HoveredIndex.IsSet();
        const auto IsHoveredEnabled = IsHovering && _Entries[_HoveredIndex.GetValue()].IsEnabled;

        if (IsHovering && _Segments.IsValidIndex(_HoveredIndex.GetValue()))
        { _Segments[_HoveredIndex.GetValue()].Set_Hovered(true); }

        if (ck::IsValid(_DiskDMI))
        {
            // The Disk material reads -1 as no hovered sector.
            _DiskDMI.SetScalarParameterValue(HoveredIndexParameter, float32(_HoveredIndex.Get(-1)));
            _DiskDMI.SetVectorParameterValue(HoveredColorParameter, IsHoveredEnabled || IsHovering == false ? HoveredColor : DisabledHoveredColor);
        }

        if (ck::IsValid(Selector))
        {
            Selector.SetVisibility(IsHovering ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Hidden);
            if (IsHovering)
            {
                Selector.SetRenderTranslation(utils_emote_wheel::Get_SectorPoint(_HoveredIndex.GetValue(), _Entries.Num(), SelectorRadius));
                Selector.SetRenderTransformAngle(utils_emote_wheel::Get_SectorAngleDegrees(_HoveredIndex.GetValue(), _Entries.Num()));
            }
        }

        if (ck::IsValid(CenterCancel))
        { CenterCancel.SetRenderOpacity(IsHovering ? CenterIdleOpacity : 1.0f); }

        if (ck::IsValid(HoveredName))
        { HoveredName.SetText(IsHovering ? _Entries[_HoveredIndex.GetValue()].DisplayName : CancelName); }

        if (ck::IsValid(Instruction))
        {
            if (IsHovering == false)
            { Instruction.SetText(CancelInstruction); }
            else if (IsHoveredEnabled)
            { Instruction.SetText(PerformInstruction); }
            else
            { Instruction.SetText(UnavailableInstruction); }
        }
    }

    // Non-spatialised, on the owning player's world.
    private void PlayUISound(USoundBase InSound)
    {
        if (ck::IsValid(InSound))
        { Gameplay::PlaySound2D(InSound); }
    }
}