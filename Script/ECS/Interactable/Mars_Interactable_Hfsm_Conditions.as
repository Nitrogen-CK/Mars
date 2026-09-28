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

class UMars_SmCondition_InteractableIsEnabled : UCk_SmCondition_EventDriven
{
    private FCk_Handle_Interactable CachedInteractable;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        CachedInteractable = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::EnsureIfNot(ck::IsValid(CachedInteractable), "InteractionContext is missing the Interactable handle"))
        { return; }

        CachedInteractable.BindTo_OnEnableDisableChanged(
            FMars_Delegate_Interactable_OnEnableDisableChanged(this, n"OnEnableDisableChanged"));

        if (CachedInteractable.Get_EnableDisable() == ECk_EnableDisable::Enable)
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(CachedInteractable))
        {
            CachedInteractable.UnbindFrom_OnEnableDisableChanged(
                FMars_Delegate_Interactable_OnEnableDisableChanged(this, n"OnEnableDisableChanged"));
        }
    }

    UFUNCTION()
    private void OnEnableDisableChanged(FCk_Handle_Interactable InInteractableHandle, ECk_EnableDisable InEnableDisable)
    {
        if (InEnableDisable == ECk_EnableDisable::Enable)
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }
}

class UMars_SmCondition_InteractableIsDisabled : UMars_SmCondition_InteractableIsEnabled
{
    default _NegateResult = true;
}

class UMars_SmCondition_InteractedWith : UCk_SmCondition_EventDriven
{
    private FCk_Handle_Interactable CachedInteractable;
    private FGameplayTag CachedChannel;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        CachedInteractable = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::EnsureIfNot(ck::IsValid(CachedInteractable), "InteractionContext is missing the Interactable handle"))
        { return; }

        auto TargetHandle = Get_OwningStateMachine().As_InteractTarget();
        CachedChannel = utils_interact_target::Get_InteractionChannel(TargetHandle);

        CachedInteractable.BindTo_OnInteractionFinished(CachedChannel,
            FMars_Delegate_Interactable_OnInteractionFinished(this, n"OnInteractionFinished"));

        MarkUnsatisfied();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(CachedInteractable))
        {
            CachedInteractable.UnbindFrom_OnInteractionFinished(CachedChannel,
                FMars_Delegate_Interactable_OnInteractionFinished(this, n"OnInteractionFinished"));
        }
    }

    UFUNCTION()
    private void OnInteractionFinished(FCk_Handle_Interactable InInteractable, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        if (InResult == ECk_SucceededFailed::Succeeded)
        { MarkSatisfied(); }
    }
}
