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

// InFocusable is Enable while no held reason takes the interactable out of focus (utils_interactable::Get_ClaimRemovesFocus).
delegate void FMars_Delegate_Interactable_OnFocusableChanged(FCk_Handle_Interactable InInteractableHandle, ECk_EnableDisable InFocusable);
event void FMars_Delegate_Interactable_OnFocusableChanged_MC(FCk_Handle_Interactable InInteractableHandle, ECk_EnableDisable InFocusable);

// A WhileLive interaction on InFailure.Target failed for InFailure.Initiator, for the reason its work named.
delegate void FMars_Delegate_Interactable_OnInteractionFailed(FCk_Handle_Interactable InInteractableHandle, FMars_Interactable_Failure InFailure);
event void FMars_Delegate_Interactable_OnInteractionFailed_MC(FCk_Handle_Interactable InInteractableHandle, FMars_Interactable_Failure InFailure);

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
    // Fires when the first reason is claimed and when the last one is released, not on every claim.
    FMars_Delegate_Interactable_OnEnableDisableChanged_MC OnEnableDisableChanged;
    // Fires when the first focus-removing reason is claimed and when the last one is released.
    FMars_Delegate_Interactable_OnFocusableChanged_MC OnFocusableChanged;
    // Fires once per WhileLive interaction its work ended Failed with a reason (FMars_Request_Interactable_ReportFailure).
    FMars_Delegate_Interactable_OnInteractionFailed_MC OnInteractionFailed;
    TArray<FMars_Interactable_ChanneledStartedBinding> ChanneledOnInteractionStarted;
    TArray<FMars_Interactable_ChanneledFinishedBinding> ChanneledOnInteractionFinished;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Why an interactable is disabled; it is enabled while no reason is held. Each claimant holds its own reason, so one
// releasing never undoes another's. Every reason disables the targets (a press starts nothing); only some also take the
// interactable out of focus (utils_interactable::Get_ClaimRemovesFocus).
enum EMars_Interactable_DisableReason
{
    // A world item rides a carrier: it belongs to it now, and leaves focus.
    Mounted,
    // The focuser's hotbar has nowhere to stow the item: it stays focused and its prompt says so.
    HotbarFull,
    // A pack is in its holder's hands: its cargo is out of reach, and leaves focus.
    HolderHeld,
    // A kernel's ledger (a pan, a fryer, a board) holds the item: it belongs to the kernel now, and leaves focus.
    Ledger,
    // An operator holds the station: it stays focused and its prompt says it is in use.
    Operated
}

// What a target's interaction is for (FMars_Interactable_TargetEntry.Work).
enum EMars_Interactable_Work
{
    // The work runs once the interaction has finished Succeeded, timed by the target's own completion policy (a toggle, a
    // control's engage, a held item's use).
    AfterCompletion,
    // The work runs while the interaction is live and ends it with its own outcome (a pickup, a dock's Place or Take, a
    // deposit, a cargo stow or take, a station's reserve). The target is ManuallyCompleted; the interaction is committed
    // from its start, and only that outcome, a claim that takes the interactable out of focus, or teardown ends it.
    WhileLive
}

// Why a WhileLive interaction's work failed. The work's task names it (utils_interactable::Record_FailReason), which
// reports it (OnInteractionFailed).
enum EMars_Interaction_FailReason
{
    // The gloves left the reach (returned, let go) before its Grip.
    GlovesLeftBeforeGrip,
    // The gloves lost the target they were reaching for.
    GlovesLostTarget,
    // The gloves refused the Place reach the work asked for.
    PlaceReachRefused,
    // The gloves never answered the Place reach (a defect, ensured where it is noticed).
    PlaceReachUnanswered,
    // The initiator's action on the target is a blocked one (its prompt lagged its hands by a frame).
    ActionBlocked,
    // The world item holds nothing, or the initiator's hotbar has nowhere to stow or take it.
    NowhereToStow,
    // The inventory transfer the work asked for was refused.
    TransferRefused,
    // The platter is full.
    PlatterFull,
    // The initiator's hands hold no food to place.
    NoFoodInHand,
    // The held food's release was refused: it stays in the hands.
    ReleaseRefused,
    // The platter refused the released food: it lies where it was let go.
    LoadRefused,
    // The platter let the released food go before it landed (taken by hand, or gone).
    LeftTheBooks,
    // The dock no longer holds the item the take was for.
    NoLongerDocked,
    // The dock refused the platter set down on it.
    DockRefused,
    // The dock refused to hand its platter over.
    UndockRefused
}

// The payload of OnInteractionFailed: Target's WhileLive interaction from Initiator failed for Reason.
struct FMars_Interactable_Failure
{
    UPROPERTY()
    FCk_Handle_InteractTarget Target;

    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    EMars_Interaction_FailReason Reason = EMars_Interaction_FailReason::GlovesLeftBeforeGrip;

    FMars_Interactable_Failure() {}

    FMars_Interactable_Failure(FCk_Handle_InteractTarget InTarget, FCk_Handle InInitiator, EMars_Interaction_FailReason InReason)
    {
        Target = InTarget;
        Initiator = InInitiator;
        Reason = InReason;
    }
}

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

    // Overrides UMars_SmState_InteractTarget_Enter in the per-interaction sub-SM: what the interaction DOES. Route it to
    // UMars_SmState_InteractTarget_Succeeded / _Failed when done (UMars_SmState_InteractTarget_RunTask does).
    TSoftClassPtr<UCk_SmState_EntityScript> InteractionStateClass;

    // The action needs both hands: nobody holding an item can start it (UMars_Interactable_FreeHandsPolicy); while the
    // focuser holds one its prompt reads blocked, and filling the hands mid-interaction lets go
    // (UMars_SmTask_Interactable_HandsGate).
    bool RequiresFreeHands = false;

    // When InteractionStateClass runs. WhileLive makes the target ManuallyCompleted whatever InteractTargetSpec says.
    EMars_Interactable_Work Work = EMars_Interactable_Work::AfterCompletion;

    // The gesture the gloves make for this target; None for one the hands do not touch (no lean, no reach).
    EMars_FPHands_ReachKind ReachKind = EMars_FPHands_ReachKind::Grab;

    // Which glove makes it while a one-handed item is held: the free one, or the holding one carrying its item to the
    // target (a lit torch to a candle).
    EMars_FPHands_ReachHand ReachHand = EMars_FPHands_ReachHand::Free;
}

struct FMars_Interactable_Spec
{
    // Set -> probe-driven focus from the player's view trace. Unset -> a transform-only child whose
    // focus the caller drives directly.
    TOptional<FMars_Interactable_ProbeInfo> ProbeInfo;
    TArray<FMars_Interactable_TargetEntry> Targets;

    // Held from construction; each must be released before the interactable is enabled.
    TArray<EMars_Interactable_DisableReason> StartDisabled;

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

// The latest Succeeded finish on an AfterCompletion target, for its state machine to run the work once: the finish writes
// it, and entering Interacting for it consumes it by Serial (FMars_Request_Interactable_ConsumeCompletion).
struct FMars_Interactable_Completion
{
    UPROPERTY()
    FCk_Handle_InteractTarget Target;

    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    int32 Serial = 0;
}

// Written only by the Interactable processors.
struct FMars_Fragment_Interactable
{
    // Invalid = not focused.
    UPROPERTY()
    FCk_Handle Focuser;

    // A set: enabled while empty. Every target's framework flag follows it.
    UPROPERTY()
    TArray<EMars_Interactable_DisableReason> DisableReasons;

    // Unset once consumed (or never recorded).
    UPROPERTY()
    TOptional<FMars_Interactable_Completion> Completion;

    // The Serial the last recorded completion took.
    UPROPERTY()
    int32 CompletionSerial = 0;
}

// Stamped on every InteractTarget (and, with Initiator set, on each per-interaction sub-SM root) so HFSM pieces can reach
// the interactable, its owner and what the target is for without walking the ownership chain.
struct FMars_Fragment_InteractionContext
{
    // The interact target this context was stamped on; a sub-SM root's copy keeps it.
    UPROPERTY()
    FCk_Handle_InteractTarget Target;

    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    UPROPERTY()
    FCk_Handle InteractableOwner;

    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    EMars_Interactable_Work Work = EMars_Interactable_Work::AfterCompletion;

    UPROPERTY()
    EMars_FPHands_ReachKind ReachKind = EMars_FPHands_ReachKind::Grab;

    UPROPERTY()
    EMars_FPHands_ReachHand ReachHand = EMars_FPHands_ReachHand::Free;
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

// Claims InReason: the interactable is disabled until every reason it holds is released. Claiming a held reason changes
// nothing.
struct FMars_Request_Interactable_Disable
{
    UPROPERTY()
    EMars_Interactable_DisableReason Reason = EMars_Interactable_DisableReason::Mounted;

    FMars_Request_Interactable_Disable() {}

    FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason InReason)
    {
        Reason = InReason;
    }
}

// Releases InReason. Releasing a reason that is not held changes nothing.
struct FMars_Request_Interactable_Enable
{
    UPROPERTY()
    EMars_Interactable_DisableReason Reason = EMars_Interactable_DisableReason::Mounted;

    FMars_Request_Interactable_Enable() {}

    FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason InReason)
    {
        Reason = InReason;
    }
}

// Consumes the recorded completion while it is still the one Serial names; a newer completion is kept.
struct FMars_Request_Interactable_ConsumeCompletion
{
    UPROPERTY()
    int32 Serial = 0;

    FMars_Request_Interactable_ConsumeCompletion() {}

    FMars_Request_Interactable_ConsumeCompletion(int32 InSerial)
    {
        Serial = InSerial;
    }
}

enum EMars_Interactable_ClaimChange
{
    Disable,
    Enable
}

// A Disable or an Enable request, queued with the other kind so the drain sees them in arrival order (a reason claimed and
// released in one frame ends released; released and claimed again, ends held).
struct FMars_Interactable_ClaimChangeRequest
{
    UPROPERTY()
    EMars_Interactable_ClaimChange Change = EMars_Interactable_ClaimChange::Disable;

    UPROPERTY()
    EMars_Interactable_DisableReason Reason = EMars_Interactable_DisableReason::Mounted;

    FMars_Interactable_ClaimChangeRequest() {}

    FMars_Interactable_ClaimChangeRequest(EMars_Interactable_ClaimChange InChange, EMars_Interactable_DisableReason InReason)
    {
        Change = InChange;
        Reason = InReason;
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

// Reports that InTarget's WhileLive interaction from Initiator ended Failed for Reason (OnInteractionFailed).
struct FMars_Request_Interactable_ReportFailure
{
    UPROPERTY()
    FCk_Handle_InteractTarget Target;

    UPROPERTY()
    FCk_Handle Initiator;

    UPROPERTY()
    EMars_Interaction_FailReason Reason = EMars_Interaction_FailReason::GlovesLeftBeforeGrip;

    FMars_Request_Interactable_ReportFailure() {}

    FMars_Request_Interactable_ReportFailure(FCk_Handle_InteractTarget InTarget, FCk_Handle InInitiator, EMars_Interaction_FailReason InReason)
    {
        Target = InTarget;
        Initiator = InInitiator;
        Reason = InReason;
    }
}

// Focus changes apply in arrival order (a player sliding focus A -> B -> A in one frame ends with A focused), then claim
// changes in arrival order, then completion consumes, then failure reports.
struct FMars_Fragment_Interactable_Requests
{
    UPROPERTY()
    TArray<FMars_Interactable_FocusChangeRequest> FocusChangeRequests;

    UPROPERTY()
    TArray<FMars_Interactable_ClaimChangeRequest> ClaimChangeRequests;

    UPROPERTY()
    TArray<FMars_Request_Interactable_ConsumeCompletion> ConsumeCompletionRequests;

    UPROPERTY()
    TArray<FMars_Request_Interactable_ReportFailure> ReportFailureRequests;
}
