// One cargo slot of a backpack: an entity of its own under the pack (UMars_CargoSlot_EntityScript, attached under the
// pack root at its mount) with a capacity-1 inventory, a probe-driven interactable at its mount and a Visual-mode world
// item of whatever it holds; a stowed food item is no visual: its own Persistent world item is carried on the slot's node
// (the way a dock carries a platter). Anyone who can aim at the slot can stow into it or take out of it; nothing here
// reads "the local player".
//
// Stance: the slot entity replicates with its pack, and so do its inventory and its refusal ledger
// (FMars_Fragment_CargoSlot_Net); its transform is local, attached under the pack root on every machine. A machine acts
// through utils_cargo_slot::Request_ActFor, which fires Cue.Mars.CargoSlot.Act at the slot; only the authority moves an
// item (the drain drops Stow, Take and Act elsewhere). The cargo visual, LastSeen and the signals follow the replicated
// contents on every machine.

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

    // Slot indices run [0, k_MaxCount): the Inventory.Mars.Cargo.N tags only go that far.
    const int32 k_MaxCount = 8;

    // The point a slot publishes on its own node for a stowed Persistent item to be carried on. Attach points are looked up
    // on the carrier, so the dock's tag names the slot's node here; no slot has a second point.
    FGameplayTag Get_MountPoint() { return GameplayTags::AttachPoint_Mars_Dock; }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Resolved by the Backpack entity script from the item's FMars_CargoSlot_Mount (socket already applied) and kept on the
// pack; the slot's own script fills in Backpack and Replication.
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

    // The pack's world item (its Mount decides Blocked_PackHeld).
    UPROPERTY()
    FCk_Handle_WorldItem Backpack;

    // The slot's Use prompt (its input action and placeholder text): the assembly's words.
    UPROPERTY()
    FMars_InteractPrompt_Spec Prompt;

    // The inventory's replication: the slot entity's own. A replicated inventory on an entity without a replication
    // driver cannot create an item. (The refusal ledger always replicates: on an entity without a driver it simply
    // has nowhere to go.)
    UPROPERTY()
    ECk_Replication Replication = ECk_Replication::DoesNotReplicate;
}

// Index in [0, constants_cargo_slot::k_MaxCount), ProbeRadius > 0 and finite, a valid Backpack, a prompt input action.
mixin FMars_Validation Validate(const FMars_CargoSlot_Spec& Self)
{
    const auto LastIndex = constants_cargo_slot::k_MaxCount - 1;
    if (Self.Index < 0 || Self.Index > LastIndex)
    { return FMars_Validation(f"Index [{Self.Index}] is outside [0, {LastIndex}] - Inventory.Mars.Cargo.N tags only go that far"); }

    if (Math::IsFinite(Self.ProbeRadius) == false || Self.ProbeRadius <= 0.0f)
    { return FMars_Validation(f"slot [{Self.Index}] has a non-positive ProbeRadius [{Self.ProbeRadius}]"); }

    if (Self.Prompt.InputAction.IsNull())
    { return FMars_Validation(f"slot [{Self.Index}] has no prompt input action"); }

    if (ck::Is_NOT_Valid(Self.Backpack))
    { return FMars_Validation(f"slot [{Self.Index}] has no Backpack"); }

    return FMars_Validation();
}

// UMars_CargoSlot_EntityScript's spawn params: which of its pack's slots the script builds.
struct FMars_CargoSlot_SpawnParams
{
    UPROPERTY()
    int32 Index = 0;

    FMars_CargoSlot_SpawnParams() {}

    FMars_CargoSlot_SpawnParams(int32 InIndex)
    {
        Index = InIndex;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_CargoSlot_Params
{
    // The slot's place in its pack's layout (FMars_CargoSlot_Spec.Index).
    UPROPERTY()
    int32 Index = 0;

    UPROPERTY()
    FCk_Handle_WorldItem Backpack;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Inventory and Interactable are composed by utils_cargo_slot::Add. Visual and LastSeen are written only by
// UMars_Processor_CargoSlot_Sync, PendingArrival by the request drain and the sync.
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
}

// The authority's refusal ledger on the slot, replicated with it. The serial advances once per refused Act, so an
// initiator that recorded it before its cue knows a newer refusal is about its own. Written only by the request drain.
struct FMars_Fragment_CargoSlot_Net
{
    UPROPERTY()
    int32 RefusalSerial = 0;

    UPROPERTY()
    EMars_Interaction_FailReason LastRefusal = EMars_Interaction_FailReason::ActionBlocked;

    // The refused initiator, a player's entity. On a client it may arrive unresolved: that only means "not known here yet".
    UPROPERTY()
    FCk_Handle LastRefused;
}

// The Act whose transfer is in flight on the authority: who asked, so a refused transfer names them. Local; written only
// by the request drain.
struct FMars_Fragment_CargoSlot_PendingAct
{
    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    FCk_Handle_Item Item;

    FMars_Fragment_CargoSlot_PendingAct() {}

    FMars_Fragment_CargoSlot_PendingAct(const FCk_Handle& InInitiator, const FCk_Handle_Item& InItem)
    {
        Initiator = InInitiator;
        Item = InItem;
    }
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

    FMars_Request_CargoSlot_Stow() {}

    FMars_Request_CargoSlot_Stow(const FCk_Handle_Item& InItem)
    {
        Item = InItem;
    }
}

// Presentation, drained on every machine: when Item next lands in the slot, its cargo visual lerps in from From.
struct FMars_Request_CargoSlot_ExpectArrival
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FTransform From = FTransform::Identity;

    FMars_Request_CargoSlot_ExpectArrival() {}

    FMars_Request_CargoSlot_ExpectArrival(const FCk_Handle_Item& InItem, const FTransform& InFrom)
    {
        Item = InItem;
        From = InFrom;
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

// What Initiator's interaction asks of the slot, resolved on the authority from the initiator's side: refused
// (ActionBlocked) unless Get_ActionFor(Initiator) is still Action there. The spawn params of Cue.Mars.CargoSlot.Act.
struct FMars_Request_CargoSlot_Act
{
    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    EMars_CargoSlot_Action Action = EMars_CargoSlot_Action::Stow;

    FMars_Request_CargoSlot_Act() {}

    FMars_Request_CargoSlot_Act(const FCk_Handle& InInitiator, EMars_CargoSlot_Action InAction)
    {
        Initiator = InInitiator;
        Action = InAction;
    }
}

// Drain order ExpectArrival -> Stow -> Take -> Act (see UMars_Processor_CargoSlot_HandleRequests).
struct FMars_Fragment_CargoSlot_Requests
{
    UPROPERTY()
    TArray<FMars_Request_CargoSlot_ExpectArrival> ExpectArrivalRequests;

    UPROPERTY()
    TArray<FMars_Request_CargoSlot_Stow> StowRequests;

    UPROPERTY()
    TArray<FMars_Request_CargoSlot_Take> TakeRequests;

    UPROPERTY()
    TArray<FMars_Request_CargoSlot_Act> ActRequests;
}
