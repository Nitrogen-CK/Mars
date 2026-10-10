class UMars_SmCondition_InteractableIsFocused : UCk_SmCondition_EventDriven
{
    private FCk_Handle_Interactable CachedInteractable;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        CachedInteractable = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::EnsureIfNot(ck::IsValid(CachedInteractable), "InteractionContext is missing the Interactable handle"))
        { return; }

        CachedInteractable.BindTo_OnFocused(FMars_Delegate_Interactable_OnFocused(this, n"OnFocused"));
        CachedInteractable.BindTo_OnUnfocused(FMars_Delegate_Interactable_OnUnfocused(this, n"OnUnfocused"));

        if (CachedInteractable.Get_IsFocused())
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(CachedInteractable))
        { return; }

        CachedInteractable.UnbindFrom_OnFocused(FMars_Delegate_Interactable_OnFocused(this, n"OnFocused"));
        CachedInteractable.UnbindFrom_OnUnfocused(FMars_Delegate_Interactable_OnUnfocused(this, n"OnUnfocused"));
    }

    UFUNCTION()
    private void OnFocused(FCk_Handle_Interactable InInteractableHandle, FCk_Handle InFocusedBy)
    { MarkSatisfied(); }

    UFUNCTION()
    private void OnUnfocused(FCk_Handle_Interactable InInteractableHandle, FCk_Handle InUnfocusedBy)
    { MarkUnsatisfied(); }
}

class UMars_SmCondition_InteractableIsNotFocused : UMars_SmCondition_InteractableIsFocused
{
    default _NegateResult = true;
}

// Satisfied while no held claim takes the interactable out of focus (Get_IsFocusable); a claim that keeps it focusable
// (a full hotbar, an operated station) only disables its targets.
class UMars_SmCondition_InteractableIsFocusable : UCk_SmCondition_EventDriven
{
    private FCk_Handle_Interactable CachedInteractable;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        CachedInteractable = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::EnsureIfNot(ck::IsValid(CachedInteractable), "InteractionContext is missing the Interactable handle"))
        { return; }

        CachedInteractable.BindTo_OnFocusableChanged(FMars_Delegate_Interactable_OnFocusableChanged(this, n"OnFocusableChanged"));

        if (CachedInteractable.Get_IsFocusable())
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(CachedInteractable))
        { CachedInteractable.UnbindFrom_OnFocusableChanged(FMars_Delegate_Interactable_OnFocusableChanged(this, n"OnFocusableChanged")); }
    }

    UFUNCTION()
    private void OnFocusableChanged(FCk_Handle_Interactable InInteractableHandle, ECk_EnableDisable InFocusable)
    {
        if (InFocusable == ECk_EnableDisable::Enable)
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }
}

class UMars_SmCondition_InteractableIsNotFocusable : UMars_SmCondition_InteractableIsFocusable
{
    default _NegateResult = true;
}

// A WhileLive target (its context's Work): satisfied while it has a live interaction, level-checked at enter and kept by
// its OnNewInteraction and OnInteractionFinished. Never satisfied on an AfterCompletion target.
class UMars_SmCondition_InteractionLive : UCk_SmCondition_EventDriven
{
    private FCk_Handle_InteractTarget _Target;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Target = utils_interactable::TryGet_WhileLiveTarget(Get_StateMachineContext());
        if (ck::Is_NOT_Valid(_Target))
        {
            MarkUnsatisfied();
            return;
        }

        _Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished"));
        Mark_FromRecord(FCk_Handle_Interaction());
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Target))
        {
            _Target.UnbindFrom_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
            _Target.UnbindFrom_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished"));
        }

        _Target = FCk_Handle_InteractTarget();
    }

    UFUNCTION()
    private void OnNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        Mark_FromRecord(FCk_Handle_Interaction());
    }

    // The finishing interaction is still in the record while its finish broadcasts.
    UFUNCTION()
    private void OnInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        Mark_FromRecord(InInteraction);
    }

    private void Mark_FromRecord(const FCk_Handle_Interaction& InFinishing)
    {
        if (ck::IsValid(utils_interactable::Get_LiveInteraction(_Target, InFinishing)))
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }
}

// A WhileLive target (its context's Work): satisfied once it has no live interaction left, level-checked at enter and kept
// by its OnNewInteraction and OnInteractionFinished; a cancel from outside the work ends Interacting with it. Never
// satisfied on an AfterCompletion target.
class UMars_SmCondition_InteractionEnded : UCk_SmCondition_EventDriven
{
    private FCk_Handle_InteractTarget _Target;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Target = utils_interactable::TryGet_WhileLiveTarget(Get_StateMachineContext());
        if (ck::Is_NOT_Valid(_Target))
        {
            MarkUnsatisfied();
            return;
        }

        _Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished"));
        Mark_FromRecord(FCk_Handle_Interaction());
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Target))
        {
            _Target.UnbindFrom_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
            _Target.UnbindFrom_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished"));
        }

        _Target = FCk_Handle_InteractTarget();
    }

    UFUNCTION()
    private void OnNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        Mark_FromRecord(FCk_Handle_Interaction());
    }

    // The finishing interaction is still in the record while its finish broadcasts.
    UFUNCTION()
    private void OnInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        Mark_FromRecord(InInteraction);
    }

    private void Mark_FromRecord(const FCk_Handle_Interaction& InFinishing)
    {
        if (ck::IsValid(utils_interactable::Get_LiveInteraction(_Target, InFinishing)))
        { MarkUnsatisfied(); }
        else
        { MarkSatisfied(); }
    }
}

// An AfterCompletion target (its context's Work): satisfied while the interactable holds a fresh completion of this target
// (TryGet_FreshCompletion), level-checked at enter and on every finish the interactable relays on the target's channel.
// Never satisfied on a WhileLive target.
class UMars_SmCondition_InteractionCompleted : UCk_SmCondition_EventDriven
{
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_InteractTarget _Target;
    private FGameplayTag _Channel;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Interactable = FCk_Handle_Interactable();
        auto Context = Get_StateMachineContext();
        const auto& InteractionContext = Context.Get_Fragment(FMars_Fragment_InteractionContext);
        if (InteractionContext.Work != EMars_Interactable_Work::AfterCompletion)
        {
            MarkUnsatisfied();
            return;
        }

        _Interactable = InteractionContext.Interactable;
        if (ck::EnsureIfNot(ck::IsValid(_Interactable), "InteractionContext is missing the Interactable handle"))
        { return; }

        _Target = Context.As_InteractTarget();
        _Channel = utils_interact_target::Get_InteractionChannel(_Target);
        _Interactable.BindTo_OnInteractionFinished(_Channel,
            FMars_Delegate_Interactable_OnInteractionFinished(this, n"OnInteractionFinished"));
        Mark_FromCompletion();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Interactable))
        {
            _Interactable.UnbindFrom_OnInteractionFinished(_Channel,
                FMars_Delegate_Interactable_OnInteractionFinished(this, n"OnInteractionFinished"));
        }

        _Interactable = FCk_Handle_Interactable();
    }

    UFUNCTION()
    private void OnInteractionFinished(FCk_Handle_Interactable InInteractable, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        Mark_FromCompletion();
    }

    private void Mark_FromCompletion()
    {
        if (_Interactable.TryGet_FreshCompletion(_Target).IsSet())
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }
}

// In a per-interaction sub-SM: satisfied once the interaction its root was stamped for (the target's interaction from the
// stamped Initiator) is no longer in the target's record, so the sub-SM terminates only after its end has drained. At once
// on an AfterCompletion target, whose interaction finished before the sub-SM ran.
class UMars_SmCondition_InteractionGone : UCk_SmCondition_EventDriven
{
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_Interaction _Interaction;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        FCk_Handle OwningSm = Get_OwningStateMachine();
        _Interaction = utils_interactable::TryGet_StampedInteraction(Get_StateMachineContext(), OwningSm);
        if (ck::Is_NOT_Valid(_Interaction))
        {
            MarkSatisfied();
            return;
        }

        _Target = Get_StateMachineContext().As_InteractTarget();
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished"));
        MarkUnsatisfied();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Target))
        { _Target.UnbindFrom_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished")); }

        _Target = FCk_Handle_InteractTarget();
        _Interaction = FCk_Handle_Interaction();
    }

    UFUNCTION()
    private void OnInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        if (InInteraction == _Interaction)
        { MarkSatisfied(); }
    }
}
