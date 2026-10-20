// One keyhole: a capacity-1 inventory that takes only the key whose KeyId is the lock's AcceptedKey, a Visual-mode world
// item of the key it holds on the caller's KeyMount node, and the caller's interactable, whose Use target inserts the held
// key or takes the inserted one back. Holding its key is being unlocked: a MechanismSource on the same entity asserts while
// it does (UMars_Processor_KeyLock_Sync), so doors that need several keys are Sink rules over several locks. The CargoSlot
// shape for a keyhole; nothing here reads "the local player".

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_KeyLockHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_KeyLock";
    RequiredFragments.Add(FMars_Feature_KeyLock);
    Description = "One keyhole: a capacity-1 inventory taking only its AcceptedKey, the inserted key's visual, and an optional MechanismSource asserted while unlocked";
}
struct FMars_Feature_KeyLock {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_KeyLock_Release
{
    // An inserted key stays in for good.
    Kept,
    // An inserted key can be taken back out, which locks the lock again.
    Removable
}

// What interacting with a lock would do for a given focuser (Get_ActionFor). Only Insert and Take enable the lock's
// interact target; every Blocked_ reason keeps the prompt visible with the reason and E does nothing.
enum EMars_KeyLock_Action
{
    Insert,
    Take,
    Blocked_NothingHeld,
    Blocked_WrongKey,
    Blocked_KeyKept,
    Blocked_HandsFull,
    Blocked_NoRoom
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_key_lock
{
    // Beats a world item's pickup (0), so a key dropped under the keyhole does not steal the prompt.
    const int32 k_FocusPriority = 10;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_KeyLock_Spec
{
    UPROPERTY(meta = (Categories = "Key.Mars"))
    FGameplayTag AcceptedKey;

    UPROPERTY()
    EMars_KeyLock_Release Release = EMars_KeyLock_Release::Kept;

    // The node the inserted key's visual rides, at its origin; the caller orients it so the key's +X points into the
    // keyhole.
    UPROPERTY()
    FCk_Handle_Transform KeyMount;

    // The keyhole's interactable, built by the caller with utils_key_lock::Make_InteractTarget as its one target.
    UPROPERTY()
    FCk_Handle_Interactable Interactable;
}

mixin FMars_Validation Validate(const FMars_KeyLock_Spec& Self)
{
    if (Self.AcceptedKey.IsValid() == false)
    { return FMars_Validation("AcceptedKey must be set"); }

    if (ck::Is_NOT_Valid(Self.KeyMount))
    { return FMars_Validation(f"the [{Self.AcceptedKey}] lock has no KeyMount"); }

    if (ck::Is_NOT_Valid(Self.Interactable))
    { return FMars_Validation(f"the [{Self.AcceptedKey}] lock has no Interactable"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_KeyLock_Params
{
    UPROPERTY()
    FGameplayTag AcceptedKey;

    UPROPERTY()
    EMars_KeyLock_Release Release = EMars_KeyLock_Release::Kept;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Inventory is composed by utils_key_lock::Add. Visual and LastSeen are written only by UMars_Processor_KeyLock_Sync,
// PendingArrival by the request drain and the sync.
struct FMars_Fragment_KeyLock
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Inventory;

    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    UPROPERTY()
    FCk_Handle_Transform KeyMount;

    // The Visual-mode world item of the inserted key; invalid while empty. Owned by the lock entity.
    UPROPERTY()
    FCk_Handle Visual;

    // The key the lock held on the previous sync pass; the content is polled, not bound.
    UPROPERTY()
    FCk_Handle_Item LastSeen;

    // Where an inserted key visually was; its visual in the lock starts there.
    UPROPERTY()
    TOptional<FMars_WorldItem_PendingArrival> PendingArrival;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// InMaybeKey is the key now in the lock; invalid = it was taken out (locked again).
delegate void FMars_Delegate_KeyLock_OnKeyChanged(FCk_Handle_KeyLock InLock, FCk_Handle_Item InMaybeKey);
event void FMars_Delegate_KeyLock_OnKeyChanged_MC(FCk_Handle_KeyLock InLock, FCk_Handle_Item InMaybeKey);

// An Insert or Take of InItem was refused (by the drain or by the inventory); the item did not move.
delegate void FMars_Delegate_KeyLock_OnTransferFailed(FCk_Handle_KeyLock InLock, FCk_Handle_Item InItem);
event void FMars_Delegate_KeyLock_OnTransferFailed_MC(FCk_Handle_KeyLock InLock, FCk_Handle_Item InItem);

struct FMars_Fragment_KeyLock_Signals
{
    FMars_Delegate_KeyLock_OnKeyChanged_MC OnKeyChanged;
    FMars_Delegate_KeyLock_OnTransferFailed_MC OnTransferFailed;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Item.Get_ParentInventory() -> this lock. Refused unless the lock is empty and Item is its key.
struct FMars_Request_KeyLock_Insert
{
    UPROPERTY()
    FCk_Handle_Item Item;

    // Where the key visually is now; its visual in the lock lerps in from there. Unset = it appears at rest.
    UPROPERTY()
    TOptional<FTransform> ArriveFrom;

    FMars_Request_KeyLock_Insert() {}

    FMars_Request_KeyLock_Insert(const FCk_Handle_Item& InItem)
    {
        Item = InItem;
    }

    FMars_Request_KeyLock_Insert(const FCk_Handle_Item& InItem, const FTransform& InArriveFrom)
    {
        Item = InItem;
        ArriveFrom = TOptional<FTransform>(InArriveFrom);
    }
}

// This lock -> Target. Refused by a Kept lock.
struct FMars_Request_KeyLock_Take
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Target;

    FMars_Request_KeyLock_Take() {}

    FMars_Request_KeyLock_Take(const FCk_Handle_Item& InItem, const FCk_Handle_Inventory_DataOnly& InTarget)
    {
        Item = InItem;
        Target = InTarget;
    }
}

// Drain order Insert -> Take (see UMars_Processor_KeyLock_HandleRequests).
struct FMars_Fragment_KeyLock_Requests
{
    UPROPERTY()
    TArray<FMars_Request_KeyLock_Insert> InsertRequests;

    UPROPERTY()
    TArray<FMars_Request_KeyLock_Take> TakeRequests;
}
