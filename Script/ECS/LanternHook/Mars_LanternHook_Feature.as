// A hook for one lantern: a capacity-1 inventory that takes only lanterns (items with UMars_ItemTrait_Lantern and a
// Persistent world item), published as AttachPoint.Mars.Hook on the caller's HangNode, so the hung lantern's one live
// entity mounts there (UMars_Processor_WorldItem_Reconcile) and lights its World pool (Get_LightPool). The caller's
// interactable's Use target hangs the held lantern, takes the hung one back, or feeds it the held tallow. Holding a lit
// lantern asserts an optional MechanismSource on the same entity (UMars_Processor_LanternHook_Sync), so "light the two
// sconces" is a Sink rule over two hooks. The KeyLock shape for a lantern; nothing here reads "the local player".
//
// Stance: on a replicated host the inventory replicates with it, and so does the refusal ledger
// (FMars_Fragment_LanternHook_Net). A machine acts through utils_lantern_hook::Request_ActFor, which fires
// Cue.Mars.LanternHook.Act at the host; only the authority hangs, takes or refuels (the drain drops Hang, Take, Refuel and
// Act elsewhere). The hung lantern mounts on each machine's own hang node from the replicated contents; LastSeen and the
// signals follow them on every machine; only the authority drives the MechanismSource.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_LanternHookHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_LanternHook";
    RequiredFragments.Add(FMars_Feature_LanternHook);
    Description = "A hook for one lantern: a capacity-1 inventory taking only lanterns, the attach point a hung lantern rides, and an optional MechanismSource asserted while it holds a lit lantern";
}
struct FMars_Feature_LanternHook {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// What interacting with a hook would do for a given focuser (Get_ActionFor). Only Hang, Take and Refuel enable the hook's
// interact target; every Blocked_ reason keeps the prompt visible with the reason and E does nothing.
enum EMars_LanternHook_Action
{
    Hang,
    Take,
    // The focuser holds tallow and the hung lantern has room for it.
    Refuel,
    Blocked_NothingHeld,
    Blocked_NotALantern,
    Blocked_HandsFull,
    Blocked_NoRoom,
    // The focuser holds tallow and the hung lantern is full.
    Blocked_Full
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_lantern_hook
{
    // Beats a world item's pickup (0), so the hung lantern's own pickup never steals the hook's prompt.
    const int32 k_FocusPriority = 10;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_LanternHook_Spec
{
    // The node a hung lantern rides, published as AttachPoint.Mars.Hook on the hook entity; the caller places it where
    // the bail hangs.
    UPROPERTY()
    FCk_Handle_Transform HangNode;

    // The hung lantern's root on HangNode (the caller drops it by the lantern's bail height).
    UPROPERTY()
    FTransform HangOffset = FTransform::Identity;

    // The hook's interactable, built by the caller with utils_lantern_hook::Make_InteractTarget as its one target.
    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    // The host's own replication, which the inventory and the refusal ledger follow. Only a host with a replication
    // driver replicates; a replicated inventory on a host without one cannot create an item.
    UPROPERTY()
    ECk_Replication Replication = ECk_Replication::DoesNotReplicate;
}

mixin FMars_Validation Validate(const FMars_LanternHook_Spec& Self)
{
    if (ck::Is_NOT_Valid(Self.HangNode))
    { return FMars_Validation("LanternHook has no HangNode"); }

    if (ck::Is_NOT_Valid(Self.Interactable))
    { return FMars_Validation("LanternHook has no Interactable"); }

    if (Self.HangOffset.ContainsNaN())
    { return FMars_Validation("LanternHook's HangOffset is not a finite transform"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Inventory, Interactable and HangNode are composed by utils_lantern_hook::Add. LastSeen and LastOutput are written only
// by UMars_Processor_LanternHook_Sync.
struct FMars_Fragment_LanternHook
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Inventory;

    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    UPROPERTY()
    FCk_Handle_Transform HangNode;

    // The lantern item the hook held on the previous sync pass; the content is polled, not bound.
    UPROPERTY()
    FCk_Handle_Item LastSeen;

    // What the sync last asked of the same-entity MechanismSource; unset before its first pass.
    UPROPERTY()
    TOptional<EMars_MechanismSource_Output> LastOutput;
}

// The authority's refusal ledger on the hook, replicated with it. The serial advances once per refused Act, so an
// initiator that recorded it before its cue knows a newer refusal is about its own. Written only by the request drain.
struct FMars_Fragment_LanternHook_Net
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
struct FMars_Fragment_LanternHook_PendingAct
{
    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    FCk_Handle_Item Item;

    FMars_Fragment_LanternHook_PendingAct() {}

    FMars_Fragment_LanternHook_PendingAct(const FCk_Handle& InInitiator, const FCk_Handle_Item& InItem)
    {
        Initiator = InInitiator;
        Item = InItem;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// InMaybeLantern is the lantern item now on the hook; invalid = it was taken.
delegate void FMars_Delegate_LanternHook_OnLanternChanged(FCk_Handle_LanternHook InHook, FCk_Handle_Item InMaybeLantern);
event void FMars_Delegate_LanternHook_OnLanternChanged_MC(FCk_Handle_LanternHook InHook, FCk_Handle_Item InMaybeLantern);

// A Hang, Take or Refuel of InItem was refused (by the drain or by the inventory); nothing moved and no tallow was used.
delegate void FMars_Delegate_LanternHook_OnRequestFailed(FCk_Handle_LanternHook InHook, FCk_Handle_Item InItem);
event void FMars_Delegate_LanternHook_OnRequestFailed_MC(FCk_Handle_LanternHook InHook, FCk_Handle_Item InItem);

struct FMars_Fragment_LanternHook_Signals
{
    FMars_Delegate_LanternHook_OnLanternChanged_MC OnLanternChanged;
    FMars_Delegate_LanternHook_OnRequestFailed_MC OnRequestFailed;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Item.Get_ParentInventory() -> this hook. Refused unless the hook is empty and Item is a lantern.
struct FMars_Request_LanternHook_Hang
{
    UPROPERTY()
    FCk_Handle_Item Item;

    FMars_Request_LanternHook_Hang() {}

    FMars_Request_LanternHook_Hang(const FCk_Handle_Item& InItem)
    {
        Item = InItem;
    }
}

// This hook -> Target. Refused unless Item is the hung lantern.
struct FMars_Request_LanternHook_Take
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Target;

    FMars_Request_LanternHook_Take() {}

    FMars_Request_LanternHook_Take(const FCk_Handle_Item& InItem, const FCk_Handle_Inventory_DataOnly& InTarget)
    {
        Item = InItem;
        Target = InTarget;
    }
}

// Feeds Tallow's measures to the lantern the hook holds at the drain and uses the tallow up. Refused (the tallow is kept)
// when the hook is empty, its lantern is full or Tallow is no tallow in an inventory.
struct FMars_Request_LanternHook_Refuel
{
    UPROPERTY()
    FCk_Handle_Item Tallow;

    FMars_Request_LanternHook_Refuel() {}

    FMars_Request_LanternHook_Refuel(const FCk_Handle_Item& InTallow)
    {
        Tallow = InTallow;
    }
}

// What Initiator's interaction asks of the hook, resolved on the authority from the initiator's side: refused
// (ActionBlocked) unless Get_ActionFor(Initiator) is still Action there. The spawn params of Cue.Mars.LanternHook.Act.
struct FMars_Request_LanternHook_Act
{
    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    EMars_LanternHook_Action Action = EMars_LanternHook_Action::Hang;

    FMars_Request_LanternHook_Act() {}

    FMars_Request_LanternHook_Act(const FCk_Handle& InInitiator, EMars_LanternHook_Action InAction)
    {
        Initiator = InInitiator;
        Action = InAction;
    }
}

// Drain order Hang -> Take -> Refuel -> Act (see UMars_Processor_LanternHook_HandleRequests).
struct FMars_Fragment_LanternHook_Requests
{
    UPROPERTY()
    TArray<FMars_Request_LanternHook_Hang> HangRequests;

    UPROPERTY()
    TArray<FMars_Request_LanternHook_Take> TakeRequests;

    UPROPERTY()
    TArray<FMars_Request_LanternHook_Refuel> RefuelRequests;

    UPROPERTY()
    TArray<FMars_Request_LanternHook_Act> ActRequests;
}
