// Stateless CanInteractWith predicate for every RequiresFreeHands target, bound from the CDO. The source is the player
// whose resolver or StartInteraction asks.
UCLASS()
class UMars_Interactable_FreeHandsPolicy : UObject
{
    UFUNCTION()
    void OnCanInteractWith(FCk_Handle_InteractTarget InTarget, FCk_Handle InInteractSource, FCk_Handle InInteractInstigator, bool& OutResult)
    { OutResult = utils_interactable::Get_HandsAreFree(InInteractSource); }
}

namespace utils_interactable
{
    // Nothing in hand. An entity without HeldItem (tests, an NPC) has free hands.
    bool Get_HandsAreFree(const FCk_Handle& InEntity)
    {
        const auto HeldItem = InEntity.As_HeldItem(ECk_SanityCheck::UnChecked);
        return ck::Is_NOT_Valid(HeldItem) || ck::Is_NOT_Valid(HeldItem.Get_CurrentItem());
    }

    // Whether holding InReason takes the interactable out of focus (the thing belongs to something else now: a carrier, a
    // kernel's ledger, a holder's hands) or keeps it focusable with its targets disabled, so its prompt can say why the
    // action is refused right now (a full hotbar, an operated station).
    bool Get_ClaimRemovesFocus(EMars_Interactable_DisableReason InReason)
    {
        return InReason == EMars_Interactable_DisableReason::Mounted
            || InReason == EMars_Interactable_DisableReason::Ledger
            || InReason == EMars_Interactable_DisableReason::HolderHeld;
    }

    // A live interaction on InTarget other than InExcluding (from any source); invalid when none is.
    FCk_Handle_Interaction Get_LiveInteraction(const FCk_Handle_InteractTarget& InTarget, const FCk_Handle_Interaction& InExcluding)
    {
        if (ck::Is_NOT_Valid(InTarget))
        { return FCk_Handle_Interaction(); }

        for (auto Interaction : utils_interact_target::Get_CurrentInteractions(InTarget))
        {
            if (ck::IsValid(Interaction) && Interaction != InExcluding)
            { return Interaction; }
        }

        return FCk_Handle_Interaction();
    }

    // InContext as the WhileLive interact target it is (a target state machine's context); invalid for an AfterCompletion
    // target or an entity that is no interact target.
    FCk_Handle_InteractTarget TryGet_WhileLiveTarget(const FCk_Handle& InContext)
    {
        if (ck::Is_NOT_Valid(InContext) || InContext.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        { return FCk_Handle_InteractTarget(); }

        if (InContext.Get_Fragment(FMars_Fragment_InteractionContext).Work != EMars_Interactable_Work::WhileLive)
        { return FCk_Handle_InteractTarget(); }

        return InContext.As_InteractTarget(ECk_SanityCheck::UnChecked);
    }

    // The live interaction a WhileLive per-interaction sub-SM runs for: InContext's (the interact target's) interaction
    // from the Initiator stamped on InOwningSm (the sub-SM root). Invalid for an AfterCompletion target, an unstamped root,
    // or an interaction that already ended.
    FCk_Handle_Interaction TryGet_StampedInteraction(const FCk_Handle& InContext, const FCk_Handle& InOwningSm)
    {
        const auto Target = TryGet_WhileLiveTarget(InContext);
        if (ck::Is_NOT_Valid(Target) || ck::Is_NOT_Valid(InOwningSm) || InOwningSm.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        { return FCk_Handle_Interaction(); }

        const auto Initiator = InOwningSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        if (ck::Is_NOT_Valid(Initiator))
        { return FCk_Handle_Interaction(); }

        return utils_interact_target::TryGet_Interaction(Target, Initiator);
    }

    // Reports why the WhileLive work a per-interaction sub-SM runs failed. InSubSmRoot is the work task's owning state
    // machine, whose stamped context names the target and the initiator; the interactable broadcasts the failure
    // (OnInteractionFailed) at its next drain, and the failed task's Failed end ends the interaction. A root that was
    // never stamped is a work state run outside an interaction: ensured.
    void Record_FailReason(FCk_Handle InSubSmRoot, EMars_Interaction_FailReason InReason)
    {
        if (ck::EnsureIfNot(ck::IsValid(InSubSmRoot) && InSubSmRoot.Has_Fragment(FMars_Fragment_InteractionContext),
            f"[Interactable] a [{InReason :n}] failure names no stamped interaction sub-SM"))
        { return; }

        const auto Context = InSubSmRoot.Get_Fragment(FMars_Fragment_InteractionContext);
        auto Interactable = Context.Interactable;
        if (ck::EnsureIfNot(ck::IsValid(Interactable),
            f"[Interactable] a [{InReason :n}] failure on [{InSubSmRoot.ToString()}] has no interactable to report it"))
        { return; }

        Interactable.Request_ReportFailure(FMars_Request_Interactable_ReportFailure(Context.Target, Context.Initiator, InReason));
    }

    // An AfterCompletion target whose completion needs the press kept (Timed, a pulled Control): its interaction is
    // cancelled when the press ends. Neither an Instant one (done at its start) nor a WhileLive one (committed from its
    // start) is.
    bool Get_LastsWhileHeld(const FCk_Handle_InteractTarget& InTarget)
    {
        if (ck::Is_NOT_Valid(InTarget) || InTarget.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        { return false; }

        if (InTarget.Get_Fragment(FMars_Fragment_InteractionContext).Work != EMars_Interactable_Work::AfterCompletion)
        { return false; }

        return utils_interact_target::Get_InteractionCompletionPolicy(InTarget) != ECk_Interaction_CompletionPolicy::Instant;
    }

    // Composes the interactable as a child of InOwner: a probe node when InSpec.ProbeInfo is set, else a transform-only
    // node, with one InteractTarget (and its prompt and per-interaction state machine) per spec target, each disabled
    // while InSpec.StartDisabled holds a reason. A WhileLive target is ManuallyCompleted and takes one interaction at a
    // time (its work is one initiator's until it ends). A rejected spec ensures and returns an invalid handle with nothing
    // composed.
    FCk_Handle_Interactable Create(FCk_Handle_Transform& InOwner, FMars_Interactable_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Interactable] [{InOwner.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Interactable(); }

        FCk_Handle_Transform InteractableHandle;
        if (InSpec.ProbeInfo.IsSet())
        {
            auto Probe = InSpec.ProbeInfo.GetValue();
            // QueryOnly: traceable by the player's view ray, never a physical contact.
            Probe.ProbeSpec
                .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent)
                .Set_ContactParticipation(ECk_Probe_ContactParticipation::QueryOnly);
            InteractableHandle = utils_prefab::Create_ProbeNode(InOwner, Probe.ProbeShape, Probe.ProbeSpec, Probe.ProbeOffset).As_Transform();
        }
        else
        {
            InteractableHandle = utils_scene_node::Create(InOwner, FTransform::Identity).As_Transform();
        }

        auto Params = FMars_Fragment_Interactable_Params();
        for (const auto& Entry : InSpec.Targets)
        { Params.TargetChannels.Add(Entry.InteractTargetSpec.Get_InteractionChannel()); }
        Params.FocusPriority = InSpec.FocusPriority;

        InteractableHandle.Add_Fragment(Params);
        InteractableHandle.Add_Fragment(FMars_Feature_Interactable());

        auto InitialState = FMars_Fragment_Interactable();
        for (auto Reason : InSpec.StartDisabled)
        { InitialState.DisableReasons.AddUnique(Reason); }

        const auto StartsEnabled = InitialState.DisableReasons.Num() == 0;
        InteractableHandle.Add_Fragment(InitialState);

        InteractableHandle.Add_Fragment(FMars_Tag_Interactable_NeedsSetup());
        InteractableHandle.Request_OverrideToSelf();

        auto Interactable = InteractableHandle.As_Interactable();

        TSubclassOf<UMars_Interactable_FreeHandsPolicy> FreeHandsPolicyClass = UMars_Interactable_FreeHandsPolicy;
        auto FreeHandsPolicy = FreeHandsPolicyClass.GetDefaultObject();

        for (const auto& Entry : InSpec.Targets)
        {
            auto TargetSpec = Entry.InteractTargetSpec;
            if (Entry.Work == EMars_Interactable_Work::WhileLive)
            {
                TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::ManuallyCompleted);
                TargetSpec.Set_ConcurrentInteractionsPolicy(ECk_InteractionTarget_ConcurrentInteractionsPolicy::SingleInteraction);
            }

            if (Entry.RequiresFreeHands)
            { TargetSpec.Set_CustomCanInteractWithDynamic(FCk_Delegate_InteractTarget_CanInteractWith(FreeHandsPolicy, n"OnCanInteractWith")); }

            auto Context = FMars_Fragment_InteractionContext();
            Context.Interactable = Interactable;
            Context.InteractableOwner = InOwner;
            Context.Work = Entry.Work;
            Context.ReachKind = Entry.ReachKind;

            auto InteractTarget = utils_interact_target::Add(InteractableHandle, TargetSpec);
            InteractTarget.Request_OverrideToSelf();
            Context.Target = InteractTarget;
            InteractTarget.Add_Fragment(Context);

            if (StartsEnabled == false)
            { utils_interact_target::Set_Enabled(InteractTarget, ECk_EnableDisable::Disable); }

            if (Entry.RequiresFreeHands)
            { InteractTarget.Add_Fragment(FMars_Tag_InteractTarget_RequiresFreeHands()); }

            if (Entry.InteractPromptSpec.IsSet())
            { utils_interact_prompt::Add(InteractTarget, Entry.InteractPromptSpec.GetValue()); }

            auto TargetSm = utils_state_machine::Add(InteractTarget, FCk_StateMachine_Spec(UMars_SmState_Interactable_Idle));
            TargetSm.Request_AddOverrideState(Entry.InteractionStateClass.Get());
        }

        return Interactable;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FCk_Handle_InteractTarget Get_InteractTarget(const FCk_Handle_Interactable& Self, FGameplayTag InChannelTag)
{
    return utils_interact_target::TryGet(Self, InChannelTag);
}

mixin TArray<FCk_Handle_InteractTarget> Get_AllInteractTargets(const FCk_Handle_Interactable& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Interactable_Params);
    auto Result = TArray<FCk_Handle_InteractTarget>();
    for (const auto& Channel : Params.TargetChannels)
    {
        auto Target = utils_interact_target::TryGet(Self, Channel);
        if (ck::IsValid(Target))
        { Result.Add(Target); }
    }
    return Result;
}

mixin int32 Get_FocusPriority(const FCk_Handle_Interactable& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Interactable_Params).FocusPriority;
}

// Enable while no reason is held: the framework targets follow it.
mixin ECk_EnableDisable Get_EnableDisable(const FCk_Handle_Interactable& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Interactable);
    return State.DisableReasons.Num() == 0 ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
}

// No held reason takes it out of focus (utils_interactable::Get_ClaimRemovesFocus); its targets may still be disabled.
mixin bool Get_IsFocusable(const FCk_Handle_Interactable& Self)
{
    for (const auto Reason : Self.Get_Fragment(FMars_Fragment_Interactable).DisableReasons)
    {
        if (utils_interactable::Get_ClaimRemovesFocus(Reason))
        { return false; }
    }

    return true;
}

mixin bool Get_IsDisabledFor(const FCk_Handle_Interactable& Self, EMars_Interactable_DisableReason InReason)
{
    return Self.Get_Fragment(FMars_Fragment_Interactable).DisableReasons.Contains(InReason);
}

mixin bool Get_IsFocused(const FCk_Handle_Interactable& Self)
{
    return ck::IsValid(Self.Get_Fragment(FMars_Fragment_Interactable).Focuser);
}

// Invalid when not focused.
mixin FCk_Handle Get_CurrentFocuser(const FCk_Handle_Interactable& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Interactable).Focuser;
}

// The entity that composed the target's interactable; invalid for a target without a Mars interaction context.
mixin FCk_Handle TryGet_InteractableOwner(const FCk_Handle_InteractTarget& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_Fragment(FMars_Fragment_InteractionContext) == false)
    { return FCk_Handle(); }

    return Self.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
}

// InTarget's recorded completion that no consume has been queued for yet; unset otherwise (none, another target's, or
// one whose consume is on its way).
mixin TOptional<FMars_Interactable_Completion> TryGet_FreshCompletion(const FCk_Handle_Interactable& Self, const FCk_Handle_InteractTarget& InTarget)
{
    const auto Completion = Self.Get_Fragment(FMars_Fragment_Interactable).Completion;
    if (Completion.IsSet() == false || Completion.GetValue().Target != InTarget)
    { return TOptional<FMars_Interactable_Completion>(); }

    if (Self.Has_Fragment(FMars_Fragment_Interactable_Requests))
    {
        const auto Serial = Completion.GetValue().Serial;
        for (const auto& Request : Self.Get_Fragment(FMars_Fragment_Interactable_Requests).ConsumeCompletionRequests)
        {
            if (Request.Serial == Serial)
            { return TOptional<FMars_Interactable_Completion>(); }
        }
    }

    return Completion;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Focus(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_Focus& InRequest)
{
    if (ck::EnsureIfNot(ck::IsValid(InRequest.FocusedBy), f"[Interactable] [{Self.ToString()}] was asked to focus for an invalid focuser"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.FocusChangeRequests.Add(FMars_Interactable_FocusChangeRequest(EMars_Interactable_FocusChange::Focus, InRequest.FocusedBy));
}

mixin void Request_Unfocus(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_Unfocus& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.FocusChangeRequests.Add(FMars_Interactable_FocusChangeRequest(EMars_Interactable_FocusChange::Unfocus, InRequest.UnfocusedBy));
}

mixin void Request_Disable(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_Disable& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.ClaimChangeRequests.Add(FMars_Interactable_ClaimChangeRequest(EMars_Interactable_ClaimChange::Disable, InRequest.Reason));
}

mixin void Request_Enable(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_Enable& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.ClaimChangeRequests.Add(FMars_Interactable_ClaimChangeRequest(EMars_Interactable_ClaimChange::Enable, InRequest.Reason));
}

mixin void Request_ConsumeCompletion(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_ConsumeCompletion& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.ConsumeCompletionRequests.Add(InRequest);
}

mixin void Request_ReportFailure(FCk_Handle_Interactable& Self, const FMars_Request_Interactable_ReportFailure& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Requests);
    Requests.ReportFailureRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnFocused(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnFocused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    Fragment.OnFocused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFocused(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnFocused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnFocused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnUnfocused(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnUnfocused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    Fragment.OnUnfocused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnUnfocused(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnUnfocused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnUnfocused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnEnableDisableChanged(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnEnableDisableChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    Fragment.OnEnableDisableChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEnableDisableChanged(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnEnableDisableChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnEnableDisableChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnFocusableChanged(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnFocusableChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    Fragment.OnFocusableChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFocusableChanged(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnFocusableChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnFocusableChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnInteractionFailed(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnInteractionFailed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    Fragment.OnInteractionFailed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnInteractionFailed(FCk_Handle_Interactable& Self, FMars_Delegate_Interactable_OnInteractionFailed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnInteractionFailed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnInteractionStarted(FCk_Handle_Interactable& Self, FGameplayTag InChannel, FMars_Delegate_Interactable_OnInteractionStarted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    for (int32 Index = 0; Index < Fragment.ChanneledOnInteractionStarted.Num(); ++Index)
    {
        if (Fragment.ChanneledOnInteractionStarted[Index].Channel == InChannel)
        {
            Fragment.ChanneledOnInteractionStarted[Index].Delegates.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
            return;
        }
    }

    auto NewBinding = FMars_Interactable_ChanneledStartedBinding();
    NewBinding.Channel = InChannel;
    NewBinding.Delegates.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    Fragment.ChanneledOnInteractionStarted.Add(NewBinding);
}

mixin void UnbindFrom_OnInteractionStarted(FCk_Handle_Interactable& Self, FGameplayTag InChannel, FMars_Delegate_Interactable_OnInteractionStarted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    auto& Fragment = Self.Get_Fragment(FMars_Fragment_Interactable_Signals);
    for (int32 Index = 0; Index < Fragment.ChanneledOnInteractionStarted.Num(); ++Index)
    {
        if (Fragment.ChanneledOnInteractionStarted[Index].Channel == InChannel)
        {
            Fragment.ChanneledOnInteractionStarted[Index].Delegates.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
            return;
        }
    }
}

mixin void BindTo_OnInteractionFinished(FCk_Handle_Interactable& Self, FGameplayTag InChannel, FMars_Delegate_Interactable_OnInteractionFinished InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Interactable_Signals);
    for (int32 Index = 0; Index < Fragment.ChanneledOnInteractionFinished.Num(); ++Index)
    {
        if (Fragment.ChanneledOnInteractionFinished[Index].Channel == InChannel)
        {
            Fragment.ChanneledOnInteractionFinished[Index].Delegates.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
            return;
        }
    }

    auto NewBinding = FMars_Interactable_ChanneledFinishedBinding();
    NewBinding.Channel = InChannel;
    NewBinding.Delegates.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    Fragment.ChanneledOnInteractionFinished.Add(NewBinding);
}

mixin void UnbindFrom_OnInteractionFinished(FCk_Handle_Interactable& Self, FGameplayTag InChannel, FMars_Delegate_Interactable_OnInteractionFinished InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
    { return; }

    auto& Fragment = Self.Get_Fragment(FMars_Fragment_Interactable_Signals);
    for (int32 Index = 0; Index < Fragment.ChanneledOnInteractionFinished.Num(); ++Index)
    {
        if (Fragment.ChanneledOnInteractionFinished[Index].Channel == InChannel)
        {
            Fragment.ChanneledOnInteractionFinished[Index].Delegates.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
            return;
        }
    }
}
