// One hotbar slot. The DataOnlyPanel base renders the slot inventory's item through _SlotClass into _ItemPanel and
// refreshes itself on the inventory's OnItemsChanged; this class drives the frame, key badge and nameplate from the
// selected/occupied state the hotbar widget pushes in.
UCLASS(Abstract)
class UMars_HotbarSlot_Widget : UCk_InventoryUI_DataOnlyPanel
{
    UPROPERTY(meta = (BindWidget))
    UImage SlotFill;

    UPROPERTY(meta = (BindWidget))
    UImage SlotOutline;

    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock SlotNumber;

    // Holds SlotNumber; bag slots only.
    UPROPERTY(meta = (BindWidgetOptional))
    UWidget KeyBadge;

    // Takes the key badge's place on the overflow slot (PEAK: that item is carried in hand, not stowed under a key).
    UPROPERTY(meta = (BindWidgetOptional))
    UWidget HandMarker;

    // Shown while the slot is selected and holds an item; Hidden rather than Collapsed otherwise so every slot keeps
    // the same height and the frames stay aligned.
    UPROPERTY(meta = (BindWidgetOptional))
    UWidget Nameplate;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock ItemName;

    // The fill and outline textures are ivory; these tints multiply them.
    UPROPERTY(EditDefaultsOnly, Category = "Hotbar|Style")
    FLinearColor EmptyFillColor = FLinearColor(0.02, 0.02, 0.02, 0.2);

    UPROPERTY(EditDefaultsOnly, Category = "Hotbar|Style")
    FLinearColor OccupiedFillColor = FLinearColor(0.02, 0.02, 0.02, 0.35);

    UPROPERTY(EditDefaultsOnly, Category = "Hotbar|Style")
    FLinearColor SelectedFillColor = FLinearColor(1.0, 1.0, 1.0, 1.0);

    UPROPERTY(EditDefaultsOnly, Category = "Hotbar|Style")
    FLinearColor EmptyOutlineColor = FLinearColor(1.0, 1.0, 1.0, 0.5);

    UPROPERTY(EditDefaultsOnly, Category = "Hotbar|Style")
    FLinearColor OccupiedOutlineColor = FLinearColor(1.0, 1.0, 1.0, 0.75);

    UPROPERTY(EditDefaultsOnly, Category = "Hotbar|Style")
    FLinearColor SelectedOutlineColor = FLinearColor(1.0, 1.0, 1.0, 1.0);

    private bool _IsOverflow = false;
    private bool _IsSelected = false;
    private FCk_Handle_Item _Item;

    // The label is the number key that selects the slot (key K selects index K - 1).
    void Setup(int32 InIndex, bool InIsOverflow)
    {
        _IsOverflow = InIsOverflow;
        _IsSelected = false;
        _Item = FCk_Handle_Item();

        SlotNumber.SetText(FText::FromString(f"{InIndex + 1}"));

        if (ck::IsValid(KeyBadge))
        { KeyBadge.SetVisibility(InIsOverflow ? ESlateVisibility::Collapsed : ESlateVisibility::HitTestInvisible); }

        if (ck::IsValid(HandMarker))
        { HandMarker.SetVisibility(InIsOverflow ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed); }

        DoRefresh_State();
    }

    void Set_Selected(bool InIsSelected)
    {
        _IsSelected = InIsSelected;
        DoRefresh_State();
    }

    void Set_Item(FCk_Handle_Item InMaybeItem)
    {
        _Item = InMaybeItem;
        DoRefresh_State();
    }

    private void DoRefresh_State()
    {
        const auto IsOccupied = ck::IsValid(_Item);

        // PEAK layout: the overflow slot is only on screen while it holds something.
        if (_IsOverflow)
        { SetVisibility(IsOccupied ? ESlateVisibility::SelfHitTestInvisible : ESlateVisibility::Collapsed); }

        if (_IsSelected)
        {
            SlotFill.SetColorAndOpacity(SelectedFillColor);
            SlotOutline.SetColorAndOpacity(SelectedOutlineColor);
        }
        else if (IsOccupied)
        {
            SlotFill.SetColorAndOpacity(OccupiedFillColor);
            SlotOutline.SetColorAndOpacity(OccupiedOutlineColor);
        }
        else
        {
            SlotFill.SetColorAndOpacity(EmptyFillColor);
            SlotOutline.SetColorAndOpacity(EmptyOutlineColor);
        }

        const auto ShowsNameplate = _IsSelected && IsOccupied;

        if (ShowsNameplate && ck::IsValid(ItemName))
        { ItemName.SetText(DoGet_ItemName()); }

        if (ck::IsValid(Nameplate))
        { Nameplate.SetVisibility(ShowsNameplate ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Hidden); }
    }

    private FText DoGet_ItemName()
    {
        const auto Definition = utils_item::Get_Definition(_Item);
        if (ck::Is_NOT_Valid(Definition))
        { return FText(); }

        return Definition.Get_CoreInfo().Get_Name();
    }
}
