//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HeldItemUseHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_HeldItemUse";
    RequiredFragments.Add(FMars_Feature_HeldItemUse);
    Description = "Uses, drops and throws the item in the player's hands through a no-probe interactable on the player";
}
struct FMars_Feature_HeldItemUse {}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_held_item_use
{
    // Used when the held item has no Throwable trait.
    const float32 k_DefaultDropSpeed = 150.0f;
    const float32 k_DefaultThrowSpeed = 900.0f;

    // Spawn distance in front of the view when the player has no hand attach point.
    const float32 k_NoHandSpawnDistance = 60.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Lives on the player. CurrentInteractable is the no-probe interactable whose single Primary.UsableItem target runs the
// held item's UseAction state; it is rebuilt whenever the held item changes.
struct FMars_Fragment_HeldItemUse
{
    UPROPERTY()
    FCk_Handle_Interactable CurrentInteractable;

    // HUD-only: set by the drop/throw input task once Drop has been held past the throw threshold, read by the
    // action-hint task. Written immediately (not a request) and never read by gameplay.
    UPROPERTY()
    bool ThrowArmed = false;

    // The item a drop/throw already launched. Its world item adopts it a frame or more later, so a second launch of
    // the same item before the held item changes would spawn a world item whose adopt fails.
    UPROPERTY()
    FCk_Handle_Item LaunchedItem;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_HeldItemUse_RefreshFromHeldItem
{
    UPROPERTY()
    bool Requested = true;
}

struct FMars_Request_HeldItemUse_Drop
{
    UPROPERTY()
    bool Requested = true;
}

struct FMars_Request_HeldItemUse_Throw
{
    UPROPERTY()
    bool Requested = true;
}

// Latest wins per kind; drained Refresh -> Drop -> Throw.
struct FMars_Fragment_HeldItemUse_Requests
{
    UPROPERTY()
    TOptional<FMars_Request_HeldItemUse_RefreshFromHeldItem> RefreshFromHeldItem;

    UPROPERTY()
    TOptional<FMars_Request_HeldItemUse_Drop> Drop;

    UPROPERTY()
    TOptional<FMars_Request_HeldItemUse_Throw> Throw;
}
