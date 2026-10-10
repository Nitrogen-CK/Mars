// One cargo slot of a backpack: a child entity of the pack root with its own capacity-1 inventory, a probe-driven
// interactable at its mount and a Visual-mode world item of whatever it holds; a stowed food item is no visual: its own
// Persistent world item is carried on the slot's node (the way a dock carries a platter). Anyone who can aim at the slot
// can stow into it or take out of it; nothing here reads "the local player".

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_CargoSlotHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_CargoSlot";
    RequiredFragments.Add(FMars_Feature_CargoSlot);
    Description = "One backpack cargo slot: a child of the pack with a capacity-1 inventory, a probe interactable and the stowed item's visual";
}
struct FMars_Feature_CargoSlot {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// What interacting with a slot would do for a given focuser (Get_ActionFor). Only Stow and Take enable the slot's
// interact target; every Blocked_ reason keeps the prompt visible with the reason and E does nothing.
enum EMars_CargoSlot_Action
{
    Stow,
    Take,
    Blocked_NothingHeld,
    Blocked_NotStowable,
    Blocked_SlotOccupied,
    Blocked_NoRoom,
    Blocked_PackHeld
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_cargo_slot
{
    // Beats the pack's own pickup (0), whose probe sphere encloses the cargo probes under the same view ray.
    const int32 k_FocusPriority = 10;

    // The point a slot publishes on its own node for a stowed Persistent item to be carried on. Attach points are looked up
    // on the carrier, so the dock's tag names the slot's node here; no slot has a second point.
    FGameplayTag Get_MountPoint() { return GameplayTags::AttachPoint_Mars_Dock; }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Resolved by the Backpack entity script from the item's FMars_CargoSlot_Mount (socket already applied); utils_backpack::Add
// fills in Backpack.
struct FMars_CargoSlot_Spec
{
    // 0..7 (Inventory.Mars.Cargo.<Index>).
    UPROPERTY()
    int32 Index = 0;

    // Relative to the pack root.
    UPROPERTY()
    FTransform MountOffset = FTransform::Identity;

    UPROPERTY()
    float32 ProbeRadius = 12.0f;

    // The pack's world item (its Mount decides Blocked_PackHeld); the slot is created under its root.
    UPROPERTY()
    FCk_Handle_WorldItem Backpack;
}

// Index in [0, 7] (the Inventory.Mars.Cargo.N tags only go that far), ProbeRadius > 0, a valid Backpack.
mixin FMars_Validation Validate(const FMars_CargoSlot_Spec& Self)
{
    if (Self.Index < 0 || Self.Index > 7)
    { return FMars_Validation(f"Index [{Self.Index}] is outside [0, 7] - Inventory.Mars.Cargo.N tags only go that far"); }

    if (Self.ProbeRadius <= 0.0f)
    { return FMars_Validation(f"slot [{Self.Index}] has a non-positive ProbeRadius [{Self.ProbeRadius}]"); }

    if (ck::Is_NOT_Valid(Self.Backpack))
    { return FMars_Validation(f"slot [{Self.Index}] has no Backpack"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_CargoSlot_Params
{
    UPROPERTY()
    FCk_Handle_WorldItem Backpack;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Inventory and Interactable are composed by utils_cargo_slot::Create. Visual and LastSeen are written only by
// UMars_Processor_CargoSlot_Sync, PendingArrival by the request drain and the sync, LastPromptAction only by
// UMars_Processor_CargoSlot_Prompt.
struct FMars_Fragment_CargoSlot
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Inventory;

    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    // The Visual-mode world item of the stowed item; invalid while empty. Owned by the slot entity.
    UPROPERTY()
    FCk_Handle Visual;

    // The item the slot held on the previous sync pass; the content is polled, not bound.
    UPROPERTY()
    FCk_Handle_Item LastSeen;

    // Where a stowed item visually was; its cargo visual starts there.
    UPROPERTY()
    TOptional<FMars_WorldItem_PendingArrival> PendingArrival;

    // The action the prompt currently shows; unset while the slot is not focused.
    UPROPERTY()
    TOptional<EMars_CargoSlot_Action> LastPromptAction;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_CargoSlot_OnItemChanged(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InMaybeItem);
event void FMars_Delegate_CargoSlot_OnItemChanged_MC(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InMaybeItem);

// A Stow or Take of InItem was refused (by the drain or by the inventory); the item did not move.
delegate void FMars_Delegate_CargoSlot_OnTransferFailed(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InItem);
event void FMars_Delegate_CargoSlot_OnTransferFailed_MC(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InItem);

struct FMars_Fragment_CargoSlot_Signals
{
    FMars_Delegate_CargoSlot_OnItemChanged_MC OnItemChanged;
    FMars_Delegate_CargoSlot_OnTransferFailed_MC OnTransferFailed;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Item.Get_ParentInventory() -> this slot.
struct FMars_Request_CargoSlot_Stow
{
    UPROPERTY()
    FCk_Handle_Item Item;

    // Where the item visually is now; its cargo visual lerps in from there. Unset = it appears at rest.
    UPROPERTY()
    TOptional<FTransform> ArriveFrom;

    FMars_Request_CargoSlot_Stow() {}

    FMars_Request_CargoSlot_Stow(const FCk_Handle_Item& InItem)
    {
        Item = InItem;
    }

    FMars_Request_CargoSlot_Stow(const FCk_Handle_Item& InItem, const FTransform& InArriveFrom)
    {
        Item = InItem;
        ArriveFrom = TOptional<FTransform>(InArriveFrom);
    }
}

// This slot -> Target.
struct FMars_Request_CargoSlot_Take
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Target;

    FMars_Request_CargoSlot_Take() {}

    FMars_Request_CargoSlot_Take(const FCk_Handle_Item& InItem, const FCk_Handle_Inventory_DataOnly& InTarget)
    {
        Item = InItem;
        Target = InTarget;
    }
}

// Drain order Stow -> Take (see UMars_Processor_CargoSlot_HandleRequests).
struct FMars_Fragment_CargoSlot_Requests
{
    UPROPERTY()
    TArray<FMars_Request_CargoSlot_Stow> StowRequests;

    UPROPERTY()
    TArray<FMars_Request_CargoSlot_Take> TakeRequests;
}
