// Stance A. FMars_Fragment_Hotbar (the selection, the parked selection, the eject serial) is the replicated ledger, written
// only by the authority's request drain and sync pass. Each slot is a root of its own (UMars_HotbarSlot_EntityScript, a
// lifetime child of the carrier) holding one capacity-1 inventory: an inventory replicates its contents through its
// lifetime owner, so slots sharing the carrier would overwrite one another. The slot roots and their inventories
// replicate with the carrier; on a carrier with no replication driver (a test rig) they are local. The slot handles
// (Local) are adopted per machine; a client mirrors the ledger and broadcasts the signals from what replicated (Mirror).
// A client's selection reaches the authority through Cue.Mars.Hotbar.Select (utils_hotbar::Fire_SelectCue).

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

// Whether a selection waits behind the occupied overflow slot (FMars_Fragment_Hotbar.ParkedIndex says which).
enum EMars_Hotbar_Park
{
    Nothing,
    Parked
}

// Deselect empties the hands (parked instead while an occupied overflow slot is selected). Cycle steps through the bag
// slots only, wrapping; the overflow slot is never a cycle target. Set is absolute (a target slot, or empty hands) and
// never toggles: it is what a relative change means against one machine's view (utils_hotbar::Resolve_SelectionChange),
// so the authority applies the same target the requesting machine saw.
enum EMars_Hotbar_SelectionChange
{
    Select,
    Deselect,
    Cycle,
    Set
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
    // and a backpack item fits nowhere else; a hands-only item fits only the overflow slot.
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

// The replicated ledger, written only by UMars_Processor_Hotbar_HandleRequests and UMars_Processor_Hotbar_Sync on the
// authority. The overflow slot is only ever occupied while every bag slot is full, or by a hands-only item (which fits
// only the overflow slot), and while occupied it is always the selected slot: any selection that would leave it is
// parked until its item has been dropped.
struct FMars_Fragment_Hotbar
{
    // Unset = hands empty.
    UPROPERTY()
    TOptional<int32> SelectedIndex;

    // The parked selection, split in two because a replicated fragment cannot carry an optional struct (the net
    // serializer has no path for it). Read it as one through TryGet_ParkedSelection.
    UPROPERTY()
    EMars_Hotbar_Park Park = EMars_Hotbar_Park::Nothing;

    // Parked only; unset parks empty hands.
    UPROPERTY()
    TOptional<int32> ParkedIndex;

    // Advances once per park: the machine that owns the carrier answers each advance with one overflow eject.
    UPROPERTY()
    int32 EjectSerial = 0;
}

// Never replicated, sized by Add on every machine. Layout: [0 .. N-1] bag, [N] overflow, [N+1] backpack (only with a
// backpack slot), N = BagSlotCount. Slots fill as UMars_Processor_Hotbar_AdoptSlots finds each slot root; LastSeen is
// UMars_Processor_Hotbar_Sync's (slot contents are polled, not bound).
struct FMars_Fragment_Hotbar_Local
{
    UPROPERTY()
    TArray<FCk_Handle_Inventory_DataOnly> Slots;

    UPROPERTY()
    TArray<FCk_Handle_Item> LastSeen;
}

// Non-authority only (the authority's mirror pass removes it): the ledger as this machine last broadcast it, seeded with
// the ledger as Add composed it, so a value that replicated before the mirror bound still broadcasts.
struct FMars_Fragment_Hotbar_Mirror
{
    UPROPERTY()
    FMars_Fragment_Hotbar Last;
}

// Present until every slot root is adopted (Get_IsReady), removed by UMars_Processor_Hotbar_AdoptSlots.
struct FMars_Fragment_Hotbar_AwaitingSlots
{
    UPROPERTY()
    bool Awaiting = true;
}

// Consumed by UMars_Processor_Hotbar_SpawnSlots and UMars_Processor_Hotbar_Mirror respectively.
struct FMars_Tag_Hotbar_NeedsSlots {}
struct FMars_Tag_Hotbar_NeedsMirror {}

//--------------------------------------------------------------------------------------------------------------------------
// Slot roots
//--------------------------------------------------------------------------------------------------------------------------

// What one slot root is: its place in the layout, and the replication its inventory takes (the slot script's own).
struct FMars_HotbarSlot_Spec
{
    UPROPERTY()
    int32 Index = 0;

    UPROPERTY()
    EMars_Hotbar_SlotKind Kind = EMars_Hotbar_SlotKind::Bag;

    UPROPERTY()
    ECk_Replication Replication = ECk_Replication::DoesNotReplicate;

    FMars_HotbarSlot_Spec() {}

    FMars_HotbarSlot_Spec(int32 InIndex, EMars_Hotbar_SlotKind InKind, ECk_Replication InReplication)
    {
        Index = InIndex;
        Kind = InKind;
        Replication = InReplication;
    }
}

// The slot script's spawn params (UMars_HotbarSlot_EntityScript's ExposeOnSpawn fields): a client's placeholder is
// matched to the replicated slot by them.
struct FMars_HotbarSlot_SpawnParams
{
    UPROPERTY()
    int32 Index = 0;

    UPROPERTY()
    EMars_Hotbar_SlotKind Kind = EMars_Hotbar_SlotKind::Bag;

    FMars_HotbarSlot_SpawnParams() {}

    FMars_HotbarSlot_SpawnParams(int32 InIndex, EMars_Hotbar_SlotKind InKind)
    {
        Index = InIndex;
        Kind = InKind;
    }
}

// On a slot root, written once by utils_hotbar::Add_Slot on every machine.
struct FMars_Fragment_HotbarSlot
{
    UPROPERTY()
    int32 Index = 0;

    UPROPERTY()
    EMars_Hotbar_SlotKind Kind = EMars_Hotbar_SlotKind::Bag;

    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Inventory;
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

// Fired once per machine, when the last slot root is adopted (Get_IsReady turns true); slot handles are valid from then.
delegate void FMars_Delegate_Hotbar_OnReady(FCk_Handle_Hotbar InHotbar);
event void FMars_Delegate_Hotbar_OnReady_MC(FCk_Handle_Hotbar InHotbar);

struct FMars_Fragment_Hotbar_Signals
{
    FMars_Delegate_Hotbar_OnReady_MC OnReady;
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

struct FMars_Request_Hotbar_Deselect
{
    UPROPERTY()
    bool Requested = true;
}

struct FMars_Request_Hotbar_Cycle
{
    UPROPERTY()
    EMars_Hotbar_CycleDirection Direction = EMars_Hotbar_CycleDirection::Next;

    FMars_Request_Hotbar_Cycle() {}

    FMars_Request_Hotbar_Cycle(EMars_Hotbar_CycleDirection InDirection)
    {
        Direction = InDirection;
    }
}

// Absolute: the target slot, or unset for empty hands. Selecting the selected slot changes nothing. The payload of
// Cue.Mars.Hotbar.Select.
struct FMars_Request_Hotbar_SetSelection
{
    UPROPERTY()
    TOptional<int32> Index;

    FMars_Request_Hotbar_SetSelection() {}

    FMars_Request_Hotbar_SetSelection(TOptional<int32> InIndex)
    {
        Index = InIndex;
    }
}

// A Select, Deselect, Cycle or Set request, queued with the other kinds so the drain applies them in arrival order.
struct FMars_Hotbar_SelectionChangeRequest
{
    UPROPERTY()
    EMars_Hotbar_SelectionChange Change = EMars_Hotbar_SelectionChange::Deselect;

    // Select: the slot (a Select without one is rejected by the drain). Set: the target, unset for empty hands.
    UPROPERTY()
    TOptional<int32> Index;

    // Cycle only.
    UPROPERTY()
    EMars_Hotbar_CycleDirection Direction = EMars_Hotbar_CycleDirection::Next;

    FMars_Hotbar_SelectionChangeRequest() {}

    FMars_Hotbar_SelectionChangeRequest(const FMars_Request_Hotbar_Select& InRequest)
    {
        Change = EMars_Hotbar_SelectionChange::Select;
        Index = InRequest.Index;
    }

    FMars_Hotbar_SelectionChangeRequest(const FMars_Request_Hotbar_Deselect& InRequest)
    {
        Change = EMars_Hotbar_SelectionChange::Deselect;
    }

    FMars_Hotbar_SelectionChangeRequest(const FMars_Request_Hotbar_Cycle& InRequest)
    {
        Change = EMars_Hotbar_SelectionChange::Cycle;
        Direction = InRequest.Direction;
    }

    FMars_Hotbar_SelectionChangeRequest(const FMars_Request_Hotbar_SetSelection& InRequest)
    {
        Change = EMars_Hotbar_SelectionChange::Set;
        Index = InRequest.Index;
    }
}

// Selection changes apply in arrival order (a Deselect then a Select queued in one frame ends selected).
struct FMars_Fragment_Hotbar_Requests
{
    UPROPERTY()
    TArray<FMars_Hotbar_SelectionChangeRequest> SelectionChangeRequests;
}
