// A station's mount for one platter: a child entity of the station root with its own capacity-1 inventory, an attach point
// the docked platter's world item is carried on, a probe-driven interactable and a policy on what the platter may bring.
// The dock mounts the platter's one live entity (a Persistent world item); it never spawns a visual, and it ends the
// platter only when it is torn down with it docked (the platter's item lives in the dock's inventory and dies with it).
// Anyone who can aim at the dock can place onto it or take from it; nothing here reads "the local player".

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PlatterDockHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_PlatterDock";
    RequiredFragments.Add(FMars_Feature_PlatterDock);
    Description = "A station's mount for one platter: a child of the station with a capacity-1 inventory, an attach point, a probe interactable and a policy on what the platter may bring";
}
struct FMars_Feature_PlatterDock {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_PlatterDock_Role
{
    Input,
    Output
}

// Why a platter was not docked. Never deferred.
enum EMars_PlatterDock_Refusal
{
    Occupied,
    NotAPlatter,
    KindRejected,
    NotWhole,
    MustBeEmpty,
    MustHaveFood,
    // The item is in no inventory, or the transfer was refused.
    TransferFailed,
    // A food placed on the docked platter would not fit.
    PlatterFull
}

// What interacting would do for a given focuser (Get_ActionFor). Only Place, Take and PlaceFood enable the dock's interact
// target; every Blocked_ reason keeps the prompt visible with the reason and E does nothing.
enum EMars_PlatterDock_Action
{
    Place,
    Take,
    Blocked_NothingHeld,
    Blocked_NotAPlatter,
    Blocked_Policy,
    Blocked_HandsFull,
    // The focuser holds food and a platter is docked: the food goes onto the docked platter.
    PlaceFood
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_platter_dock
{
    // Beats the station's own Use (0), whose probe box encloses the docks.
    const int32 k_FocusPriority = 10;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// What a dock lets a platter bring, never how much: every held piece must match Kind (an empty query = any); WholeOnly =
// every piece whole; RequireEmpty set = the platter must (true) or must not (false) be empty. How many pieces a station
// takes is its kernel's own limit.
struct FMars_PlatterDock_Policy
{
    UPROPERTY()
    FGameplayTagQuery Kind;

    UPROPERTY()
    bool WholeOnly = false;

    UPROPERTY()
    TOptional<bool> RequireEmpty;

    FMars_PlatterDock_Policy() {}

    FMars_PlatterDock_Policy(FGameplayTagQuery InKind, bool InWholeOnly)
    {
        Kind = InKind;
        WholeOnly = InWholeOnly;
    }
}

// What a dock's prompt says to one focuser (utils_platter_dock::Get_PromptText).
struct FMars_PlatterDock_PromptQuery
{
    UPROPERTY()
    EMars_PlatterDock_Action Action = EMars_PlatterDock_Action::Blocked_NothingHeld;

    // Blocked_Policy: the policy's reason.
    UPROPERTY()
    TOptional<EMars_PlatterDock_Refusal> Refusal;

    // PlaceFood: the held food's name.
    UPROPERTY()
    FText FoodName;
}

// What each of a station's two docks lets a platter bring: the input platter it draws from and the finished tray it fills.
struct FMars_Station_DockPolicies
{
    UPROPERTY()
    FMars_PlatterDock_Policy Input;

    UPROPERTY()
    FMars_PlatterDock_Policy Output;
}

struct FMars_PlatterDock_Spec
{
    UPROPERTY()
    EMars_PlatterDock_Role Role = EMars_PlatterDock_Role::Input;

    UPROPERTY()
    FMars_PlatterDock_Policy Policy;

    UPROPERTY()
    float32 ProbeRadius = 18.0f;

    // What the prompt calls the dock ("input platter", "finished tray").
    UPROPERTY()
    FText Name;

    // The dock's pose in the station root's frame; the dock's node is created there.
    UPROPERTY()
    FTransform MountLocal = FTransform::Identity;

    // The prompt's reason when the Kind query refuses a piece ("Meat only"); the other refusals have fixed texts.
    UPROPERTY()
    FText KindRejectedText;

    FMars_PlatterDock_Spec() {}

    FMars_PlatterDock_Spec(EMars_PlatterDock_Role InRole, const FMars_PlatterDock_Policy& InPolicy, const FTransform& InMountLocal)
    {
        Role = InRole;
        Policy = InPolicy;
        MountLocal = InMountLocal;
    }
}

// A probe needs a radius and the prompt a name; a non-finite pose has no place to mount.
mixin FMars_Validation Validate(const FMars_PlatterDock_Spec& Self)
{
    if (Self.ProbeRadius <= 0.0f)
    { return FMars_Validation(f"PlatterDock has a non-positive ProbeRadius [{Self.ProbeRadius}]"); }

    if (Self.Name.IsEmpty())
    { return FMars_Validation("PlatterDock has no Name for its prompt"); }

    if (Self.MountLocal.ContainsNaN())
    { return FMars_Validation("PlatterDock's MountLocal is not a finite transform"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_PlatterDock_Params
{
    UPROPERTY()
    FMars_PlatterDock_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Inventory, Interactable and Node are composed by utils_platter_dock::Create. WorldItem, Platter, LastSeen and HasArrived
// are written only by UMars_Processor_PlatterDock_Sync from what the inventory holds and where its world item is (polled,
// as a cargo slot is), LastPromptAction only by UMars_Processor_PlatterDock_Prompt.
struct FMars_Fragment_PlatterDock
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Inventory;

    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    // The dock entity itself: the node a docked platter's root is attached to.
    UPROPERTY()
    FCk_Handle_Transform Node;

    // The docked platter's world item and kernel; invalid while empty (as of the last sync pass).
    UPROPERTY()
    FCk_Handle_WorldItem WorldItem;

    UPROPERTY()
    FCk_Handle_Platter Platter;

    // The item the dock held on the previous sync pass; the content is polled, not bound.
    UPROPERTY()
    FCk_Handle_Item LastSeen;

    // The docked platter's world item has landed on the node (Carried here, no arrival in flight); reset on every undock.
    UPROPERTY()
    bool HasArrived = false;

    // The action the prompt currently shows; unset while the dock is not focused.
    UPROPERTY()
    TOptional<EMars_PlatterDock_Action> LastPromptAction;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// The dock's inventory took the platter's item; its world item is on the way to the dock (Carry).
delegate void FMars_Delegate_PlatterDock_OnDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter);
event void FMars_Delegate_PlatterDock_OnDocked_MC(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter);

// The docked platter landed: its world item reads Carried by the dock with no arrival in flight. Once per dock; a station
// takes from a platter only from here on.
delegate void FMars_Delegate_PlatterDock_OnArrived(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter);
event void FMars_Delegate_PlatterDock_OnArrived_MC(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter);

// The dock's inventory let the platter's item go.
delegate void FMars_Delegate_PlatterDock_OnUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter);
event void FMars_Delegate_PlatterDock_OnUndocked_MC(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter);

// A Dock of InItem was refused (by the drain or by the inventory); the item did not move.
delegate void FMars_Delegate_PlatterDock_OnDockRefused(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal);
event void FMars_Delegate_PlatterDock_OnDockRefused_MC(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal);

struct FMars_Fragment_PlatterDock_Signals
{
    FMars_Delegate_PlatterDock_OnDocked_MC OnDocked;
    FMars_Delegate_PlatterDock_OnArrived_MC OnArrived;
    FMars_Delegate_PlatterDock_OnUndocked_MC OnUndocked;
    FMars_Delegate_PlatterDock_OnDockRefused_MC OnDockRefused;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Item.Get_ParentInventory() -> this dock's inventory, then the platter's world item is asked to Carry onto the dock's
// node. Refused (never deferred) with OnDockRefused when the dock, the policy or the inventory says no.
struct FMars_Request_PlatterDock_Dock
{
    UPROPERTY()
    FCk_Handle_Item Item;

    FMars_Request_PlatterDock_Dock() {}

    FMars_Request_PlatterDock_Dock(const FCk_Handle_Item& InItem)
    {
        Item = InItem;
    }
}

// This dock's inventory -> Target (the taker's hotbar stow target). The hotbar's arrival then holds it.
struct FMars_Request_PlatterDock_Undock
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Target;

    FMars_Request_PlatterDock_Undock() {}

    FMars_Request_PlatterDock_Undock(const FCk_Handle_Item& InItem, const FCk_Handle_Inventory_DataOnly& InTarget)
    {
        Item = InItem;
        Target = InTarget;
    }
}

// Drain order Dock -> Undock (see UMars_Processor_PlatterDock_HandleRequests).
struct FMars_Fragment_PlatterDock_Requests
{
    UPROPERTY()
    TArray<FMars_Request_PlatterDock_Dock> DockRequests;

    UPROPERTY()
    TArray<FMars_Request_PlatterDock_Undock> UndockRequests;
}
