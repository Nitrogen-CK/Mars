//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HotbarHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Hotbar";
    RequiredFragments.Add(FMars_Feature_Hotbar);
    Description = "The player's hotbar: capacity-1 bag slot inventories plus one overflow slot, and the selected slot";
}
struct FMars_Feature_Hotbar {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Hotbar_CycleDirection
{
    Next,
    Previous
}

// Deselect empties the hands (parked instead while an occupied overflow slot is selected). Cycle steps through the bag
// slots only, wrapping; the overflow slot is never a cycle target.
enum EMars_Hotbar_SelectionChange
{
    Select,
    Deselect,
    CycleNext,
    CyclePrevious
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Hotbar_Spec
{
    // The overflow slot is always added on top, at index BagSlotCount.
    UPROPERTY()
    int32 BagSlotCount = 3;

    // Enabled adds the backpack slot after the overflow slot, at index BagSlotCount + 1. Only a backpack item fits it,
    // and a backpack item fits nowhere else.
    UPROPERTY()
    ECk_EnableDisable BackpackSlot = ECk_EnableDisable::Enable;
}

// BagSlotCount in [1, utils_hotbar::k_MaxBagSlotCount]: the Inventory.Mars.Slot.N tags only go that far.
mixin FMars_Validation Validate(const FMars_Hotbar_Spec& Self)
{
    const auto BagSlotCountIsValid = Self.BagSlotCount >= 1 && Self.BagSlotCount <= utils_hotbar::k_MaxBagSlotCount;
    if (BagSlotCountIsValid == false)
    {
        return FMars_Validation(
            f"BagSlotCount [{Self.BagSlotCount}] is outside [1, {utils_hotbar::k_MaxBagSlotCount}] - Inventory.Mars.Slot.N tags only go that far");
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Hotbar_Params
{
    UPROPERTY()
    FMars_Hotbar_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// A selection parked while the occupied overflow slot is selected. Unset Index parks a deselect (hands empty).
struct FMars_Hotbar_ParkedSelection
{
    UPROPERTY()
    TOptional<int32> Index;

    FMars_Hotbar_ParkedSelection() {}

    FMars_Hotbar_ParkedSelection(TOptional<int32> InIndex)
    {
        Index = InIndex;
    }
}

// The overflow slot is only ever occupied while every bag slot is full, and while occupied it is always the selected
// slot: any selection that would leave it is parked until its item has been dropped.
struct FMars_Fragment_Hotbar
{
    // Layout: [0 .. N-1] bag, [N] overflow, [N+1] backpack (only with a backpack slot), N = BagSlotCount.
    UPROPERTY()
    TArray<FCk_Handle_Inventory_DataOnly> Slots;

    // Unset = hands empty.
    UPROPERTY()
    TOptional<int32> SelectedIndex;

    UPROPERTY()
    TOptional<FMars_Hotbar_ParkedSelection> ParkedSelection;

    // The item each slot held on the previous sync pass; slot contents are polled, not bound.
    UPROPERTY()
    TArray<FCk_Handle_Item> LastSeen;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Read the new selection with Get_SelectedIndex.
delegate void FMars_Delegate_Hotbar_OnSelectionChanged(FCk_Handle_Hotbar InHotbar);
event void FMars_Delegate_Hotbar_OnSelectionChanged_MC(FCk_Handle_Hotbar InHotbar);

delegate void FMars_Delegate_Hotbar_OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem);
event void FMars_Delegate_Hotbar_OnSlotItemChanged_MC(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem);

// Fired once per park: the holder of the overflow item must drop it before the parked selection (TryGet_ParkedSelection)
// can apply.
delegate void FMars_Delegate_Hotbar_OnOverflowEjectRequested(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem);
event void FMars_Delegate_Hotbar_OnOverflowEjectRequested_MC(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem);

struct FMars_Fragment_Hotbar_Signals
{
    FMars_Delegate_Hotbar_OnSelectionChanged_MC OnSelectionChanged;
    FMars_Delegate_Hotbar_OnSlotItemChanged_MC OnSlotItemChanged;
    FMars_Delegate_Hotbar_OnOverflowEjectRequested_MC OnOverflowEjectRequested;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Selecting the already-selected slot deselects it.
struct FMars_Request_Hotbar_Select
{
    // Always set by the constructor; unset only on a default-constructed request, which the drain rejects.
    UPROPERTY()
    TOptional<int32> Index;

    FMars_Request_Hotbar_Select() {}

    FMars_Request_Hotbar_Select(int32 InIndex)
    {
        Index = TOptional<int32>(InIndex);
    }
}

// A Select, Deselect or Cycle request, queued with the other kinds so the drain applies them in arrival order.
struct FMars_Hotbar_SelectionChangeRequest
{
    UPROPERTY()
    EMars_Hotbar_SelectionChange Change = EMars_Hotbar_SelectionChange::Deselect;

    // Select only; a Select without one is rejected by the drain.
    UPROPERTY()
    TOptional<int32> Index;

    FMars_Hotbar_SelectionChangeRequest() {}

    FMars_Hotbar_SelectionChangeRequest(EMars_Hotbar_SelectionChange InChange)
    {
        Change = InChange;
    }

    FMars_Hotbar_SelectionChangeRequest(EMars_Hotbar_SelectionChange InChange, TOptional<int32> InIndex)
    {
        Change = InChange;
        Index = InIndex;
    }
}

// Selection changes apply in arrival order (a Deselect then a Select queued in one frame ends selected).
struct FMars_Fragment_Hotbar_Requests
{
    UPROPERTY()
    TArray<FMars_Hotbar_SelectionChangeRequest> SelectionChangeRequests;
}
