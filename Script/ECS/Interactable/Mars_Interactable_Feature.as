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
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Tag_Interactable_NeedsSetup {}

// On an InteractTarget whose entry set RequiresFreeHands.
struct FMars_Tag_InteractTarget_RequiresFreeHands {}

struct FMars_Interactable_ProbeInfo
{
    UPROPERTY()
    FCk_Probe_Spec ProbeSpec;

    UPROPERTY()
    FCk_AnyShape ProbeShape;

    UPROPERTY()
    FTransform ProbeOffset;
}

struct FMars_Interactable_TargetEntry
{
    FCk_InteractTarget_Spec InteractTargetSpec;
    TOptional<FMars_InteractPrompt_Spec> InteractPromptSpec;

    // Overrides UMars_SmState_InteractTarget_Enter in the per-interaction sub-SM: what the
    // interaction DOES. Route it to UMars_SmState_ExitAndTerminate when done.
    TSoftClassPtr<UCk_SmState_EntityScript> InteractionStateClass;

    // The action needs both hands: nobody holding an item can start it (UMars_Interactable_FreeHandsPolicy); while the
    // focuser holds one its prompt reads blocked, and filling the hands mid-interaction lets go
    // (UMars_SmTask_Interactable_HandsGate).
    bool RequiresFreeHands = false;
}

struct FMars_Interactable_Spec
{
    // Set -> probe-driven focus from the player's view trace. Unset -> a transform-only child whose
    // focus the caller drives directly.
    TOptional<FMars_Interactable_ProbeInfo> ProbeInfo;
    TArray<FMars_Interactable_TargetEntry> Targets;
    ECk_EnableDisable StartEnableDisable = ECk_EnableDisable::Enable;

    // Higher wins focus when several interactables sit under the view ray; ties fall back to distance.
    int32 FocusPriority = 0;
}

// Every target names a channel no other target uses (targets are looked up by channel) and an InteractionStateClass that
// loads (the sub-SM has nothing to run without one), and its prompt, if any, validates. No targets is valid: a bare
// interactable that only takes focus.
mixin FMars_Validation Validate(const FMars_Interactable_Spec& Self)
{
    for (int32 Index = 0; Index < Self.Targets.Num(); ++Index)
    {
        const auto& Entry = Self.Targets[Index];
        const auto Channel = Entry.InteractTargetSpec.Get_InteractionChannel();
        if (Channel.IsValid() == false)
        { return FMars_Validation(f"Interactable target [{Index}] has no interaction channel"); }

        for (int32 Earlier = 0; Earlier < Index; ++Earlier)
        {
            if (Self.Targets[Earlier].InteractTargetSpec.Get_InteractionChannel() == Channel)
            { return FMars_Validation(f"Interactable target [{Index}] repeats the channel [{Channel.ToString()}] of target [{Earlier}]"); }
        }

        auto InteractionStateClass = Entry.InteractionStateClass.Get();
        if (ck::Is_NOT_Valid(InteractionStateClass))
        { return FMars_Validation(f"Interactable target [{Index}] on [{Channel.ToString()}] has no InteractionStateClass"); }

        if (Entry.InteractPromptSpec.IsSet())
        {
            const auto PromptValidation = Entry.InteractPromptSpec.GetValue().Validate();
            if (PromptValidation.IsValid() == false)
            { return FMars_Validation(f"Interactable target [{Index}] on [{Channel.ToString()}]: {PromptValidation.Get_Error()}"); }
        }
    }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// The spec residue read after construction: which channels the targets were created on, and how it ranks for focus.
struct FMars_Fragment_Interactable_Params
{
    UPROPERTY()
    TArray<FGameplayTag> TargetChannels;

    UPROPERTY()
    int32 FocusPriority = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The most recent interaction started on one of the interactable's targets. Its source is read when it starts: a finished
// interaction is destroyed, often before the per-interaction sub-SM that needs its initiator is constructed.
struct FMars_Interactable_StartedInteraction
{
    UPROPERTY()
    FCk_Handle_InteractTarget Target;

    UPROPERTY()
    FCk_Handle Initiator;
}

// Written only by the Interactable processors.
struct FMars_Fragment_Interactable
{
    // Invalid = not focused.
    UPROPERTY()
    FCk_Handle Focuser;

    UPROPERTY()
    ECk_EnableDisable EnableDisable = ECk_EnableDisable::Enable;

    UPROPERTY()
    FMars_Interactable_StartedInteraction LastStarted;
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

// Scoped: a no-op unless UnfocusedBy is the focuser when it drains.
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

enum EMars_Interactable_FocusChange
{
    Focus,
    Unfocus
}

// A Focus or an Unfocus request, queued with the other kind so the drain sees them in arrival order.
struct FMars_Interactable_FocusChangeRequest
{
    UPROPERTY()
    EMars_Interactable_FocusChange Change = EMars_Interactable_FocusChange::Focus;

    UPROPERTY()
    FCk_Handle Focuser;

    FMars_Interactable_FocusChangeRequest() {}

    FMars_Interactable_FocusChangeRequest(EMars_Interactable_FocusChange InChange, const FCk_Handle& InFocuser)
    {
        Change = InChange;
        Focuser = InFocuser;
    }
}

// Focus changes apply in arrival order (a player sliding focus A -> B -> A in one frame ends with A focused), then
// SetEnableDisable requests.
struct FMars_Fragment_Interactable_Requests
{
    UPROPERTY()
    TArray<FMars_Interactable_FocusChangeRequest> FocusChangeRequests;

    UPROPERTY()
    TArray<FMars_Request_Interactable_SetEnableDisable> SetEnableDisableRequests;
}
