//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HeldItemHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_HeldItem";
    RequiredFragments.Add(FMars_Feature_HeldItem);
    Description = "The item in the player's hands, derived from the selected hotbar slot, and its first-person held visual";
}
struct FMars_Feature_HeldItem {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// Who owns the held item's presentation entity.
enum EMars_HeldItem_PresentationOwnership
{
    // The Visual-mode world item HeldItem spawned: destroyed when the held item changes.
    Owned,
    // A Persistent item's own World-mode world item: asked to Carry when the held item changes, never destroyed.
    Borrowed
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Derived, never authored: the hotbar's selected slot and its item. PresentationEntity is recorded synchronously at spawn
// so a faster re-equip can still destroy it; its ownership is recorded with it, because the item it was spawned for may
// be gone by the time it is replaced.
struct FMars_Fragment_HeldItem
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly CurrentInventory;

    UPROPERTY()
    FCk_Handle_Item CurrentItem;

    UPROPERTY()
    FCk_Handle PresentationEntity;

    UPROPERTY()
    EMars_HeldItem_PresentationOwnership PresentationOwnership = EMars_HeldItem_PresentationOwnership::Owned;

    // One-shot: the next held visual spawns at this world pose and keeps that offset from the hand (an item picked up by
    // the first-person gloves starts where it lay and rides in with them). Wins over NextArrival.
    UPROPERTY()
    TOptional<FTransform> NextSpawnFrom;

    // One-shot: the next held visual of this item starts at this world pose and lerps to its hold offset (an item taken
    // out of a cargo slot).
    UPROPERTY()
    TOptional<FMars_WorldItem_PendingArrival> NextArrival;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_HeldItem_OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew);
event void FMars_Delegate_HeldItem_OnHeldItemChanged_MC(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew);

struct FMars_Fragment_HeldItem_Signals
{
    FMars_Delegate_HeldItem_OnHeldItemChanged_MC OnHeldItemChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_HeldItem_SetSlot
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Inventory;

    UPROPERTY()
    FCk_Handle_Item Item;

    FMars_Request_HeldItem_SetSlot() {}

    FMars_Request_HeldItem_SetSlot(const FCk_Handle_Inventory_DataOnly& InInventory, const FCk_Handle_Item& InItem)
    {
        Inventory = InInventory;
        Item = InItem;
    }
}

struct FMars_Request_HeldItem_SetNextSpawnFrom
{
    UPROPERTY()
    FTransform WorldTransform;

    FMars_Request_HeldItem_SetNextSpawnFrom() {}

    FMars_Request_HeldItem_SetNextSpawnFrom(const FTransform& InWorldTransform)
    {
        WorldTransform = InWorldTransform;
    }
}

// AngelScript rejects a TArray of an empty struct, so it carries one placeholder field.
struct FMars_Request_HeldItem_ClearNextSpawnFrom
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_HeldItem_ClearNextSpawnFrom() {}
}

struct FMars_Request_HeldItem_SetNextArrival
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FTransform World;

    FMars_Request_HeldItem_SetNextArrival() {}

    FMars_Request_HeldItem_SetNextArrival(const FCk_Handle_Item& InItem, const FTransform& InWorld)
    {
        Item = InItem;
        World = InWorld;
    }
}

// Drained ClearNextSpawnFrom -> SetNextSpawnFrom -> SetNextArrival -> SetSlot, the latest of each kind winning. A start pose
// is always requested before the slot change it animates, and Request_ClearNextSpawnFrom drops a not-yet-drained
// SetNextSpawnFrom, so arrival order survives the per-kind drain.
struct FMars_Fragment_HeldItem_Requests
{
    UPROPERTY()
    TArray<FMars_Request_HeldItem_ClearNextSpawnFrom> ClearNextSpawnFromRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItem_SetNextSpawnFrom> SetNextSpawnFromRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItem_SetNextArrival> SetNextArrivalRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItem_SetSlot> SetSlotRequests;
}
