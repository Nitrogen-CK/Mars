// One keyhole: a capacity-1 inventory that takes only the key whose KeyId is the lock's AcceptedKey, a Visual-mode world
// item of the key it holds on the caller's KeyMount node, and the caller's interactable, whose Use target inserts the held
// key or takes the inserted one back. Holding its key is being unlocked: a MechanismSource on the same entity asserts while
// it does (UMars_Processor_KeyLock_Sync), so doors that need several keys are Sink rules over several locks. The CargoSlot
// shape for a keyhole; nothing here reads "the local player".
//
// Stance: on a replicated host the inventory replicates with it, and so does the refusal ledger
// (FMars_Fragment_KeyLock_Net). A machine acts through utils_key_lock::Request_ActFor, which fires Cue.Mars.KeyLock.Act at
// the host; only the authority moves a key (the drain drops Insert, Take and Act elsewhere). The key visual, LastSeen and
// the signals follow the replicated contents on every machine; only the authority drives the MechanismSource.

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

    // The inventory's replication: the host's own. Only a host with a replication driver replicates; a replicated
    // inventory on a host without one cannot create an item. (The refusal ledger always replicates: on a host
    // without a driver it simply has nowhere to go.)
    UPROPERTY()
    ECk_Replication Replication = ECk_Replication::DoesNotReplicate;
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

// The authority's refusal ledger on the lock, replicated with it. The serial advances once per refused Act, so an
// initiator that recorded it before its cue knows a newer refusal is about its own. Written only by the request drain.
struct FMars_Fragment_KeyLock_Net
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
struct FMars_Fragment_KeyLock_PendingAct
{
    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    FCk_Handle_Item Item;

    FMars_Fragment_KeyLock_PendingAct() {}

    FMars_Fragment_KeyLock_PendingAct(const FCk_Handle& InInitiator, const FCk_Handle_Item& InItem)
    {
        Initiator = InInitiator;
        Item = InItem;
    }
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

    FMars_Request_KeyLock_Insert() {}

    FMars_Request_KeyLock_Insert(const FCk_Handle_Item& InItem)
    {
        Item = InItem;
    }
}

// Presentation, drained on every machine: when Item next lands in the lock, its visual lerps in from From.
struct FMars_Request_KeyLock_ExpectArrival
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FTransform From = FTransform::Identity;

    FMars_Request_KeyLock_ExpectArrival() {}

    FMars_Request_KeyLock_ExpectArrival(const FCk_Handle_Item& InItem, const FTransform& InFrom)
    {
        Item = InItem;
        From = InFrom;
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

// What Initiator's interaction asks of the lock, resolved on the authority from the initiator's side: refused
// (ActionBlocked) unless Get_ActionFor(Initiator) is still Action there. The spawn params of Cue.Mars.KeyLock.Act.
struct FMars_Request_KeyLock_Act
{
    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    EMars_KeyLock_Action Action = EMars_KeyLock_Action::Insert;

    FMars_Request_KeyLock_Act() {}

    FMars_Request_KeyLock_Act(const FCk_Handle& InInitiator, EMars_KeyLock_Action InAction)
    {
        Initiator = InInitiator;
        Action = InAction;
    }
}

// Drain order ExpectArrival -> Insert -> Take -> Act (see UMars_Processor_KeyLock_HandleRequests).
struct FMars_Fragment_KeyLock_Requests
{
    UPROPERTY()
    TArray<FMars_Request_KeyLock_ExpectArrival> ExpectArrivalRequests;

    UPROPERTY()
    TArray<FMars_Request_KeyLock_Insert> InsertRequests;

    UPROPERTY()
    TArray<FMars_Request_KeyLock_Take> TakeRequests;

    UPROPERTY()
    TArray<FMars_Request_KeyLock_Act> ActRequests;
}
