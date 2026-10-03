// Enter-time snapshot: adds every target's prompt on focus, removes them on unfocus. A target whose
// availability changes while focused needs its own task (a snapshot gate would leave stale rows).
class UMars_SmTask_Interactable_ShowPrompt : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    // Every prompt this task added to the display (and bound OnPromptChanged on); removed by prompt on exit.
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

        SubscribedPrompts.Empty();

        auto AllTargets = Interactable.Get_AllInteractTargets();
        for (auto& Target : AllTargets)
        {
            auto Prompt = Target.As_InteractPrompt(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Prompt))
            { continue; }

            PlayerDisplay.Request_AddPrompt(FMars_Request_InteractPromptDisplay_AddPrompt(Prompt));
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

        if (ck::IsValid(PlayerDisplay))
        {
            for (auto& Prompt : SubscribedPrompts)
            { PlayerDisplay.Request_RemovePrompt(FMars_Request_InteractPromptDisplay_RemovePrompt(Prompt)); }
        }
        SubscribedPrompts.Empty();
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

    // Records the in-progress interaction on the prompt so its widget can fill a hold bar. The prompt's drain
    // broadcasts OnPromptChanged, which refreshes the display through OnPromptChanged below.
    private void Set_PromptInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        auto Prompt = FCk_Handle(InTarget).As_InteractPrompt(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Prompt))
        { return; }

        Prompt.Request_SetInteraction(FMars_Request_InteractPrompt_SetInteraction(InInteraction));
    }

    private void DoRefreshPrompt(FCk_Handle_InteractPrompt InPrompt)
    {
        if (ck::Is_NOT_Valid(PlayerDisplay))
        { return; }

        if (SubscribedPrompts.Contains(InPrompt))
        { PlayerDisplay.Request_RefreshPrompt(FMars_Request_InteractPromptDisplay_RefreshPrompt(InPrompt)); }
    }
}

// A RequiresFreeHands target while focused: its prompt reads constants_interactable::k_HandsFullText while the
// focuser's hands are full. Starting an interaction is refused by UMars_Interactable_FreeHandsPolicy, but the resolver
// only re-checks it when dirtied, so when the hands fill this task re-offers the target to the focuser's resolver
// (remove + add, drained in order): the re-resolve drops it from the best targets, and the resolver's consumers let go -
// the player's bridge cancels a live pull and the gloves release. A focuser without HeldItem binds nothing.
class UMars_SmTask_Interactable_HandsGate : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle _Focuser;
    private FCk_Handle_HeldItem _HeldItem;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Context = Get_StateMachineContext();
        if (Context.Has_Fragment(FMars_Tag_InteractTarget_RequiresFreeHands) == false)
        { return; }

        auto Interactable = Context.Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        _Focuser = Interactable.Get_CurrentFocuser();
        _HeldItem = _Focuser.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_HeldItem))
        { return; }

        _Target = Context.As_InteractTarget();
        _HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));
        Apply_Prompt();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_HeldItem))
        { _HeldItem.UnbindFrom_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged")); }

        if (ck::IsValid(_Target))
        {
            auto Prompt = FCk_Handle(_Target).As_InteractPrompt(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Prompt))
            { Prompt.Request_SetBlocked(FMars_Request_InteractPrompt_SetBlocked()); }
        }

        _Target = FCk_Handle_InteractTarget();
        _Focuser = FCk_Handle();
        _HeldItem = FCk_Handle_HeldItem();
    }

    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        Apply_Prompt();

        if (ck::IsValid(_Target) && ck::IsValid(_Focuser) && utils_interactable::Get_HandsAreFree(_Focuser) == false)
        { Reoffer_ToResolver(); }
    }

    private void Apply_Prompt()
    {
        if (ck::Is_NOT_Valid(_Target) || ck::Is_NOT_Valid(_Focuser))
        { return; }

        auto Prompt = FCk_Handle(_Target).As_InteractPrompt(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Prompt))
        { return; }

        auto Request = FMars_Request_InteractPrompt_SetBlocked();
        if (utils_interactable::Get_HandsAreFree(_Focuser) == false)
        { Request = FMars_Request_InteractPrompt_SetBlocked(constants_interactable::k_HandsFullText()); }

        Prompt.Request_SetBlocked(Request);
    }

    private void Reoffer_ToResolver()
    {
        auto Resolver = _Focuser.As_InteractionResolver(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Resolver))
        { return; }

        Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(_Target));
        Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
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
