//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HotbarHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Hotbar";
    RequiredFragments.Add(FMars_Feature_Hotbar);
    Description = "The player's PEAK-style hotbar: capacity-1 bag slot inventories plus one overflow slot, and the selected slot";
}
struct FMars_Feature_Hotbar {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Hotbar_Spec
{
    // The overflow slot is always added on top, at index BagSlotCount.
    UPROPERTY()
    int32 BagSlotCount = 3;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Hotbar_Params
{
    UPROPERTY()
    int32 BagSlotCount = 3;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The overflow slot is only ever occupied while every bag slot is full, and while occupied it is always the selected
// slot: any selection that would leave it is parked in PendingSelectedIndex until its item has been dropped.
struct FMars_Fragment_Hotbar
{
    // Num == BagSlotCount + 1; the last entry is the overflow slot.
    UPROPERTY()
    TArray<FCk_Handle_Inventory_DataOnly> Slots;

    // -1 = hands empty.
    UPROPERTY()
    int32 SelectedIndex = -1;

    // -2 = nothing parked.
    UPROPERTY()
    int32 PendingSelectedIndex = -2;

    // The item each slot held on the previous sync pass; slot contents are polled, not bound.
    UPROPERTY()
    TArray<FCk_Handle_Item> LastSeen;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Hotbar_OnSelectionChanged(FCk_Handle_Hotbar InHotbar, int32 InPrevIndex, int32 InNewIndex);
event void FMars_Delegate_Hotbar_OnSelectionChanged_MC(FCk_Handle_Hotbar InHotbar, int32 InPrevIndex, int32 InNewIndex);

delegate void FMars_Delegate_Hotbar_OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem);
event void FMars_Delegate_Hotbar_OnSlotItemChanged_MC(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem);

// Fired once per park: the holder of the overflow item must drop it before the parked selection can apply.
delegate void FMars_Delegate_Hotbar_OnOverflowEjectRequested(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem, int32 InPendingIndex);
event void FMars_Delegate_Hotbar_OnOverflowEjectRequested_MC(FCk_Handle_Hotbar InHotbar, FCk_Handle_Item InItem, int32 InPendingIndex);

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
    UPROPERTY()
    int32 Index = -1;

    FMars_Request_Hotbar_Select() {}

    FMars_Request_Hotbar_Select(int32 InIndex)
    {
        Index = InIndex;
    }
}

// Hands empty (parked instead while an occupied overflow slot is selected). AngelScript rejects a TArray of an empty
// struct ("Subtype is an empty struct", Bind_TArray.cpp), so it carries one placeholder field.
struct FMars_Request_Hotbar_Deselect
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Hotbar_Deselect() {}
}

// Steps through the bag slots only, wrapping; the overflow slot is never a cycle target.
struct FMars_Request_Hotbar_Cycle
{
    // +1 = next, -1 = previous.
    UPROPERTY()
    int32 Direction = 1;

    FMars_Request_Hotbar_Cycle() {}

    FMars_Request_Hotbar_Cycle(int32 InDirection)
    {
        Direction = InDirection;
    }
}

struct FMars_Fragment_Hotbar_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Hotbar_Select> SelectRequests;

    UPROPERTY()
    TArray<FMars_Request_Hotbar_Deselect> DeselectRequests;

    UPROPERTY()
    TArray<FMars_Request_Hotbar_Cycle> CycleRequests;
}
