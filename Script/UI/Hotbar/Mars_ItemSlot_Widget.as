UCLASS(Abstract)
class UMars_ItemSlot_Widget : UCk_InventoryUI_ItemSlotEntry
{
    UPROPERTY(meta = (BindWidget))
    UImage Icon;

    // Shown instead of the icon when the item's definition has none.
    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock Name;

    UFUNCTION(BlueprintOverride)
    void OnItemDataSet(FCk_Handle_Item InMaybeValidItem, FCk_Handle_Inventory InInventory)
    {
        if (ck::Is_NOT_Valid(InMaybeValidItem))
        {
            Icon.SetVisibility(ESlateVisibility::Collapsed);
            Name.SetVisibility(ESlateVisibility::Collapsed);
            return;
        }

        const auto Definition = utils_item::Get_Definition(InMaybeValidItem);
        if (ck::EnsureIfNot(ck::IsValid(Definition), "[Mars_ItemSlot] Item has no Definition"))
        {
            Icon.SetVisibility(ESlateVisibility::Collapsed);
            Name.SetVisibility(ESlateVisibility::Collapsed);
            return;
        }

        const auto CoreInfo = Definition.Get_CoreInfo();
        const auto ItemIcon = CoreInfo.Get_Icon();
        if (ItemIcon.IsNull())
        {
            Icon.SetVisibility(ESlateVisibility::Collapsed);
            Name.SetText(CoreInfo.Get_Name());
            Name.SetVisibility(ESlateVisibility::HitTestInvisible);
            return;
        }

        Icon.SetBrushFromSoftTexture(ItemIcon, false);
        Icon.SetVisibility(ESlateVisibility::HitTestInvisible);
        Name.SetVisibility(ESlateVisibility::Collapsed);
    }

    // Slots are selected with keys, never rearranged by dragging.
    UFUNCTION(BlueprintOverride)
    bool CanAcceptDrop(UCk_InventoryUI_DragDropOperation InOperation) const
    {
        return false;
    }
}
