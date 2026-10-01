//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_FPHandsHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_FPHands";
    RequiredFragments.Add(FMars_Feature_FPHands);
    Description = "The first-person gloves: reach/grip/return/hold/release phase owned by the Hands sub-HFSM, focus lean, hold and carry";
}

struct FMars_Feature_FPHands {}

// Phase of the gloves. Set ONLY by the Hands sub-SM's state enter tasks through Request_SetPhase. Reach/Grip/Return is
// the instant grab; Hold/Release is the timed interaction.
enum EMars_FPHands_Phase
{
    None,
    Reach,
    Grip,
    Return,
    Hold,
    Release
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// Retained whole: the anim instance and the pure functions read the placement sub-specs from here.
struct FMars_Fragment_FPHands_Params
{
    UPROPERTY()
    FMars_FPHands_Spec Spec;

    // The swaying, bobbing hand node the gloves hang off (Player.HandBob, a CkGait bob node).
    UPROPERTY()
    FCk_Handle_Transform HandNode;

    // The character's stride clock (CkGait); the free-hand arm swing is derived from it.
    UPROPERTY()
    FCk_Handle_Gait Gait;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_FPHands_HandleRequests, UMars_Processor_FPHands_Tick and utils_fphands::Add.
struct FMars_Fragment_FPHands
{
    UPROPERTY()
    EMars_FPHands_Phase Phase = EMars_FPHands_Phase::None;

    // Seconds since the current phase was set (reset by every SetPhase).
    UPROPERTY()
    float32 PhaseTime = 0.0f;

    // The reach alpha when Release began (a release eases back from wherever the gloves were).
    UPROPERTY()
    float32 ReleaseFromAlpha = 1.0f;

    UPROPERTY()
    FMars_FPHands_ReachTarget Target;

    UPROPERTY()
    FCk_Handle_InteractTarget InteractTarget;

    UPROPERTY()
    bool IsInstant = true;

    // What the gloves lean toward while it is looked at, re-resolved when focus changes.
    UPROPERTY()
    FMars_FPHands_ReachTarget FocusTarget;

    UPROPERTY()
    FCk_Handle_Interactable FocusedFor;

    // Smoothed focus lean per glove (each eases on its own, so switching sides cross-fades).
    UPROPERTY()
    float32 FocusAlpha_L = 0.0f;

    UPROPERTY()
    float32 FocusAlpha_R = 0.0f;

    // Single-handed targets near the centre line stay with this glove.
    UPROPERTY()
    bool PreferRightHand = true;

    UPROPERTY()
    FMars_FPHands_Hold Hold;

    UPROPERTY()
    FMars_FPHands_Carry Carry;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_FPHands_OnReachRequested(FCk_Handle_FPHands InHands, bool InIsInstant);
event void FMars_Delegate_FPHands_OnReachRequested_MC(FCk_Handle_FPHands InHands, bool InIsInstant);

delegate void FMars_Delegate_FPHands_OnReachTargetLost(FCk_Handle_FPHands InHands);
event void FMars_Delegate_FPHands_OnReachTargetLost_MC(FCk_Handle_FPHands InHands);

delegate void FMars_Delegate_FPHands_OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew);
event void FMars_Delegate_FPHands_OnPhaseChanged_MC(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew);

struct FMars_Fragment_FPHands_Signals
{
    FMars_Delegate_FPHands_OnReachRequested_MC OnReachRequested;
    FMars_Delegate_FPHands_OnReachTargetLost_MC OnReachTargetLost;
    FMars_Delegate_FPHands_OnPhaseChanged_MC OnPhaseChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Issued only by the Hands sub-SM's state enter tasks. The last one in a drain wins.
struct FMars_Request_FPHands_SetPhase
{
    UPROPERTY()
    EMars_FPHands_Phase Phase = EMars_FPHands_Phase::None;

    FMars_Request_FPHands_SetPhase() {}

    FMars_Request_FPHands_SetPhase(EMars_FPHands_Phase InPhase)
    {
        Phase = InPhase;
    }
}

// Reach for an interact target. The last one in a drain wins; ignored unless the gloves are at rest (Phase None) and
// when the target is unresolvable.
struct FMars_Request_FPHands_StartReach
{
    UPROPERTY()
    FCk_Handle_InteractTarget Target;

    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    UPROPERTY()
    FCk_Handle Owner;

    UPROPERTY()
    bool IsInstant = true;

    FMars_Request_FPHands_StartReach() {}

    FMars_Request_FPHands_StartReach(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interactable InInteractable, FCk_Handle InOwner,
                                     bool InIsInstant)
    {
        Target = InTarget;
        Interactable = InInteractable;
        Owner = InOwner;
        IsInstant = InIsInstant;
    }
}

// The reach target is gone. AngelScript rejects a TArray of an empty struct, so it carries one placeholder field.
struct FMars_Request_FPHands_Release
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_FPHands_Release() {}
}

// An invalid Interactable clears the focus lean.
struct FMars_Request_FPHands_SetFocus
{
    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    UPROPERTY()
    FCk_Handle Owner;

    FMars_Request_FPHands_SetFocus() {}

    FMars_Request_FPHands_SetFocus(FCk_Handle_Interactable InInteractable, FCk_Handle InOwner)
    {
        Interactable = InInteractable;
        Owner = InOwner;
    }
}

// An invalid Item empties the hands.
struct FMars_Request_FPHands_SetHold
{
    UPROPERTY()
    FCk_Handle_Item Item;

    FMars_Request_FPHands_SetHold() {}

    FMars_Request_FPHands_SetHold(FCk_Handle_Item InItem)
    {
        Item = InItem;
    }
}

struct FMars_Fragment_FPHands_Requests
{
    UPROPERTY()
    TArray<FMars_Request_FPHands_SetHold> SetHoldRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_SetFocus> SetFocusRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_Release> ReleaseRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_SetPhase> SetPhaseRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_StartReach> StartReachRequests;
}
