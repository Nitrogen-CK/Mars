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
    // A Persistent item's own World-mode world item: never destroyed here; it mounts where its item lives
    // (UMars_Processor_WorldItem_Reconcile).
    Borrowed
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Derived, never authored: the hotbar's selected slot and its item, synced every pass by UMars_Processor_HeldItem_Sync.
// PresentationEntity is recorded synchronously at spawn so a faster re-equip can still destroy it; its ownership is
// recorded with it, because the item it was spawned for may be gone by the time it is replaced.
struct FMars_Fragment_HeldItem
{
    // The carrier's own hotbar (set by Add): the one source of what is held.
    UPROPERTY()
    FCk_Handle_Hotbar Hotbar;

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

// Drained ClearNextSpawnFrom -> SetNextSpawnFrom -> SetNextArrival, the latest of each kind winning, before the sync pass
// that spawns a held visual. A start pose is always requested before the slot change it animates, and
// Request_ClearNextSpawnFrom drops a not-yet-drained SetNextSpawnFrom, so arrival order survives the per-kind drain.
struct FMars_Fragment_HeldItem_Requests
{
    UPROPERTY()
    TArray<FMars_Request_HeldItem_ClearNextSpawnFrom> ClearNextSpawnFromRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItem_SetNextSpawnFrom> SetNextSpawnFromRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItem_SetNextArrival> SetNextArrivalRequests;
}
