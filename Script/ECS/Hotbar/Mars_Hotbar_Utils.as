// The kind of slot an index of the hotbar's layout is: [0, BagSlotCount) bag, BagSlotCount overflow, BagSlotCount + 1
// backpack (only with a backpack slot).
enum EMars_Hotbar_SlotKind
{
    Bag,
    Overflow,
    Backpack
}

// Stateless accept predicates for the hotbar's slot inventories, bound from the CDO (a params-borne delegate has no
// post-creation install API and needs a target that outlives every hotbar). Each asks the fit rule for its own kind.
UCLASS()
class UMars_Hotbar_AcceptPolicy : UObject
{
    UFUNCTION()
    void OnCanAccept_ItemSlot(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = utils_hotbar::Get_FitsSlot(EMars_Hotbar_SlotKind::Bag, InItem); }

    UFUNCTION()
    void OnCanAccept_OverflowSlot(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = utils_hotbar::Get_FitsSlot(EMars_Hotbar_SlotKind::Overflow, InItem); }

    UFUNCTION()
    void OnCanAccept_BackpackSlot(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = utils_hotbar::Get_FitsSlot(EMars_Hotbar_SlotKind::Backpack, InItem); }
}

namespace utils_hotbar
{
    const int32 k_MaxBagSlotCount = 8;

    // Processor-only, authority only: UMars_Processor_Hotbar_HandleRequests and UMars_Processor_Hotbar_Sync are
    // SelectedIndex's only writers, and both go through here so a change is always marked for replication and broadcasts
    // OnSelectionChanged.
    void Apply_Selection(FCk_Handle_Hotbar& InHotbar, FMars_Fragment_Hotbar& InState, TOptional<int32> InNewIndex)
    {
        if (InState.SelectedIndex == InNewIndex)
        { return; }

        InState.SelectedIndex = InNewIndex;
        InHotbar.H().Request_MarkReplicationDirty(FMars_Fragment_Hotbar);

        if (InHotbar.Has_Fragment(FMars_Fragment_Hotbar_Signals))
        { InHotbar.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSelectionChanged.Broadcast(InHotbar); }
    }

    // The slot-fit rule, the one place it is written: a backpack fits only the backpack slot, a hands-only item only the
    // overflow slot, any other item a bag slot or the overflow slot. CkInventory enforces it on every add and transfer
    // through the accept predicates; the stow and take targets ask it before they name a slot.
    bool Get_FitsSlot(EMars_Hotbar_SlotKind InKind, const FCk_Handle_Item& InItem)
    {
        switch (InKind)
        {
            case EMars_Hotbar_SlotKind::Bag: return InItem.Has_Backpack() == false && InItem.Has_HandsOnly() == false;
            case EMars_Hotbar_SlotKind::Overflow: return InItem.Has_Backpack() == false;
            default: return InItem.Has_Backpack();
        }
    }

    // Composes the hotbar on InPlayer on every machine: BagSlotCount capacity-1 bag slots, one overflow slot and
    // (BackpackSlot Enable) one backpack slot, each on a slot root of its own that UMars_Processor_Hotbar_SpawnSlots
    // requests under InPlayer; the hotbar is ready (Get_IsReady) once every root is adopted. The Hotbar never moves items
    // itself: a caller stows by transferring into TryGet_StowTarget(Item), and the sync pass reacts to what lands. Every
    // slot's accept policy is enforced by CkInventory on every add/transfer. A Persistent item in a slot rides InPlayer:
    // Held from the selected slot, else Carried on its own CarryPoint.
    FCk_Handle_Hotbar Add(FCk_Handle& InPlayer, FMars_Hotbar_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Hotbar] {Validation.Get_Error()}"))
        { return FCk_Handle_Hotbar(); }

        const auto HasBackpackSlot = InSpec.BackpackSlot == ECk_EnableDisable::Enable;
        const auto SlotCount = InSpec.BagSlotCount + 1 + (HasBackpackSlot ? 1 : 0);

        auto Local = FMars_Fragment_Hotbar_Local();
        for (int32 Index = 0; Index < SlotCount; ++Index)
        {
            Local.Slots.Add(FCk_Handle_Inventory_DataOnly());
            Local.LastSeen.Add(FCk_Handle_Item());
        }

        auto Params = FMars_Fragment_Hotbar_Params();
        Params.Spec = InSpec;

        // Seeded with the default ledger, not the arrived one: the mirror's first reconcile then broadcasts what arrived.
        const auto Ledger = FMars_Fragment_Hotbar();
        auto Mirror = FMars_Fragment_Hotbar_Mirror();
        Mirror.Last = Ledger;

        InPlayer.Add_Fragment(Params);
        InPlayer.Add_Fragment(Local);
        InPlayer.Add_Fragment(Mirror);
        InPlayer.Add_Fragment(FMars_Fragment_Hotbar_AwaitingSlots());
        InPlayer.Add_Fragment(FMars_Tag_Hotbar_NeedsSlots());
        InPlayer.Add_Fragment(FMars_Tag_Hotbar_NeedsMirror());

        // A client composing after the authority wrote the ledger already holds it: the replicated value arrives as the
        // fragment itself.
        if (InPlayer.Has_Fragment(FMars_Fragment_Hotbar) == false)
        { InPlayer.Add_Fragment(Ledger, ECk_Replication::Replicates); }

        // Last: the hotbar's processors see it only once it is whole.
        InPlayer.Add_Fragment(FMars_Feature_Hotbar());
        return InPlayer.As_Hotbar();
    }

    // Composes one slot's capacity-1 inventory on InSlotRoot (its tag and accept policy by kind, no stacking, contents not
    // saved), marks it as an inventory whose Persistent items ride the carrier, and records the slot. Called on every
    // machine by the slot root's own construction; only the authority evaluates the accept policies.
    FCk_Handle_Inventory_DataOnly Add_Slot(FCk_Handle& InSlotRoot, const FMars_HotbarSlot_Spec& InSpec)
    {
        // Stateless CDO delegates: a params-borne delegate has no post-creation install API and needs a target that
        // outlives every hotbar.
        TSubclassOf<UMars_Hotbar_AcceptPolicy> PolicyClass = UMars_Hotbar_AcceptPolicy;
        auto Policy = PolicyClass.GetDefaultObject();

        auto PolicyFunction = n"OnCanAccept_ItemSlot";
        auto SlotTag = FGameplayTag();
        if (InSpec.Kind == EMars_Hotbar_SlotKind::Overflow)
        {
            SlotTag = GameplayTags::Inventory_Mars_Overflow;
            PolicyFunction = n"OnCanAccept_OverflowSlot";
        }
        else if (InSpec.Kind == EMars_Hotbar_SlotKind::Backpack)
        {
            SlotTag = GameplayTags::Inventory_Mars_Backpack;
            PolicyFunction = n"OnCanAccept_BackpackSlot";
        }
        else
        { SlotTag = utils_gameplay_tag::ResolveGameplayTag(FName(f"Inventory.Mars.Slot.{InSpec.Index}")); }

        auto SlotParams = utils_inventory_data_only::Make_Params_Bounded(
            SlotTag, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(Policy, PolicyFunction),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        SlotParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        SlotParams.Set_PersistContents(ECk_EnableDisable::Disable);

        auto Inventory = utils_inventory_data_only::Add(InSlotRoot, SlotParams, InSpec.Replication);
        utils_world_item::Add_MountedInventory(Inventory, FMars_Fragment_MountedInventory());

        auto Slot = FMars_Fragment_HotbarSlot();
        Slot.Index = InSpec.Index;
        Slot.Kind = InSpec.Kind;
        Slot.Inventory = Inventory;
        InSlotRoot.Add_Fragment(Slot);
        return Inventory;
    }

    // What InChange means against this machine's view of InHotbar, as an absolute target (unset = empty hands): a Select
    // of the selected slot or a Cycle that lands on it deselects, as the drain applies them. A Set is already absolute.
    TOptional<int32> Resolve_SelectionChange(const FCk_Handle_Hotbar& InHotbar, const FMars_Hotbar_SelectionChangeRequest& InChange)
    {
        const auto Selected = InHotbar.Get_SelectedIndex();
        switch (InChange.Change)
        {
            case EMars_Hotbar_SelectionChange::Set: return InChange.Index;
            case EMars_Hotbar_SelectionChange::Deselect: return TOptional<int32>();
            case EMars_Hotbar_SelectionChange::Select:
            {
                if (ck::EnsureIfNot(InChange.Index.IsSet(), f"[Hotbar] [{InHotbar.ToString()}] got a Select with no index"))
                { return Selected; }

                return InChange.Index == Selected ? TOptional<int32>() : InChange.Index;
            }
            default: break;
        }

        const auto BagSlotCount = InHotbar.Get_BagSlotCount();
        const auto Step = InChange.Direction == EMars_Hotbar_CycleDirection::Next ? 1 : -1;
        const auto CurrentIsBagSlot = Selected.IsSet() && Selected.GetValue() < BagSlotCount;

        int32 Target = 0;
        if (CurrentIsBagSlot)
        { Target = (((Selected.GetValue() + Step) % BagSlotCount) + BagSlotCount) % BagSlotCount; }
        else if (InChange.Direction == EMars_Hotbar_CycleDirection::Previous)
        { Target = BagSlotCount - 1; }

        const auto Resolved = TOptional<int32>(Target);
        return Resolved == Selected ? TOptional<int32>() : Resolved;
    }

    // The one way a selection change is asked for outside a test: Cue.Mars.Hotbar.Select at the carrier with the absolute
    // target InChange means on this machine. The authority applies it; on the listen host and in standalone the same frame.
    void Fire_SelectCue(const FCk_Handle_Hotbar& InHotbar, const FMars_Hotbar_SelectionChangeRequest& InChange)
    {
        FCk_Handle Carrier = InHotbar;
        utils_cue_generic::Request_ExecuteCue(Carrier, GameplayTags::Cue_Mars_Hotbar_Select,
            FMars_Request_Hotbar_SetSelection(Resolve_SelectionChange(InHotbar, InChange)),
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
    }

    // The entity that carries InInventoryEntity: a hotbar slot's carrier (the slot root's lifetime owner), else the
    // inventory's own lifetime owner. Pending-kill owners are included so a caller can tell an ending carrier.
    FCk_Handle Get_CarrierOf(const FCk_Handle& InInventoryEntity)
    {
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InInventoryEntity, ECk_PendingKill_Policy::IncludePendingKill);
        if (ck::IsValid(Owner) && Owner.Has_Fragment(FMars_Fragment_HotbarSlot))
        { return utils_entity_lifetime::Get_LifetimeOwner(Owner, ECk_PendingKill_Policy::IncludePendingKill); }

        return Owner;
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

// The highest selectable index: the backpack slot when present, else the overflow slot. Valid before the slots are
// adopted.
mixin int32 Get_LastIndex(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_OverflowIndex() + (Self.Get_HasBackpackSlot() ? 1 : 0);
}

// Every slot root is adopted: until then Get_Slot is invalid for the slots not yet found and nothing can be stowed.
mixin bool Get_IsReady(const FCk_Handle_Hotbar& Self)
{
    return Self.Has_Fragment(FMars_Fragment_Hotbar_AwaitingSlots) == false;
}

mixin EMars_Hotbar_SlotKind Get_SlotKind(const FCk_Handle_Hotbar& Self, int32 InIndex)
{
    if (InIndex < Self.Get_BagSlotCount())
    { return EMars_Hotbar_SlotKind::Bag; }

    if (InIndex == Self.Get_OverflowIndex())
    { return EMars_Hotbar_SlotKind::Overflow; }

    return EMars_Hotbar_SlotKind::Backpack;
}

// One entry per layout index; an entry is invalid until its slot root is adopted.
mixin TArray<FCk_Handle_Inventory_DataOnly> Get_Slots(const FCk_Handle_Hotbar& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Hotbar_Local).Slots;
}

// Invalid when InIndex is out of range or its slot root is not adopted yet.
mixin FCk_Handle_Inventory_DataOnly Get_Slot(const FCk_Handle_Hotbar& Self, int32 InIndex)
{
    const auto& Local = Self.Get_Fragment(FMars_Fragment_Hotbar_Local);
    if (Local.Slots.IsValidIndex(InIndex) == false)
    { return FCk_Handle_Inventory_DataOnly(); }

    return Local.Slots[InIndex];
}

// The slot InItem is in, on this machine's view; unset when no slot holds it (or InItem is invalid).
mixin TOptional<int32> TryGet_SlotIndexOf(const FCk_Handle_Hotbar& Self, const FCk_Handle_Item& InItem)
{
    if (ck::Is_NOT_Valid(InItem))
    { return TOptional<int32>(); }

    const auto& Local = Self.Get_Fragment(FMars_Fragment_Hotbar_Local);
    for (int32 Index = 0; Index < Local.Slots.Num(); ++Index)
    {
        if (Local.Slots[Index].Get_SoleItem() == InItem)
        { return TOptional<int32>(Index); }
    }

    return TOptional<int32>();
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
    const auto& State = Self.Get_Fragment(FMars_Fragment_Hotbar);
    if (State.Park == EMars_Hotbar_Park::Nothing)
    { return TOptional<FMars_Hotbar_ParkedSelection>(); }

    return TOptional<FMars_Hotbar_ParkedSelection>(FMars_Hotbar_ParkedSelection(State.ParkedIndex));
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

// The first empty slot InItem fits (utils_hotbar::Get_FitsSlot), in layout order: a bag slot before the overflow slot, so
// a backpack goes only to the empty backpack slot, a hands-only item only to the empty overflow slot, any other item to the
// first empty bag slot, else the empty overflow slot. Invalid when none is free.
mixin FCk_Handle_Inventory_DataOnly TryGet_StowTarget(const FCk_Handle_Hotbar& Self, const FCk_Handle_Item& InItem)
{
    if (ck::Is_NOT_Valid(InItem))
    { return FCk_Handle_Inventory_DataOnly(); }

    for (int32 Index = 0; Index <= Self.Get_LastIndex(); ++Index)
    {
        if (ck::Is_NOT_Valid(Self.Get_ItemAt(Index)) && utils_hotbar::Get_FitsSlot(Self.Get_SlotKind(Index), InItem))
        { return Self.Get_Slot(Index); }
    }

    return FCk_Handle_Inventory_DataOnly();
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
    const auto SelectedIsBagSlot = SelectedIndex.IsSet() && Self.Get_SlotKind(SelectedIndex.GetValue()) == EMars_Hotbar_SlotKind::Bag;
    const auto FitsBagSlot = utils_hotbar::Get_FitsSlot(EMars_Hotbar_SlotKind::Bag, InItem);
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
    Requests.SelectionChangeRequests.Add(FMars_Hotbar_SelectionChangeRequest(InRequest));
}

mixin void Request_Deselect(FCk_Handle_Hotbar& Self, const FMars_Request_Hotbar_Deselect& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.SelectionChangeRequests.Add(FMars_Hotbar_SelectionChangeRequest(InRequest));
}

mixin void Request_Cycle(FCk_Handle_Hotbar& Self, const FMars_Request_Hotbar_Cycle& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.SelectionChangeRequests.Add(FMars_Hotbar_SelectionChangeRequest(InRequest));
}

mixin void Request_SetSelection(FCk_Handle_Hotbar& Self, const FMars_Request_Hotbar_SetSelection& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Requests);
    Requests.SelectionChangeRequests.Add(FMars_Hotbar_SelectionChangeRequest(InRequest));
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnReady(FCk_Handle_Hotbar& Self, FMars_Delegate_Hotbar_OnReady InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Hotbar_Signals);
    Fragment.OnReady.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReady(FCk_Handle_Hotbar& Self, FMars_Delegate_Hotbar_OnReady InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Hotbar_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnReady.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

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
