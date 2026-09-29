UCLASS(Abstract)
class UMars_Hotbar_Widget : UCk_UserWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UPanelWidget SlotContainer;

    UPROPERTY(EditDefaultsOnly, Category = "Hotbar")
    TSubclassOf<UMars_HotbarSlot_Widget> SlotWidgetClass;

    private TArray<UMars_HotbarSlot_Widget> _SlotWidgets;
    private FCk_Handle_Hotbar _Hotbar;

    UFUNCTION(BlueprintOverride)
    void PreConstruct(bool bIsDesignTime)
    {
        if (bIsDesignTime == false || ck::Is_NOT_Valid(SlotContainer) || SlotWidgetClass == nullptr)
        { return; }

        const int32 PreviewBagSlotCount = 3;

        SlotContainer.ClearChildren();
        for (int32 Index = 0; Index <= PreviewBagSlotCount; ++Index)
        {
            auto PreviewWidget = Cast<UMars_HotbarSlot_Widget>(WidgetBlueprint::CreateWidget(SlotWidgetClass, GetOwningPlayer()));
            if (ck::Is_NOT_Valid(PreviewWidget))
            { continue; }

            PreviewWidget.Setup(Index, Index == PreviewBagSlotCount);
            SlotContainer.AddChild(PreviewWidget);
        }
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        if (ck::IsValid(SlotContainer))
        { SlotContainer.ClearChildren(); }

        _SlotWidgets.Empty();
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

            SlotWidget.Setup(Index, Index == OverflowIndex);
            SlotWidget.InjectInventory(Slots[Index]);
            SlotContainer.AddChild(SlotWidget);
            _SlotWidgets.Add(SlotWidget);
        }

        _Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));

        // The signal is edge-only; converge on the selection the hotbar already holds.
        const auto SelectedIndex = _Hotbar.Get_SelectedIndex();
        for (int32 Index = 0; Index < _SlotWidgets.Num(); ++Index)
        { _SlotWidgets[Index].Set_Selected(Index == SelectedIndex); }
    }

    UFUNCTION(BlueprintOverride)
    void OnContextCleared()
    {
        if (ck::IsValid(_Hotbar))
        { _Hotbar.UnbindFrom_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged")); }

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

    private void ClearSlots()
    {
        for (auto SlotWidget : _SlotWidgets)
        {
            if (ck::IsValid(SlotWidget))
            { SlotWidget.ClearPanel(); }
        }

        if (ck::IsValid(SlotContainer))
        { SlotContainer.ClearChildren(); }

        _SlotWidgets.Empty();
    }
}
