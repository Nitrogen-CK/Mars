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

    // HUD-only: requested by the drop/throw input task once Drop has been held past the throw threshold, read by the
    // action-hint task. Never read by gameplay - the input task decides throw-vs-drop from its own flag.
    UPROPERTY()
    bool ThrowArmed = false;

    // The item a drop/throw already launched. Its world item adopts it a frame or more later, so a second launch of
    // the same item before the held item changes would spawn a world item whose adopt fails.
    UPROPERTY()
    FCk_Handle_Item LaunchedItem;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_HeldItemUse_OnThrowArmedChanged(FCk_Handle_HeldItemUse InUse, bool InArmed);
event void FMars_Delegate_HeldItemUse_OnThrowArmedChanged_MC(FCk_Handle_HeldItemUse InUse, bool InArmed);

struct FMars_Fragment_HeldItemUse_Signals
{
    FMars_Delegate_HeldItemUse_OnThrowArmedChanged_MC OnThrowArmedChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// AngelScript rejects a TArray of an empty struct ("Subtype is an empty struct", Bind_TArray.cpp), so the payload-less
// requests carry one placeholder field.
struct FMars_Request_HeldItemUse_RefreshFromHeldItem
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_HeldItemUse_RefreshFromHeldItem() {}
}

struct FMars_Request_HeldItemUse_Drop
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_HeldItemUse_Drop() {}
}

struct FMars_Request_HeldItemUse_Throw
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_HeldItemUse_Throw() {}
}

struct FMars_Request_HeldItemUse_SetThrowArmed
{
    UPROPERTY()
    bool Armed = false;

    FMars_Request_HeldItemUse_SetThrowArmed() {}

    FMars_Request_HeldItemUse_SetThrowArmed(bool InArmed)
    {
        Armed = InArmed;
    }
}

// Drained Refresh -> Drop -> Throw -> SetThrowArmed; see the processor.
struct FMars_Fragment_HeldItemUse_Requests
{
    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_RefreshFromHeldItem> RefreshFromHeldItemRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_Drop> DropRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_Throw> ThrowRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_SetThrowArmed> SetThrowArmedRequests;
}
