// PEAK layout: the bag slots in SlotContainer, and the overflow slot apart on the far left in OverflowContainer, where it
// only shows while it holds an item (see UMars_HotbarSlot_Widget).
UCLASS(Abstract)
class UMars_Hotbar_Widget : UCk_UserWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UPanelWidget SlotContainer;

    UPROPERTY(meta = (BindWidget))
    UPanelWidget OverflowContainer;

    UPROPERTY(EditDefaultsOnly, Category = "Hotbar")
    TSubclassOf<UMars_HotbarSlot_Widget> SlotWidgetClass;

    // Indexed like the hotbar's slots: the overflow slot is last.
    private TArray<UMars_HotbarSlot_Widget> _SlotWidgets;
    private FCk_Handle_Hotbar _Hotbar;

    UFUNCTION(BlueprintOverride)
    void PreConstruct(bool bIsDesignTime)
    {
        if (bIsDesignTime == false || ck::Is_NOT_Valid(SlotContainer) || ck::Is_NOT_Valid(OverflowContainer) || SlotWidgetClass == nullptr)
        { return; }

        const int32 PreviewBagSlotCount = 3;

        SlotContainer.ClearChildren();
        OverflowContainer.ClearChildren();
        for (int32 Index = 0; Index <= PreviewBagSlotCount; ++Index)
        {
            auto PreviewWidget = Cast<UMars_HotbarSlot_Widget>(WidgetBlueprint::CreateWidget(SlotWidgetClass, GetOwningPlayer()));
            if (ck::Is_NOT_Valid(PreviewWidget))
            { continue; }

            const auto IsOverflow = Index == PreviewBagSlotCount;
            PreviewWidget.Setup(Index, IsOverflow);

            // Show the overflow slot selected, as it is in game whenever it is on screen.
            if (IsOverflow)
            {
                PreviewWidget.Set_Selected(true);
                PreviewWidget.SetVisibility(ESlateVisibility::SelfHitTestInvisible);
            }

            DoGet_Container(IsOverflow).AddChild(PreviewWidget);
        }
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        ClearSlots();
    }

    UFUNCTION(BlueprintOverride)
    void OnValidContextInjected(FCk_Handle InContextEntity)
    {
        _Hotbar = InContextEntity.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Hotbar))
        { return; }

        if (ck::EnsureIfNot(SlotWidgetClass != nullptr, "[Mars_Hotbar] SlotWidgetClass is not set on the widget blueprint"))
        { return; }

        ClearSlots();

        const auto OverflowIndex = _Hotbar.Get_OverflowIndex();
        auto Slots = _Hotbar.Get_Slots();
        for (int32 Index = 0; Index < Slots.Num(); ++Index)
        {
            auto SlotWidget = Cast<UMars_HotbarSlot_Widget>(WidgetBlueprint::CreateWidget(SlotWidgetClass, GetOwningPlayer()));
            if (ck::EnsureIfNot(ck::IsValid(SlotWidget), f"[Mars_Hotbar] Could not create the widget for slot [{Index}]"))
            { continue; }

            const auto IsOverflow = Index == OverflowIndex;
            SlotWidget.Setup(Index, IsOverflow);
            SlotWidget.InjectInventory(Slots[Index]);
            DoGet_Container(IsOverflow).AddChild(SlotWidget);
            _SlotWidgets.Add(SlotWidget);
        }

        _Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));
        _Hotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnSlotItemChanged"));

        // Both signals are edge-only; converge on what the hotbar already holds.
        const auto SelectedIndex = _Hotbar.Get_SelectedIndex();
        for (int32 Index = 0; Index < _SlotWidgets.Num(); ++Index)
        {
            _SlotWidgets[Index].Set_Item(_Hotbar.Get_ItemAt(Index));
            _SlotWidgets[Index].Set_Selected(Index == SelectedIndex);
        }
    }

    UFUNCTION(BlueprintOverride)
    void OnContextCleared()
    {
        if (ck::IsValid(_Hotbar))
        {
            _Hotbar.UnbindFrom_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));
            _Hotbar.UnbindFrom_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnSlotItemChanged"));
        }

        _Hotbar = FCk_Handle_Hotbar();
        ClearSlots();
    }

    UFUNCTION()
    private void OnSelectionChanged(FCk_Handle_Hotbar InHotbar, int32 InPrevIndex, int32 InNewIndex)
    {
        if (_SlotWidgets.IsValidIndex(InPrevIndex))
        { _SlotWidgets[InPrevIndex].Set_Selected(false); }

        if (_SlotWidgets.IsValidIndex(InNewIndex))
        { _SlotWidgets[InNewIndex].Set_Selected(true); }
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        if (_SlotWidgets.IsValidIndex(InIndex))
        { _SlotWidgets[InIndex].Set_Item(InMaybeItem); }
    }

    private UPanelWidget DoGet_Container(bool InIsOverflow)
    {
        return InIsOverflow ? OverflowContainer : SlotContainer;
    }

    private void ClearSlots()
    {
        for (auto SlotWidget : _SlotWidgets)
        {
            if (ck::IsValid(SlotWidget))
            { SlotWidget.ClearPanel(); }
        }

        if (ck::IsValid(SlotContainer))
        { SlotContainer.ClearChildren(); }

        if (ck::IsValid(OverflowContainer))
        { OverflowContainer.ClearChildren(); }

        _SlotWidgets.Empty();
    }
}
