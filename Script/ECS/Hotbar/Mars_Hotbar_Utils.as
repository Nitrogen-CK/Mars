// Stateless accept predicates for the hotbar's slot inventories, bound from the CDO (a params-borne delegate has no
// post-creation install API and needs a target that outlives every hotbar).
UCLASS()
class UMars_Hotbar_AcceptPolicy : UObject
{
    UFUNCTION()
    void OnCanAccept_ItemSlot(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = InItem.Has_Backpack() == false && InItem.Has_HandsOnly() == false; }

    UFUNCTION()
    void OnCanAccept_OverflowSlot(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = InItem.Has_Backpack() == false; }

    UFUNCTION()
    void OnCanAccept_BackpackSlot(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = InItem.Has_Backpack(); }
}

namespace utils_hotbar
{
    const int32 k_MaxBagSlotCount = 8;

    // Composes BagSlotCount capacity-1 bag slot inventories, one overflow slot and (BackpackSlot Enable) one backpack slot
    // on InPlayer. The Hotbar never moves items itself: a caller stows by transferring into TryGet_StowTarget(Item), and
    // the sync pass reacts to what lands. Every slot's accept policy is enforced by CkInventory on every add/transfer.
    FCk_Handle_Hotbar Add(FCk_Handle& InPlayer, FMars_Hotbar_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Hotbar] {Validation.Get_Error()}"))
        { return FCk_Handle_Hotbar(); }

        TSubclassOf<UMars_Hotbar_AcceptPolicy> PolicyClass = UMars_Hotbar_AcceptPolicy;
        auto Policy = PolicyClass.GetDefaultObject();

        const auto HasBackpackSlot = InSpec.BackpackSlot == ECk_EnableDisable::Enable;
        const auto SlotCount = InSpec.BagSlotCount + 1 + (HasBackpackSlot ? 1 : 0);

        auto State = FMars_Fragment_Hotbar();
        for (int32 Index = 0; Index <= SlotCount - 1; ++Index)
        {
            auto PolicyFunction = n"OnCanAccept_ItemSlot";
            auto SlotTag = FGameplayTag();
            if (Index == InSpec.BagSlotCount)
            {
                SlotTag = GameplayTags::Inventory_Mars_Overflow;
                PolicyFunction = n"OnCanAccept_OverflowSlot";
            }
            else if (Index == InSpec.BagSlotCount + 1)
            {
                SlotTag = GameplayTags::Inventory_Mars_Backpack;
                PolicyFunction = n"OnCanAccept_BackpackSlot";
            }
            else
            { SlotTag = utils_gameplay_tag::ResolveGameplayTag(FName(f"Inventory.Mars.Slot.{Index}")); }

            auto SlotParams = utils_inventory_data_only::Make_Params_Bounded(
                SlotTag, 1,
                FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(Policy, PolicyFunction),
                FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
            SlotParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
            SlotParams.Set_PersistContents(ECk_EnableDisable::Disable);

            State.Slots.Add(utils_inventory_data_only::Add(InPlayer, SlotParams, ECk_Replication::DoesNotReplicate));
            State.LastSeen.Add(FCk_Handle_Item());
        }

        auto Params = FMars_Fragment_Hotbar_Params();
        Params.Spec = InSpec;

        InPlayer.Add_Fragment(FMars_Feature_Hotbar());
        InPlayer.Add_Fragment(Params);
        InPlayer.Add_Fragment(State);
        return InPlayer.As_Hotbar();
    }

    // Processor-only: the two Hotbar processors are the only writers of SelectedIndex.
    void Apply_Selection(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, TOptional<int32> InNewIndex)
    {
        if (InState.SelectedIndex == InNewIndex)
        { return; }

        InState.SelectedIndex = InNewIndex;

        if (InHotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals))
        { InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSelectionChanged.Broadcast(InHotbar); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin int32 Get_BagSlotCount(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar_Params).Spec.BagSlotCount;
}

mixin int32 Get_OverflowIndex(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_BagSlotCount();
}

mixin bool Get_HasBackpackSlot(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar_Params).Spec.BackpackSlot == ECk_EnableDisable::Enable;
}

// Unset when the hotbar has no backpack slot.
mixin TOptional<int32> Get_BackpackIndex(const FCk_Handle_Hotbar& Self)
{
    if (Self.Get_HasBackpackSlot() == false)
    { return TOptional<int32>(); }

    return TOptional<int32>(Self.Get_BagSlotCount() + 1);
}

// The highest selectable index: the backpack slot when present, else the overflow slot.
mixin int32 Get_LastIndex(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar).Slots.Num() - 1;
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

// Invalid when InIndex is out of range or the slot is empty.
mixin FCk_Handle_Item Get_ItemAt(const FCk_Handle_Hotbar& Self, int32 InIndex)
{
    const auto Slot = Self.Get_Slot(InIndex);
    return Slot.Get_SoleItem();
}

// Unset while hands are empty.
mixin TOptional<int32> Get_SelectedIndex(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar).SelectedIndex;
}

// Unset while nothing is parked; see FMars_Hotbar_ParkedSelection.
mixin TOptional<FMars_Hotbar_ParkedSelection> TryGet_ParkedSelection(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar).ParkedSelection;
}

// Invalid while hands are empty.
mixin FCk_Handle_Inventory_DataOnly Get_SelectedSlot(const FCk_Handle_Hotbar& Self)
{
    const auto SelectedIndex = Self.Get_SelectedIndex();
    if (SelectedIndex.IsSet() == false)
    { return FCk_Handle_Inventory_DataOnly(); }

    return Self.Get_Slot(SelectedIndex.GetValue());
}

// Invalid while hands are empty or the selected slot is empty.
mixin FCk_Handle_Item Get_SelectedItem(const FCk_Handle_Hotbar& Self)
{
    const auto Slot = Self.Get_SelectedSlot();
    return Slot.Get_SoleItem();
}

mixin bool Get_IsOverflowOccupied(const FCk_Handle_Hotbar& Self)
{
    return ck::IsValid(Self.Get_ItemAt(Self.Get_OverflowIndex()));
}

// Invalid when the hotbar has no backpack slot.
mixin FCk_Handle_Inventory_DataOnly Get_BackpackSlot(const FCk_Handle_Hotbar& Self)
{
    const auto BackpackIndex = Self.Get_BackpackIndex();
    if (BackpackIndex.IsSet() == false)
    { return FCk_Handle_Inventory_DataOnly(); }

    return Self.Get_Slot(BackpackIndex.GetValue());
}

// Invalid when the hotbar has no backpack slot or it is empty.
mixin FCk_Handle_Item Get_BackpackItem(const FCk_Handle_Hotbar& Self)
{
    const auto Slot = Self.Get_BackpackSlot();
    return Slot.Get_SoleItem();
}

mixin bool Get_IsWearingBackpack(const FCk_Handle_Hotbar& Self)
{
    return ck::IsValid(Self.Get_BackpackItem());
}

// Unset when every bag slot holds an item.
mixin TOptional<int32> TryGet_FirstEmptyBagSlot(const FCk_Handle_Hotbar& Self)
{
    const auto BagSlotCount = Self.Get_BagSlotCount();
    for (int32 Index = 0; Index < BagSlotCount; ++Index)
    {
        if (ck::Is_NOT_Valid(Self.Get_ItemAt(Index)))
        { return TOptional<int32>(Index); }
    }

    return TOptional<int32>();
}

// Backpack item: the backpack slot if present and empty, else invalid.
// Hands-only item: the overflow slot if empty, else invalid (never a bag slot, even a free one).
// Any other item: first empty bag slot, else overflow if empty, else invalid.
mixin FCk_Handle_Inventory_DataOnly TryGet_StowTarget(const FCk_Handle_Hotbar& Self, const FCk_Handle_Item& InItem)
{
    if (ck::Is_NOT_Valid(InItem))
    { return FCk_Handle_Inventory_DataOnly(); }

    if (InItem.Has_Backpack())
    {
        if (Self.Get_HasBackpackSlot() == false || Self.Get_IsWearingBackpack())
        { return FCk_Handle_Inventory_DataOnly(); }

        return Self.Get_BackpackSlot();
    }

    // A hands-only item: the overflow slot (both hands) or nowhere.
    if (InItem.Has_HandsOnly())
    { return Self.Get_IsOverflowOccupied() ? FCk_Handle_Inventory_DataOnly() : Self.Get_Slot(Self.Get_OverflowIndex()); }

    const auto BagIndex = Self.TryGet_FirstEmptyBagSlot();
    if (BagIndex.IsSet())
    { return Self.Get_Slot(BagIndex.GetValue()); }

    if (Self.Get_IsOverflowOccupied())
    { return FCk_Handle_Inventory_DataOnly(); }

    return Self.Get_Slot(Self.Get_OverflowIndex());
}

mixin bool Get_CanStow(const FCk_Handle_Hotbar& Self, const FCk_Handle_Item& InItem)
{
    return ck::IsValid(Self.TryGet_StowTarget(InItem));
}

// Where a TAKEN item lands: the selected bag slot when it is empty (into the hands) and the item fits a bag slot, else
// TryGet_StowTarget(InItem).
mixin FCk_Handle_Inventory_DataOnly TryGet_TakeTarget(const FCk_Handle_Hotbar& Self, const FCk_Handle_Item& InItem)
{
    if (ck::Is_NOT_Valid(InItem))
    { return FCk_Handle_Inventory_DataOnly(); }

    const auto SelectedIndex = Self.Get_SelectedIndex();
    const auto SelectedIsBagSlot = SelectedIndex.IsSet() && SelectedIndex.GetValue() < Self.Get_BagSlotCount();
    const auto FitsBagSlot = InItem.Has_Backpack() == false && InItem.Has_HandsOnly() == false;
    if (SelectedIsBagSlot && FitsBagSlot && ck::Is_NOT_Valid(Self.Get_ItemAt(SelectedIndex.GetValue())))
    { return Self.Get_Slot(SelectedIndex.GetValue()); }

    return Self.TryGet_StowTarget(InItem);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Select(FCk_Handle_Hotbar& Self, const FMars_Request_Hotbar_Select& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.SelectionChangeRequests.Add(FMars_Hotbar_SelectionChangeRequest(EMars_Hotbar_SelectionChange::Select, InRequest.Index));
}

mixin void Request_Deselect(FCk_Handle_Hotbar& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.SelectionChangeRequests.Add(FMars_Hotbar_SelectionChangeRequest(EMars_Hotbar_SelectionChange::Deselect));
}

mixin void Request_CycleNext(FCk_Handle_Hotbar& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.SelectionChangeRequests.Add(FMars_Hotbar_SelectionChangeRequest(EMars_Hotbar_SelectionChange::CycleNext));
}

mixin void Request_CyclePrevious(FCk_Handle_Hotbar& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.SelectionChangeRequests.Add(FMars_Hotbar_SelectionChangeRequest(EMars_Hotbar_SelectionChange::CyclePrevious));
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
