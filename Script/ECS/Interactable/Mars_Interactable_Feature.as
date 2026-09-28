//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_InteractableHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Interactable";
    RequiredFragments.Add(FMars_Feature_Interactable);
    Description = "An entity that has the interactable feature set";
}
struct FMars_Feature_Interactable {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Interactable_OnFocused(FCk_Handle_Interactable InInteractableHandle, FCk_Handle InFocusedBy);
event void FMars_Delegate_Interactable_OnFocused_MC(FCk_Handle_Interactable InInteractableHandle, FCk_Handle InFocusedBy);

delegate void FMars_Delegate_Interactable_OnUnfocused(FCk_Handle_Interactable InInteractableHandle, FCk_Handle InUnfocusedBy);
event void FMars_Delegate_Interactable_OnUnfocused_MC(FCk_Handle_Interactable InInteractableHandle, FCk_Handle InUnfocusedBy);

delegate void FMars_Delegate_Interactable_OnInteractionStarted(FCk_Handle_Interactable InInteractableHandle, FCk_Handle_Interaction InInteraction);
event void FMars_Delegate_Interactable_OnInteractionStarted_MC(FCk_Handle_Interactable InInteractableHandle, FCk_Handle_Interaction InInteraction);

delegate void FMars_Delegate_Interactable_OnInteractionFinished(FCk_Handle_Interactable InInteractableHandle, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult);
event void FMars_Delegate_Interactable_OnInteractionFinished_MC(FCk_Handle_Interactable InInteractableHandle, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult);

delegate void FMars_Delegate_Interactable_OnEnableDisableChanged(FCk_Handle_Interactable InInteractableHandle, ECk_EnableDisable InEnableDisable);
event void FMars_Delegate_Interactable_OnEnableDisableChanged_MC(FCk_Handle_Interactable InInteractableHandle, ECk_EnableDisable InEnableDisable);

struct FMars_Interactable_ChanneledStartedBinding
{
    FGameplayTag Channel;
    FMars_Delegate_Interactable_OnInteractionStarted_MC Delegates;
}

struct FMars_Interactable_ChanneledFinishedBinding
{
    FGameplayTag Channel;
    FMars_Delegate_Interactable_OnInteractionFinished_MC Delegates;
}

struct FMars_Fragment_Interactable_Signals
{
    FMars_Delegate_Interactable_OnFocused_MC OnFocused;
    FMars_Delegate_Interactable_OnUnfocused_MC OnUnfocused;
    FMars_Delegate_Interactable_OnEnableDisableChanged_MC OnEnableDisableChanged;
    TArray<FMars_Interactable_ChanneledStartedBinding> ChanneledOnInteractionStarted;
    TArray<FMars_Interactable_ChanneledFinishedBinding> ChanneledOnInteractionFinished;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Tag_Interactable_NeedsSetup {}

struct FMars_Interactable_ProbeInfo
{
    UPROPERTY()
    FCk_Probe_Spec ProbeParams;

    UPROPERTY()
    FCk_AnyShape ProbeShape;

    UPROPERTY()
    FTransform ProbeOffset;
}

struct FMars_Interactable_TargetEntry
{
    FCk_InteractTarget_Spec InteractTargetParams;
    TOptional<FMars_Fragment_InteractPrompt> InteractPromptParams;

    // Overrides UMars_SmState_InteractTarget_Enter in the per-interaction sub-SM: what the
    // interaction DOES. Route it to UMars_SmState_ExitAndTerminate when done.
    TSoftClassPtr<UCk_SmState_EntityScript> InteractionStateClass;
}

struct FMars_Fragment_Interactable
{
    // Set -> probe-driven focus from the player's view trace. Unset -> a transform-only child whose
    // focus the caller drives directly.
    TOptional<FMars_Interactable_ProbeInfo> ProbeInfo;
    TArray<FMars_Interactable_TargetEntry> Targets;
    ECk_EnableDisable StartEnableDisable = ECk_EnableDisable::Enable;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Interactable_State
{
    UPROPERTY()
    FCk_Handle CurrentFocuser;

    UPROPERTY()
    bool IsFocused = false;

    UPROPERTY()
    ECk_EnableDisable EnableDisable = ECk_EnableDisable::Enable;

    UPROPERTY()
    FCk_Handle_InteractTarget CurrentInteractTarget;

    UPROPERTY()
    FCk_Handle_Interaction CurrentInteraction;
}

// Stamped on every InteractTarget (and, with Initiator set, on each per-interaction sub-SM root) so
// HFSM pieces can reach the interactable and its owner without walking the ownership chain.
struct FMars_Fragment_InteractionContext
{
    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    UPROPERTY()
    FCk_Handle InteractableOwner;

    UPROPERTY()
    FCk_Handle Initiator;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Interactable_Focus
{
    UPROPERTY()
    FCk_Handle FocusedBy;

    FMars_Request_Interactable_Focus() {}

    FMars_Request_Interactable_Focus(const FCk_Handle& InFocusedBy)
    {
        FocusedBy = InFocusedBy;
    }
}

struct FMars_Request_Interactable_Unfocus
{
    UPROPERTY()
    FCk_Handle UnfocusedBy;

    FMars_Request_Interactable_Unfocus() {}

    FMars_Request_Interactable_Unfocus(const FCk_Handle& InUnfocusedBy)
    {
        UnfocusedBy = InUnfocusedBy;
    }
}

struct FMars_Request_Interactable_SetEnableDisable
{
    UPROPERTY()
    ECk_EnableDisable EnableDisable = ECk_EnableDisable::Enable;

    FMars_Request_Interactable_SetEnableDisable() {}

    FMars_Request_Interactable_SetEnableDisable(ECk_EnableDisable InEnableDisable)
    {
        EnableDisable = InEnableDisable;
    }
}

struct FMars_Fragment_Interactable_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Interactable_Focus> FocusRequests;

    UPROPERTY()
    TArray<FMars_Request_Interactable_Unfocus> UnfocusRequests;

    UPROPERTY()
    TArray<FMars_Request_Interactable_SetEnableDisable> SetEnableDisableRequests;
}
