//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_FPHandsHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_FPHands";
    RequiredFragments.Add(FMars_Feature_FPHands);
    Description = "The first-person gloves: reach/grip/return/hold/release/push phase owned by the Hands sub-HFSM, focus lean, hold and carry";
}

struct FMars_Feature_FPHands {}

// Phase of the gloves. Set ONLY by the Hands sub-SM's state enter tasks through Request_SetPhase. Reach/Grip/Return is
// the instant grab; Hold/Release is the timed interaction; Push follows through a drop or throw.
enum EMars_FPHands_Phase
{
    None,
    Reach,
    Grip,
    Return,
    Hold,
    Release,
    Push
}

// The gesture a reach plays: Grab (an instant interaction) runs Reach -> Grip -> Return on its own; Hold (a timed or
// manually completed one) keeps the gloves on the target until it is lost. Place runs Grab's phases with whatever the
// gloves hold carried over the target (the one reach a two-handed hold may make): the Grip phase is where it is let go.
enum EMars_FPHands_ReachKind
{
    Grab,
    Hold,
    Place
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// Retained whole: the anim instance and the pure functions read the sub-specs from here.
struct FMars_Fragment_FPHands_Params
{
    UPROPERTY()
    FMars_FPHands_Spec Spec;

    // The character's stride clock (CkGait); the free-hand arm swing is derived from it. Invalid without one.
    UPROPERTY()
    FCk_Handle_Gait Gait;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The reach the gloves are on (or last were on).
struct FMars_FPHands_ReachState
{
    UPROPERTY()
    TOptional<FMars_FPHands_ReachTarget> Target;

    // Unset when the reach serves no interaction (a bare reach, a target-less subject).
    UPROPERTY()
    TOptional<FCk_Handle_InteractTarget> InteractTarget;

    UPROPERTY()
    ECk_Interaction_CompletionPolicy CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;

    // Single-handed targets near the centre line stay with this glove; every resolve (focus included) updates it.
    UPROPERTY()
    EMars_Hand PreferredHand = EMars_Hand::Right;

    // The interact target of the last reach the gloves refused; cleared by the next reach they take and by a hold change.
    // Lets a task that starts after the refusal (an interaction's grip-wait) know the gloves will not come.
    UPROPERTY()
    TOptional<FCk_Handle_InteractTarget> RefusedTarget;
}

// The lean toward what is looked at.
struct FMars_FPHands_FocusState
{
    // Re-resolved when focus changes. Outlives the focus while the gloves lean back out; cleared once both leans are gone.
    UPROPERTY()
    TOptional<FMars_FPHands_ReachTarget> Target;

    UPROPERTY()
    FCk_Handle_Interactable FocusedFor;

    // Smoothed lean per glove (each eases on its own, so switching sides cross-fades).
    UPROPERTY()
    float32 Alpha_L = 0.0f;

    UPROPERTY()
    float32 Alpha_R = 0.0f;
}

// What a push follows through from.
struct FMars_FPHands_PushState
{
    // The hold the gloves had when the item launched: the feature's Hold empties a few frames later, the push keeps this
    // grip shape.
    UPROPERTY()
    FMars_FPHands_Hold Hold;

    UPROPERTY()
    EMars_LaunchKind Kind = EMars_LaunchKind::Drop;
}

// Written only by UMars_Processor_FPHands_HandleRequests, UMars_Processor_FPHands_Tick and utils_fphands::Add.
struct FMars_Fragment_FPHands
{
    // Phase and the From alphas are written only by the requests drain's SetPhase; PhaseTime also advances in the Tick.
    UPROPERTY()
    FMars_FPHands_PhaseState PhaseState;

    UPROPERTY()
    FMars_FPHands_ReachState Reach;

    UPROPERTY()
    FMars_FPHands_FocusState Focus;

    UPROPERTY()
    FMars_FPHands_Hold Hold;

    // Set while a picked-up item rides in with the gloves.
    UPROPERTY()
    TOptional<FMars_FPHands_Carry> Carry;

    UPROPERTY()
    FMars_FPHands_PushState Push;

    // The view pitch the pitch node is set from, eased (degrees, up is positive). Unset until the first tick with a
    // pitch node.
    UPROPERTY()
    TOptional<float32> ViewPitchDeg;

    // Per-glove finger pose overrides (a station's feed closes the free glove on the food). Each applies only while that
    // glove is on a reach target; both clear when the phase returns to None.
    UPROPERTY()
    TOptional<EMars_HandGripPose> PoseOverride_R;

    UPROPERTY()
    TOptional<EMars_HandGripPose> PoseOverride_L;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_FPHands_OnReachRequested(FCk_Handle_FPHands InHands, EMars_FPHands_ReachKind InKind);
event void FMars_Delegate_FPHands_OnReachRequested_MC(FCk_Handle_FPHands InHands, EMars_FPHands_ReachKind InKind);

// A StartReach the gloves did not take (busy, superseded in its drain, the subject gone, nothing to reach). InTarget is the
// request's interact target (invalid for a reach that served no interaction).
delegate void FMars_Delegate_FPHands_OnReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind);
event void FMars_Delegate_FPHands_OnReachRefused_MC(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind);

delegate void FMars_Delegate_FPHands_OnReachTargetLost(FCk_Handle_FPHands InHands);
event void FMars_Delegate_FPHands_OnReachTargetLost_MC(FCk_Handle_FPHands InHands);

delegate void FMars_Delegate_FPHands_OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew);
event void FMars_Delegate_FPHands_OnPhaseChanged_MC(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew);

delegate void FMars_Delegate_FPHands_OnPushRequested(FCk_Handle_FPHands InHands);
event void FMars_Delegate_FPHands_OnPushRequested_MC(FCk_Handle_FPHands InHands);

struct FMars_Fragment_FPHands_Signals
{
    FMars_Delegate_FPHands_OnReachRequested_MC OnReachRequested;
    FMars_Delegate_FPHands_OnReachRefused_MC OnReachRefused;
    FMars_Delegate_FPHands_OnReachTargetLost_MC OnReachTargetLost;
    FMars_Delegate_FPHands_OnPhaseChanged_MC OnPhaseChanged;
    FMars_Delegate_FPHands_OnPushRequested_MC OnPushRequested;
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

// Reach for a subject. The last one in a drain wins; ignored unless the gloves are at rest (Phase None) or letting go
// (Release, Return), when the subject died before the drain, and when it is unresolvable. Every ignored one (the
// superseded ones included) is refused out loud: OnReachRefused.
struct FMars_Request_FPHands_StartReach
{
    // Unset: a bare reach - the right glove toward the hand node itself, which drives the phase machine without an
    // interactable to resolve (headless tests).
    UPROPERTY()
    TOptional<FMars_FPHands_ReachSubject> Subject;

    UPROPERTY()
    ECk_Interaction_CompletionPolicy CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;

    // Unset: the gesture follows CompletionPolicy (utils_fphands::Get_ReachKind). Place needs a Subject that is a world item,
    // unless PlaceAtWorld names the spot.
    UPROPERTY()
    TOptional<EMars_FPHands_ReachKind> Kind;

    // Place only: where the held item's bounds centre is set down (world; its location is used), instead of over the
    // subject's bounds top. The subject then only anchors the reach (it may be any entity with a transform: a dock's node).
    UPROPERTY()
    TOptional<FTransform> PlaceAtWorld;

    FMars_Request_FPHands_StartReach() {}

    FMars_Request_FPHands_StartReach(ECk_Interaction_CompletionPolicy InCompletionPolicy)
    {
        CompletionPolicy = InCompletionPolicy;
    }

    FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject InSubject, ECk_Interaction_CompletionPolicy InCompletionPolicy)
    {
        Subject = TOptional<FMars_FPHands_ReachSubject>(InSubject);
        CompletionPolicy = InCompletionPolicy;
    }

    FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject InSubject, ECk_Interaction_CompletionPolicy InCompletionPolicy, EMars_FPHands_ReachKind InKind)
    {
        Subject = TOptional<FMars_FPHands_ReachSubject>(InSubject);
        CompletionPolicy = InCompletionPolicy;
        Kind = TOptional<EMars_FPHands_ReachKind>(InKind);
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

// Follow through a launch with the gloves that held the item. Hold is the gloves' hold at launch (read before the item
// leaves the hands). The last one in a drain wins; ignored unless the gloves are at rest (Phase None).
struct FMars_Request_FPHands_StartPush
{
    UPROPERTY()
    FMars_FPHands_Hold Hold;

    UPROPERTY()
    EMars_LaunchKind Kind = EMars_LaunchKind::Drop;

    FMars_Request_FPHands_StartPush() {}

    FMars_Request_FPHands_StartPush(FMars_FPHands_Hold InHold, EMars_LaunchKind InKind)
    {
        Hold = InHold;
        Kind = InKind;
    }
}

// One glove's finger pose while it is on a reach target; an unset Pose clears the override. The last one per glove in a
// drain wins.
struct FMars_Request_FPHands_SetPoseOverride
{
    UPROPERTY()
    EMars_Hand Hand = EMars_Hand::Left;

    UPROPERTY()
    TOptional<EMars_HandGripPose> Pose;

    FMars_Request_FPHands_SetPoseOverride() {}

    FMars_Request_FPHands_SetPoseOverride(EMars_Hand InHand, TOptional<EMars_HandGripPose> InPose)
    {
        Hand = InHand;
        Pose = InPose;
    }
}

struct FMars_Fragment_FPHands_Requests
{
    UPROPERTY()
    TArray<FMars_Request_FPHands_SetHold> SetHoldRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_SetFocus> SetFocusRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_SetPoseOverride> SetPoseOverrideRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_Release> ReleaseRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_SetPhase> SetPhaseRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_StartReach> StartReachRequests;

    UPROPERTY()
    TArray<FMars_Request_FPHands_StartPush> StartPushRequests;
}
