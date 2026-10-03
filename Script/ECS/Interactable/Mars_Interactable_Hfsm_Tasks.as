// Enter-time snapshot: adds every target's prompt to the focuser's display on focus, removes them on unfocus. A target
// whose availability changes while focused needs its own task (a snapshot gate would leave stale rows). A changed prompt
// refreshes the display itself (FMars_Fragment_InteractPrompt_DisplayBinding). A focuser without a display (a test, an
// NPC), or one that let go before this task entered, shows nothing.
class UMars_SmTask_Interactable_ShowPrompt : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    // Every prompt this task added to the display; removed by prompt on exit.
    private TArray<FCk_Handle_InteractPrompt> SubscribedPrompts;
    private FCk_Handle_InteractPromptDisplay PlayerDisplay;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Interactable = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::EnsureIfNot(ck::IsValid(Interactable), "InteractionContext is missing the Interactable handle"))
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

            auto Target = Prompt.As_InteractTarget();
            Target.UnbindFrom_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnTargetNewInteraction"));
            Target.UnbindFrom_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnTargetInteractionFinished"));
        }

        if (ck::IsValid(PlayerDisplay))
        {
            for (auto& Prompt : SubscribedPrompts)
            { PlayerDisplay.Request_RemovePrompt(FMars_Request_InteractPromptDisplay_RemovePrompt(Prompt)); }
        }
        SubscribedPrompts.Empty();
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

    // Records the in-progress interaction on the prompt so its widget can fill a hold bar. Only targets with a prompt
    // are bound.
    private void Set_PromptInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        auto Prompt = InTarget.As_InteractPrompt();
        Prompt.Request_SetInteraction(FMars_Request_InteractPrompt_SetInteraction(InInteraction));
    }
}

// A RequiresFreeHands target while focused: its prompt reads utils_interactable::Get_HandsFullText while the focuser's
// hands are full. Starting an interaction is refused by UMars_Interactable_FreeHandsPolicy, but the resolver only re-checks
// it when dirtied, so when the hands fill this task re-offers the target to the focuser's resolver (remove + add, drained
// in order): the re-resolve drops it from the best targets, and the resolver's consumers let go - the player's bridge
// cancels a live pull and the gloves release. A focuser without HeldItem binds nothing.
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
        if (ck::EnsureIfNot(ck::IsValid(Interactable), "InteractionContext is missing the Interactable handle"))
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
            auto Prompt = _Target.As_InteractPrompt(ECk_SanityCheck::UnChecked);
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

    // A RequiresFreeHands target without a prompt has nothing to block.
    private void Apply_Prompt()
    {
        if (ck::Is_NOT_Valid(_Target) || ck::Is_NOT_Valid(_Focuser))
        { return; }

        auto Prompt = _Target.As_InteractPrompt(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Prompt))
        { return; }

        auto Request = FMars_Request_InteractPrompt_SetBlocked();
        if (utils_interactable::Get_HandsAreFree(_Focuser) == false)
        { Request = FMars_Request_InteractPrompt_SetBlocked(utils_interactable::Get_HandsFullText()); }

        Prompt.Request_SetBlocked(Request);
    }

    // A focuser without a resolver (a test) has nothing to re-offer to.
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

    // Valid while this task holds a claim.
    private FCk_Handle _OutlineTarget;
    private FCk_Handle _OutlineSource;
    private FGameplayTag _OutlineTag;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Release_Outline();

        const auto& InteractableCtx = Get_StateMachineContext().Get_Fragment(FMars_Fragment_InteractionContext);
        auto Interactable = InteractableCtx.Interactable;
        if (ck::EnsureIfNot(ck::IsValid(Interactable), "InteractionContext is missing the Interactable handle"))
        { return; }

        auto Focuser = Interactable.Get_CurrentFocuser();
        if (ck::Is_NOT_Valid(Focuser))
        { return; }

        // Interactables hosted on the player are not world objects; outlining their owner would outline the player.
        if (InteractableCtx.InteractableOwner == Focuser)
        { return; }

        Claim_Outline(InteractableCtx.InteractableOwner);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Release_Outline();
    }

    private void Claim_Outline(FCk_Handle InTarget)
    {
        auto Target = InTarget;
        FCk_Handle Source = Get_OwningStateMachine();
        const auto Tag = UCk_Utils_Usf_Outline_Settings_UE::Get_GameplayInteractionOutlineTag();
        if (ck::Is_NOT_Valid(Target) || ck::Is_NOT_Valid(Source))
        { return; }

        UCk_Utils_Usf_Outline_UE::Set_OutlineClaim(Target, Source, Tag, ECk_Usf_OutlineScope::EntityAndDependents);
        if (UCk_Utils_Usf_Outline_UE::Has_OutlineClaim(Target, Source, Tag) == false)
        { return; }

        _OutlineTarget = Target;
        _OutlineSource = Source;
        _OutlineTag = Tag;
    }

    // The claim goes with its target: nothing to clear once the target is gone.
    private void Release_Outline()
    {
        if (ck::IsValid(_OutlineTarget) && ck::IsValid(_OutlineSource) &&
            UCk_Utils_Usf_Outline_UE::Has_OutlineClaim(_OutlineTarget, _OutlineSource, _OutlineTag))
        { UCk_Utils_Usf_Outline_UE::Clear_OutlineClaim(_OutlineTarget, _OutlineSource, _OutlineTag); }

        _OutlineTarget = FCk_Handle();
        _OutlineSource = FCk_Handle();
        _OutlineTag = FGameplayTag();
    }
}

// Runs the target's InteractionStateClass as a sub-SM. The sub-SM's context is the InteractTarget; the sub-SM root is
// stamped with a copy of the target's InteractionContext whose Initiator is the source of the interaction that started
// this run (recorded by UMars_Processor_Interactable_Setup when it started).
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
        if (ck::EnsureIfNot(ck::IsValid(SubSm), "The interaction sub-SM was constructed invalid"))
        { return; }

        auto TargetEntity = Get_StateMachineContext();
        const auto TargetContext = TargetEntity.Get_Fragment(FMars_Fragment_InteractionContext);
        if (ck::EnsureIfNot(ck::IsValid(TargetContext.Interactable), "InteractionContext is missing the Interactable handle"))
        { return; }

        // Stamped even when missing: the interaction's own state then fails on the invalid initiator.
        const auto Initiator = TargetContext.Interactable.Get_InitiatorOn(TargetEntity);
        ck::EnsureIfNot(ck::IsValid(Initiator),
            f"[Interactable] [{TargetEntity.ToString()}] runs an interaction with no recorded initiator");

        auto& StampedContext = SubSm.AddOrGet_Fragment(FMars_Fragment_InteractionContext);
        StampedContext.Interactable = TargetContext.Interactable;
        StampedContext.InteractableOwner = TargetContext.InteractableOwner;
        StampedContext.Initiator = Initiator;
    }
}
