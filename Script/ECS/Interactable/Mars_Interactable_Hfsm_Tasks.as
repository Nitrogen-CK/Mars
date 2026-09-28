// Enter-time snapshot: adds every target's prompt on focus, removes them on unfocus. A target whose
// availability changes while focused needs its own task (a snapshot gate would leave stale rows).
class UMars_SmTask_Interactable_ShowPrompt : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    // Parallel arrays: SubscribedPrompts[i] was added to the display as StoredPromptIds[i].
    private TArray<FMars_InteractPromptDisplay_ID> StoredPromptIds;
    private TArray<FCk_Handle_InteractPrompt> SubscribedPrompts;
    private FCk_Handle_InteractPromptDisplay PlayerDisplay;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Interactable = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        auto Focuser = Interactable.Get_CurrentFocuser();
        if (ck::Is_NOT_Valid(Focuser))
        { return; }

        PlayerDisplay = Focuser.As_InteractPromptDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(PlayerDisplay))
        { return; }

        StoredPromptIds.Empty();
        SubscribedPrompts.Empty();

        auto AllTargets = Interactable.Get_AllInteractTargets();
        for (auto& Target : AllTargets)
        {
            auto Prompt = Target.As_InteractPrompt(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Prompt))
            { continue; }

            StoredPromptIds.Add(PlayerDisplay.Request_AddPrompt(FMars_Request_InteractPromptDisplay_AddPrompt(Prompt)));
            SubscribedPrompts.Add(Prompt);

            Prompt.BindTo_OnPromptChanged(FMars_Delegate_InteractPrompt_OnChanged(this, n"OnPromptChanged"));
            Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnTargetNewInteraction"));
            Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnTargetInteractionFinished"));
        }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        for (auto& Prompt : SubscribedPrompts)
        {
            if (ck::Is_NOT_Valid(Prompt))
            { continue; }

            Prompt.UnbindFrom_OnPromptChanged(FMars_Delegate_InteractPrompt_OnChanged(this, n"OnPromptChanged"));

            auto Target = FCk_Handle(Prompt).As_InteractTarget(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Target))
            {
                Target.UnbindFrom_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnTargetNewInteraction"));
                Target.UnbindFrom_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnTargetInteractionFinished"));
            }
        }
        SubscribedPrompts.Empty();

        if (ck::IsValid(PlayerDisplay))
        {
            for (auto& StoredId : StoredPromptIds)
            {
                if (StoredId.Value >= 0)
                { PlayerDisplay.Request_RemovePrompt(FMars_Request_InteractPromptDisplay_RemovePrompt(StoredId)); }
            }
        }
        StoredPromptIds.Empty();
    }

    UFUNCTION()
    private void OnPromptChanged(FCk_Handle_InteractPrompt InPrompt)
    {
        DoRefreshPrompt(InPrompt);
    }

    UFUNCTION()
    private void OnTargetNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        Set_PromptInteraction(InTarget, InInteraction);
    }

    UFUNCTION()
    private void OnTargetInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        Set_PromptInteraction(InTarget, FCk_Handle_Interaction());
    }

    // Records the in-progress interaction on the prompt so its widget can fill a hold bar.
    private void Set_PromptInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        auto Prompt = FCk_Handle(InTarget).As_InteractPrompt(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Prompt))
        { return; }

        Prompt.Get_Fragment(FMars_Fragment_InteractPrompt).CurrentInteraction = InInteraction;
        DoRefreshPrompt(Prompt);
    }

    private void DoRefreshPrompt(FCk_Handle_InteractPrompt InPrompt)
    {
        if (ck::Is_NOT_Valid(PlayerDisplay))
        { return; }

        for (int32 Index = 0; Index < SubscribedPrompts.Num(); ++Index)
        {
            if (SubscribedPrompts[Index] == InPrompt && StoredPromptIds[Index].Value >= 0)
            {
                PlayerDisplay.Request_RefreshPrompt(FMars_Request_InteractPromptDisplay_RefreshPrompt(StoredPromptIds[Index]));
                return;
            }
        }
    }
}

// Claims an outline on the interactable's owner and its live entity subtree while focused. The source is the
// owning state machine, so concurrent focus tasks clear only the claim they own. Only components hosted by the
// entity (utils_unreal_component) are outlined - see AMars_TestLamp.
class UMars_SmTask_Interactable_Outline : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle OutlineTarget;
    private FCk_Handle OutlineSource;
    private FGameplayTag OutlineTag;
    private bool OutlineActive = false;

    protected void Set_OutlineTag(FGameplayTag InOutlineTag)
    { OutlineTag = InOutlineTag; }

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        SetOutlineActive(false);

        const auto& InteractableCtx = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext);
        auto Interactable = InteractableCtx.Interactable;
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        auto Focuser = Interactable.Get_CurrentFocuser();
        if (ck::Is_NOT_Valid(Focuser))
        { return; }

        // Interactables hosted on the player are not world objects; outlining their owner would outline the player.
        if (utils_handle::IsEqual(InteractableCtx.InteractableOwner, Focuser))
        { return; }

        OutlineTarget = InteractableCtx.InteractableOwner;
        OutlineSource = Get_OwningStateMachine();
        if (OutlineTag.IsValid() == false)
        { OutlineTag = UCk_Utils_Usf_Outline_Settings_UE::Get_GameplayInteractionOutlineTag(); }

        SetOutlineActive(true);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        SetOutlineActive(false);
    }

    private void SetOutlineActive(bool bActive)
    {
        if (bActive)
        {
            if (OutlineActive || ck::Is_NOT_Valid(OutlineTarget) || ck::Is_NOT_Valid(OutlineSource))
            { return; }

            UCk_Utils_Usf_Outline_UE::Set_OutlineClaim(
                OutlineTarget, OutlineSource, OutlineTag, ECk_Usf_OutlineScope::EntityAndDependents);
            OutlineActive = UCk_Utils_Usf_Outline_UE::Has_OutlineClaim(OutlineTarget, OutlineSource, OutlineTag);
            return;
        }

        if (OutlineActive && ck::IsValid(OutlineTarget) && ck::IsValid(OutlineSource) &&
            UCk_Utils_Usf_Outline_UE::Has_OutlineClaim(OutlineTarget, OutlineSource, OutlineTag))
        { UCk_Utils_Usf_Outline_UE::Clear_OutlineClaim(OutlineTarget, OutlineSource, OutlineTag); }

        OutlineActive = false;
        OutlineTarget = FCk_Handle();
        OutlineSource = FCk_Handle();
    }
}

// Runs the target's InteractionStateClass as a sub-SM. The sub-SM's context is the InteractTarget;
// the initiator is snapshotted onto the sub-SM root's InteractionContext.
class UMars_SmTask_PerformInteractionSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_InteractTarget_Enter;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::SucceedOnStop;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        // The C++ EnterTask already spawned the sub-SM; catch the in-flight broadcast.
        auto TaskHandle = InHandle;
        TaskHandle.BindTo_OnSubSmConstructed(
            FCk_Delegate_SmTask_OnSubSmConstructed(this, n"OnSubSmConstructed"),
            ECk_Signal_BindingPolicy::FireIfPayloadInFlight,
            ECk_Signal_PostFireBehavior::Unbind);
    }

    UFUNCTION()
    private void OnSubSmConstructed(FCk_Handle_SmTask InTaskHandle, FCk_Sm_Payload_OnSubSmConstructed InPayload)
    {
        auto SubSm = InPayload.Get_SubStateMachineHandle();
        if (ck::Is_NOT_Valid(SubSm))
        { return; }

        const auto& TargetContext = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext);
        if (ck::Is_NOT_Valid(TargetContext.Interactable))
        { return; }

        auto& StampedContext = SubSm.AddOrGet_Fragment(FMars_Fragment_InteractionContext);
        StampedContext.Interactable = TargetContext.Interactable;
        StampedContext.InteractableOwner = TargetContext.InteractableOwner;
        StampedContext.Initiator = TargetContext.Interactable.Get_CurrentFocuser();
    }
}
