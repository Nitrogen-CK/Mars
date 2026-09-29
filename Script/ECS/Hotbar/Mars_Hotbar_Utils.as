namespace utils_hotbar
{
    const int32 k_MaxBagSlotCount = 8;

    // Composes BagSlotCount capacity-1 bag slot inventories and one overflow slot on InPlayer. The Hotbar never moves
    // items itself: a caller stows by transferring into TryGet_StowTarget(), and the sync pass reacts to what lands.
    FCk_Handle_Hotbar Add(FCk_Handle& InPlayer, FMars_Hotbar_Spec InSpec)
    {
        const auto BagSlotCountIsValid = InSpec.BagSlotCount >= 1 && InSpec.BagSlotCount <= k_MaxBagSlotCount;
        if (ck::EnsureIfNot(BagSlotCountIsValid,
            f"[Hotbar] BagSlotCount [{InSpec.BagSlotCount}] is outside [1, {k_MaxBagSlotCount}] - Inventory.Mars.Slot.N tags only go that far"))
        { return FCk_Handle_Hotbar(); }

        auto State = FMars_Fragment_Hotbar();
        for (int32 Index = 0; Index <= InSpec.BagSlotCount; ++Index)
        {
            const auto IsOverflow = Index == InSpec.BagSlotCount;
            const auto SlotName = utils_gameplay_tag::ResolveGameplayTag(
                IsOverflow ? n"Inventory.Mars.Overflow" : FName(f"Inventory.Mars.Slot.{Index}"));

            auto SlotParams = utils_inventory_data_only::Make_Params_Bounded(SlotName, 1,
                FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
                FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
            SlotParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
            SlotParams.Set_PersistContents(ECk_EnableDisable::Disable);

            State.Slots.Add(utils_inventory_data_only::Add(InPlayer, SlotParams, ECk_Replication::DoesNotReplicate));
            State.LastSeen.Add(FCk_Handle_Item());
        }

        auto Params = FMars_Fragment_Hotbar_Params();
        Params.BagSlotCount = InSpec.BagSlotCount;

        InPlayer.Add_Fragment(FMars_Feature_Hotbar());
        InPlayer.Add_Fragment(Params);
        InPlayer.Add_Fragment(State);
        return InPlayer.As_Hotbar();
    }

    // Processor-side: the one place SelectedIndex changes.
    void DoApplySelection(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, int32 InNewIndex)
    {
        const auto PrevIndex = InState.SelectedIndex;
        if (PrevIndex == InNewIndex)
        { return; }

        InState.SelectedIndex = InNewIndex;

        if (InHotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals))
        { InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSelectionChanged.Broadcast(InHotbar, PrevIndex, InNewIndex); }
    }

    FCk_Handle_Item DoGet_FirstItem(FCk_Handle_Inventory_DataOnly InSlot)
    {
        if (ck::Is_NOT_Valid(InSlot) || InSlot.Get_NumItems() == 0)
        { return FCk_Handle_Item(); }

        auto Items = InSlot.Get_Items();
        return Items[0];
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin int32 Get_BagSlotCount(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar_Params).BagSlotCount;
}

mixin int32 Get_OverflowIndex(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_BagSlotCount();
}

mixin TArray<FCk_Handle_Inventory_DataOnly> Get_Slots(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar).Slots;
}

// Invalid when InIndex is out of range.
mixin FCk_Handle_Inventory_DataOnly Get_Slot(const FCk_Handle_Hotbar& Self, int32 InIndex)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Hotbar);
    if (State.Slots.IsValidIndex(InIndex) == false)
    { return FCk_Handle_Inventory_DataOnly(); }

    return State.Slots[InIndex];
}

mixin FCk_Handle_Item Get_ItemAt(const FCk_Handle_Hotbar& Self, int32 InIndex)
{
    return utils_hotbar::DoGet_FirstItem(Self.Get_Slot(InIndex));
}

mixin int32 Get_SelectedIndex(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar).SelectedIndex;
}

// Invalid while hands are empty.
mixin FCk_Handle_Inventory_DataOnly Get_SelectedSlot(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Slot(Self.Get_SelectedIndex());
}

// Invalid while hands are empty or the selected slot is empty.
mixin FCk_Handle_Item Get_SelectedItem(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_ItemAt(Self.Get_SelectedIndex());
}

mixin bool Get_IsOverflowOccupied(const FCk_Handle_Hotbar& Self)
{
    return ck::IsValid(Self.Get_ItemAt(Self.Get_OverflowIndex()));
}

// -1 when every bag slot holds an item.
mixin int32 TryGet_FirstEmptyBagSlot(const FCk_Handle_Hotbar& Self)
{
    const auto BagSlotCount = Self.Get_BagSlotCount();
    for (int32 Index = 0; Index < BagSlotCount; ++Index)
    {
        if (ck::Is_NOT_Valid(Self.Get_ItemAt(Index)))
        { return Index; }
    }
    return -1;
}

// Where a picked-up item should go: the first empty bag slot, else the overflow slot if empty, else invalid.
mixin FCk_Handle_Inventory_DataOnly TryGet_StowTarget(const FCk_Handle_Hotbar& Self)
{
    const auto BagIndex = Self.TryGet_FirstEmptyBagSlot();
    if (BagIndex != -1)
    { return Self.Get_Slot(BagIndex); }

    if (Self.Get_IsOverflowOccupied())
    { return FCk_Handle_Inventory_DataOnly(); }

    return Self.Get_Slot(Self.Get_OverflowIndex());
}

mixin bool Get_CanStow(const FCk_Handle_Hotbar& Self)
{
    return ck::IsValid(Self.TryGet_StowTarget());
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Select(FCk_Handle_Hotbar& Self, const FMars_Request_Hotbar_Select& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.SelectRequests.Add(InRequest);
}

mixin void Request_Deselect(FCk_Handle_Hotbar& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.DeselectRequestCount += 1;
}

mixin void Request_CycleNext(FCk_Handle_Hotbar& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.CycleRequests.Add(FMars_Request_Hotbar_Cycle(1));
}

mixin void Request_CyclePrevious(FCk_Handle_Hotbar& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.CycleRequests.Add(FMars_Request_Hotbar_Cycle(-1));
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnSelectionChanged(FCk_Handle_Hotbar& Self, FMars_Delegate_Hotbar_OnSelectionChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Signals);
    Fragment.OnSelectionChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSelectionChanged(FCk_Handle_Hotbar& Self, FMars_Delegate_Hotbar_OnSelectionChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Hotbar_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSelectionChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSlotItemChanged(FCk_Handle_Hotbar& Self, FMars_Delegate_Hotbar_OnSlotItemChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Signals);
    Fragment.OnSlotItemChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSlotItemChanged(FCk_Handle_Hotbar& Self, FMars_Delegate_Hotbar_OnSlotItemChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Hotbar_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSlotItemChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnOverflowEjectRequested(FCk_Handle_Hotbar& Self, FMars_Delegate_Hotbar_OnOverflowEjectRequested InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Signals);
    Fragment.OnOverflowEjectRequested.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnOverflowEjectRequested(FCk_Handle_Hotbar& Self, FMars_Delegate_Hotbar_OnOverflowEjectRequested InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Hotbar_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnOverflowEjectRequested.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
