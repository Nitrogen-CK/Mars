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
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_HeldItem_Spec
{
    // The scene node the held visual is parented under.
    UPROPERTY()
    FCk_Handle_Transform HandAttachPoint;

    FMars_HeldItem_Spec() {}

    FMars_HeldItem_Spec(const FCk_Handle_Transform& InHandAttachPoint)
    {
        HandAttachPoint = InHandAttachPoint;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_HeldItem_Params
{
    UPROPERTY()
    FCk_Handle_Transform HandAttachPoint;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Derived, never authored: the hotbar's selected slot and its item. PresentationEntity is the HeldVisual world item,
// recorded synchronously at spawn so a faster re-equip can still destroy it.
struct FMars_Fragment_HeldItem
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly CurrentInventory;

    UPROPERTY()
    FCk_Handle_Item CurrentItem;

    UPROPERTY()
    FCk_Handle PresentationEntity;
}

// One-shot: the next held visual spawns at this world transform (instead of at its hold offset) and keeps that offset
// from the hand, e.g. an item picked up by the first-person gloves starts where it lay and rides in with them.
struct FMars_Fragment_HeldItem_SpawnFrom
{
    UPROPERTY()
    FTransform WorldTransform;
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

// Latest wins: back-to-back slot changes inside one frame collapse to the last one (see the processor).
struct FMars_Fragment_HeldItem_Requests
{
    UPROPERTY()
    TArray<FMars_Request_HeldItem_SetSlot> SetSlotRequests;
}
