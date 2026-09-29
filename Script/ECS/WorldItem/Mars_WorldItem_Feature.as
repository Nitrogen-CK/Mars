//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_WorldItemHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_WorldItem";
    RequiredFragments.Add(FMars_Feature_WorldItem);
    Description = "An item presented outside an inventory: pickable with physics in the world, or a visual in the player's hand";
}
struct FMars_Feature_WorldItem {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_WorldItem_Mode
{
    // Holder + Jolt body + pickup interactable + visual.
    World,
    // Visual only, scene-node attached to the hand. No holder, body, probe or interactable.
    HeldVisual
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_WorldItem_Params
{
    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    // Soft: fragments must not hold strong UObject refs.
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// World mode owns a capacity-1 holder and the item entity lives inside it, so pickup and drop are entity-preserving
// transfers. Every handle is invalid in HeldVisual mode except VisualRoot.
struct FMars_Fragment_WorldItem
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Holder;

    UPROPERTY()
    FCk_Handle_Interactable Pickup;

    UPROPERTY()
    FCk_Handle_JoltBody Body;

    UPROPERTY()
    FCk_Handle_Transform VisualRoot;
}

// A launch applied once the Jolt body exists; drained by UMars_Processor_WorldItem_Launch.
struct FMars_Fragment_WorldItem_PendingLaunch
{
    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;
}
