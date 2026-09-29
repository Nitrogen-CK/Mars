// One hotbar slot. The DataOnlyPanel base renders the slot inventory's item through _SlotClass into _ItemPanel and
// refreshes itself on the inventory's OnItemsChanged; this class adds the key label and the frames.
UCLASS(Abstract)
class UMars_HotbarSlot_Widget : UCk_InventoryUI_DataOnlyPanel
{
    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock SlotNumber;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget SelectedFrame;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget OverflowFrame;

    // The label is the number key that selects the slot (key K selects index K - 1, the overflow slot included).
    void Setup(int32 InIndex, bool InIsOverflow)
    {
        SlotNumber.SetText(FText::FromString(f"{InIndex + 1}"));

        if (ck::IsValid(OverflowFrame))
        { OverflowFrame.SetVisibility(InIsOverflow ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed); }

        Set_Selected(false);
    }

    void Set_Selected(bool InIsSelected)
    {
        if (ck::IsValid(SelectedFrame))
        { SelectedFrame.SetVisibility(InIsSelected ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed); }
    }
}
