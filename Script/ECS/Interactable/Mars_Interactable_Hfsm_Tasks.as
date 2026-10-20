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

// A RequiresFreeHands target while focused: its prompt is blocked HandsFull while the focuser's hands are full. Starting
// an interaction is refused by UMars_Interactable_FreeHandsPolicy, but the resolver only re-checks it when dirtied, so when the hands fill this task re-offers the target to the focuser's resolver (remove + add, drained
// in order): the re-resolve drops it from the best targets, and the resolver's consumers let go - the player's Use task
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

        const auto Reason = utils_interactable::Get_HandsAreFree(_Focuser)
            ? EMars_InteractPrompt_BlockedReason::None
            : EMars_InteractPrompt_BlockedReason::HandsFull;
        Prompt.Request_SetBlocked(FMars_Request_InteractPrompt_SetBlocked(Reason));
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

// Runs the target's InteractionStateClass as a sub-SM. The sub-SM's context is the InteractTarget; the sub-SM root is
// stamped with a copy of the target's InteractionContext whose Initiator is who the work is for: the source of a WhileLive
// target's live interaction, or the initiator of an AfterCompletion target's fresh completion (consumed here, so the work
// runs once per finish). The stamp lands before the sub-SM's first state enters. Leaving Interacting while a WhileLive
// interaction the sub-SM ran for is still live (a claim took the interactable out of focus, a teardown) ends it Failed:
// its work did not finish.
class UMars_SmTask_PerformInteractionSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_InteractTarget_Enter;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::SucceedOnStop;

    // Valid once the sub-SM was stamped for a WhileLive interaction.
    private FCk_Handle_InteractTarget _WhileLiveTarget;
    private FCk_Handle _Initiator;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _WhileLiveTarget = FCk_Handle_InteractTarget();
        _Initiator = FCk_Handle();

        // The C++ EnterTask already spawned the sub-SM; catch the in-flight broadcast.
        auto TaskHandle = InHandle;
        TaskHandle.BindTo_OnSubSmConstructed(
            FCk_Delegate_SmTask_OnSubSmConstructed(this, n"OnSubSmConstructed"),
            ECk_Signal_BindingPolicy::FireIfPayloadInFlight,
            ECk_Signal_PostFireBehavior::Unbind);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_WhileLiveTarget) && ck::IsValid(_Initiator))
        {
            auto Interaction = utils_interact_target::TryGet_Interaction(_WhileLiveTarget, _Initiator);
            if (ck::IsValid(Interaction))
            { utils_interaction::Request_EndInteraction(Interaction, FCk_Request_Interaction_EndInteraction(ECk_SucceededFailed::Failed)); }
        }

        _WhileLiveTarget = FCk_Handle_InteractTarget();
        _Initiator = FCk_Handle();
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

        auto Target = TargetEntity.As_InteractTarget();
        const auto Initiator = DoGet_Initiator(Target, TargetContext);

        // Stamped even when missing: the interaction's own state then fails on the invalid initiator.
        ck::EnsureIfNot(ck::IsValid(Initiator),
            f"[Interactable] [{TargetEntity.ToString()}] runs a [{TargetContext.Work :n}] interaction with no initiator to run it for");

        if (TargetContext.Work == EMars_Interactable_Work::WhileLive)
        {
            _WhileLiveTarget = Target;
            _Initiator = Initiator;
        }

        auto& StampedContext = SubSm.AddOrGet_Fragment(FMars_Fragment_InteractionContext);
        StampedContext = TargetContext;
        StampedContext.Initiator = Initiator;
    }

    // A WhileLive target's live interaction's source; an AfterCompletion target's fresh completion's initiator, whose
    // consume is queued here. Invalid when neither exists.
    private FCk_Handle DoGet_Initiator(const FCk_Handle_InteractTarget& InTarget, const FMars_Fragment_InteractionContext& InContext)
    {
        if (InContext.Work == EMars_Interactable_Work::WhileLive)
        {
            const auto Interaction = utils_interactable::Get_LiveInteraction(InTarget, FCk_Handle_Interaction());
            if (ck::Is_NOT_Valid(Interaction))
            { return FCk_Handle(); }

            return utils_interaction::Get_InteractionSource(Interaction);
        }

        auto Interactable = InContext.Interactable;
        const auto Completion = Interactable.TryGet_FreshCompletion(InTarget);
        if (Completion.IsSet() == false)
        { return FCk_Handle(); }

        Interactable.Request_ConsumeCompletion(FMars_Request_Interactable_ConsumeCompletion(Completion.GetValue().Serial));
        return Completion.GetValue().Initiator;
    }
}

// The per-interaction sub-SM's end: ends the WhileLive interaction its root was stamped for with Result. A failed work
// reported its reason when it failed (utils_interactable::Record_FailReason). An AfterCompletion target's interaction
// ended before the sub-SM ran: nothing to end. Subclasses only set Result.
UCLASS(Abstract)
class UMars_SmTask_EndInteraction : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    protected ECk_SucceededFailed Result = ECk_SucceededFailed::Succeeded;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        FCk_Handle OwningSm = Get_OwningStateMachine();
        auto Interaction = utils_interactable::TryGet_StampedInteraction(Get_StateMachineContext(), OwningSm);
        if (ck::Is_NOT_Valid(Interaction))
        { return; }

        utils_interaction::Request_EndInteraction(Interaction, FCk_Request_Interaction_EndInteraction(Result));
    }
}

class UMars_SmTask_EndInteraction_Succeeded : UMars_SmTask_EndInteraction
{
    default Result = ECk_SucceededFailed::Succeeded;
}

class UMars_SmTask_EndInteraction_Failed : UMars_SmTask_EndInteraction
{
    default Result = ECk_SucceededFailed::Failed;
}

// The base of a WhileLive work task (an interaction sub-SM's work state: a stow, a take, a deposit) that runs until its
// work answers. The subclass resets _Outcome to Running on enter, reads its interaction's ends with TryGet_InteractionEnds,
// sets _Outcome to Succeeded when the work lands, and calls DoFail with the reason when it does not; the task ticks and
// returns _Outcome, so the work state's AllTasksSucceeded / AnyTaskFailed conditions route the sub-SM to its end. A
// subclass that overrides DoTick calls Super.
UCLASS(Abstract)
class UMars_SmTask_InteractionWork : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    protected ECk_SmTaskResult _Outcome = ECk_SmTaskResult::Running;

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        return _Outcome;
    }

    // The work failed and nothing moved: InReason is reported (utils_interactable::Record_FailReason) and the task fails.
    protected void DoFail(EMars_Interaction_FailReason InReason)
    {
        utils_interactable::Record_FailReason(Get_OwningStateMachine(), InReason);
        _Outcome = ECk_SmTaskResult::Failed;
    }

    // The interactable's owner (the state machine's context is its interact target) and the initiator stamped on the
    // sub-SM root. A task run outside an interaction sub-SM has neither: ensured, and the task fails.
    protected bool TryGet_InteractionEnds(FCk_Handle& OutOwner, FCk_Handle& OutInitiator)
    {
        auto Context = Get_StateMachineContext();
        FCk_Handle SubSm = Get_OwningStateMachine();
        const auto HasContext = Context.Has_Fragment(FMars_Fragment_InteractionContext)
            && ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext);
        if (ck::EnsureIfNot(HasContext, f"[Interactable] [{GetClass().GetName()}] ran without an interaction context"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return false;
        }

        OutOwner = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        OutInitiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        return true;
    }
}
