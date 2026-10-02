// Hands sub-SM (under Alive, sibling of the Alive sub-SM). Rest is the resting glove pose; an instant interaction runs
// Reach -> Grip -> Return and always finishes on its own (a picked-up item removes its own target mid-grab); a timed one
// holds until the target is lost, then releases; a dropped or thrown item is followed through by a push. The phase itself
// lives on the FPHands feature: each state's enter task requests it.
//
//   Rest    ->Push    [HandsPushRequested]   ->Reach [HandsReachRequested instant]   ->Hold [HandsReachRequested timed]
//   Reach   ->Grip    [HandsPhaseElapsed Reach]
//   Grip    ->Return  [HandsPhaseElapsed Grip]
//   Return  ->Rest    [HandsPhaseElapsed Return]
//   Hold    ->Release [HandsTargetLost]
//   Release ->Rest    [HandsPhaseElapsed Release]
//   Push    ->Rest    [HandsPhaseElapsed Push]
//
// The resolver is listened to only in Rest and Hold, so a new target arriving mid-grab is ignored rather than restarting
// the grab - the one deliberate difference from the gloves' behaviour on the character. Tasks and conditions only issue
// FPHands requests and read its getters; ck::Ctx is the player entity (the sub-SM inherits its parent's context).

class UMars_SmTask_HandsSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Hands_Rest;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

//--------------------------------------------------------------------------------------------------------------------------
// Tasks
//--------------------------------------------------------------------------------------------------------------------------

// Enter: the state's phase onto the feature. Subclasses only set Phase.
class UMars_SmTask_Hands_SetPhase : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    protected EMars_FPHands_Phase Phase = EMars_FPHands_Phase::None;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Hands = ck::Ctx(InHandle).As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hands))
        { return; }

        Hands.Request_SetPhase(FMars_Request_FPHands_SetPhase(Phase));
    }
}

class UMars_SmTask_Hands_SetPhase_None : UMars_SmTask_Hands_SetPhase
{
    default Phase = EMars_FPHands_Phase::None;
}

class UMars_SmTask_Hands_SetPhase_Reach : UMars_SmTask_Hands_SetPhase
{
    default Phase = EMars_FPHands_Phase::Reach;
}

class UMars_SmTask_Hands_SetPhase_Grip : UMars_SmTask_Hands_SetPhase
{
    default Phase = EMars_FPHands_Phase::Grip;
}

class UMars_SmTask_Hands_SetPhase_Return : UMars_SmTask_Hands_SetPhase
{
    default Phase = EMars_FPHands_Phase::Return;
}

class UMars_SmTask_Hands_SetPhase_Hold : UMars_SmTask_Hands_SetPhase
{
    default Phase = EMars_FPHands_Phase::Hold;
}

class UMars_SmTask_Hands_SetPhase_Release : UMars_SmTask_Hands_SetPhase
{
    default Phase = EMars_FPHands_Phase::Release;
}

class UMars_SmTask_Hands_SetPhase_Push : UMars_SmTask_Hands_SetPhase
{
    default Phase = EMars_FPHands_Phase::Push;
}

// HeldItemUse -> feature request, in Rest: a launched item starts a push from the hold the gloves still have (the item
// leaves the hands a frame or more after the launch). An entity without HeldItemUse (tests) binds nothing.
class UMars_SmTask_HandsLaunchBinds : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_HeldItemUse _Use;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Hands = Player.As_FPHands(ECk_SanityCheck::UnChecked);
        _Use = Player.As_HeldItemUse(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Hands) || ck::Is_NOT_Valid(_Use))
        { return; }

        _Use.BindTo_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnItemLaunched"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Use))
        { _Use.UnbindFrom_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnItemLaunched")); }

        _Hands = FCk_Handle_FPHands();
        _Use = FCk_Handle_HeldItemUse();
    }

    UFUNCTION()
    private void OnItemLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, bool InIsThrow)
    {
        if (ck::Is_NOT_Valid(_Hands))
        { return; }

        _Hands.Request_StartPush(FMars_Request_FPHands_StartPush(_Hands.Get_Hold(), InIsThrow));
    }
}

// A reach or a hold interrupts a playing emote (an actor API; an entity with no character, as in tests, has none to stop).
class UMars_SmTask_Hands_StopEmote : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Character = Cast<AMars_PlayerCharacter>(ck::ToActor(ck::Ctx(InHandle), ECk_SanityCheck::UnChecked));
        if (ck::Is_NOT_Valid(Character))
        { return; }

        Character.Stop_FPEmote();
    }
}

// Resolver -> feature requests, in the states that can start or lose a target (Rest, Hold). A new Use-intent target
// starts a reach (instant when its interaction completes instantly); a removed one that is the current reach target
// releases. An entity without a resolver (tests) binds nothing.
class UMars_SmTask_HandsResolverBinds : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_InteractionResolver _Resolver;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Hands = Player.As_FPHands(ECk_SanityCheck::UnChecked);
        _Resolver = Player.As_InteractionResolver(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Hands) || ck::Is_NOT_Valid(_Resolver))
        { return; }

        _Resolver.BindTo_OnBestTargetsChanged(
            FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Resolver))
        {
            _Resolver.UnbindFrom_OnBestTargetsChanged(
                FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
        }

        _Hands = FCk_Handle_FPHands();
        _Resolver = FCk_Handle_InteractionResolver();
    }

    UFUNCTION()
    private void OnBestTargetsChanged(FCk_Handle_InteractionResolver InResolver, FGameplayTag InIntent,
                                      const TArray<FCk_Handle_InteractTarget>&in InPreviousTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InNewTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InRemovedTargets)
    {
        if (InIntent != GameplayTags::InteractionIntent_Mars_Use || ck::Is_NOT_Valid(_Hands))
        { return; }

        for (auto Removed : InRemovedTargets)
        {
            if (Removed == _Hands.Get_InteractTarget())
            { _Hands.Request_Release(); }
        }

        for (auto Target : InNewTargets)
        {
            if (ck::Is_NOT_Valid(Target) || Target.Has_Fragment(FMars_Fragment_InteractionContext) == false)
            { continue; }

            const auto& Context = Target.Get_Fragment(FMars_Fragment_InteractionContext);
            const auto IsInstant = Target.Get_InteractionCompletionPolicy() == ECk_Interaction_CompletionPolicy::Instant;
            _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Target, Context.Interactable, Context.InteractableOwner, IsInstant));
            return;
        }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Conditions
//--------------------------------------------------------------------------------------------------------------------------

// Polled: the current phase has run its configured seconds. Phase set per subclass.
class UMars_SmCondition_HandsPhaseElapsed : UCk_SmCondition_Polled
{
    protected EMars_FPHands_Phase Phase = EMars_FPHands_Phase::None;

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Hands = ck::Ctx(InHandle).As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hands))
        { return false; }

        return Hands.Get_Phase() == Phase
            && Hands.Get_PhaseTime() >= utils_fphands::Get_PhaseSeconds(Phase, Hands.Get_Spec());
    }
}

class UMars_SmCondition_HandsPhaseElapsed_Reach : UMars_SmCondition_HandsPhaseElapsed
{
    default Phase = EMars_FPHands_Phase::Reach;
}

class UMars_SmCondition_HandsPhaseElapsed_Grip : UMars_SmCondition_HandsPhaseElapsed
{
    default Phase = EMars_FPHands_Phase::Grip;
}

class UMars_SmCondition_HandsPhaseElapsed_Return : UMars_SmCondition_HandsPhaseElapsed
{
    default Phase = EMars_FPHands_Phase::Return;
}

class UMars_SmCondition_HandsPhaseElapsed_Release : UMars_SmCondition_HandsPhaseElapsed
{
    default Phase = EMars_FPHands_Phase::Release;
}

class UMars_SmCondition_HandsPhaseElapsed_Push : UMars_SmCondition_HandsPhaseElapsed
{
    default Phase = EMars_FPHands_Phase::Push;
}

// Event-driven: OnPushRequested. Rests at Fail; marks only from the signal handler.
class UMars_SmCondition_HandsPushRequested : UCk_SmCondition_EventDriven
{
    private FCk_Handle_FPHands _Hands;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Hands = ck::Ctx(InHandle).As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(_Hands), "The Hands state machine's context entity has no FPHands"))
        { return; }

        _Hands.BindTo_OnPushRequested(FMars_Delegate_FPHands_OnPushRequested(this, n"OnPushRequested"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Hands))
        { _Hands.UnbindFrom_OnPushRequested(FMars_Delegate_FPHands_OnPushRequested(this, n"OnPushRequested")); }

        _Hands = FCk_Handle_FPHands();
    }

    UFUNCTION()
    private void OnPushRequested(FCk_Handle_FPHands InHands)
    {
        MarkSatisfied();
    }
}

// Event-driven: OnReachRequested with the wanted IsInstant. Rests at Fail; marks only from the signal handler.
class UMars_SmCondition_HandsReachRequested : UCk_SmCondition_EventDriven
{
    protected bool WantsInstant = true;

    private FCk_Handle_FPHands _Hands;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Hands = ck::Ctx(InHandle).As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(_Hands), "The Hands state machine's context entity has no FPHands"))
        { return; }

        _Hands.BindTo_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnReachRequested"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Hands))
        { _Hands.UnbindFrom_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnReachRequested")); }

        _Hands = FCk_Handle_FPHands();
    }

    UFUNCTION()
    private void OnReachRequested(FCk_Handle_FPHands InHands, bool InIsInstant)
    {
        if (InIsInstant == WantsInstant)
        { MarkSatisfied(); }
    }
}

class UMars_SmCondition_HandsReachRequested_Instant : UMars_SmCondition_HandsReachRequested
{
    default WantsInstant = true;
}

class UMars_SmCondition_HandsReachRequested_Timed : UMars_SmCondition_HandsReachRequested
{
    default WantsInstant = false;
}

// Event-driven: OnReachTargetLost. Rests at Fail; marks only from the signal handler.
class UMars_SmCondition_HandsTargetLost : UCk_SmCondition_EventDriven
{
    private FCk_Handle_FPHands _Hands;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Hands = ck::Ctx(InHandle).As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(_Hands), "The Hands state machine's context entity has no FPHands"))
        { return; }

        _Hands.BindTo_OnReachTargetLost(FMars_Delegate_FPHands_OnReachTargetLost(this, n"OnReachTargetLost"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Hands))
        { _Hands.UnbindFrom_OnReachTargetLost(FMars_Delegate_FPHands_OnReachTargetLost(this, n"OnReachTargetLost")); }

        _Hands = FCk_Handle_FPHands();
    }

    UFUNCTION()
    private void OnReachTargetLost(FCk_Handle_FPHands InHands)
    {
        MarkSatisfied();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// States
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_Hands_Rest : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToPush = AddTransition(InHandle, UMars_SmState_Hands_Push);
        AddCondition(ToPush, UMars_SmCondition_HandsPushRequested);

        auto ToReach = AddTransition(InHandle, UMars_SmState_Hands_Reach);
        AddCondition(ToReach, UMars_SmCondition_HandsReachRequested_Instant);

        auto ToHold = AddTransition(InHandle, UMars_SmState_Hands_Hold);
        AddCondition(ToHold, UMars_SmCondition_HandsReachRequested_Timed);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_None);
        AddTask(InHandle, UMars_SmTask_HandsResolverBinds);
        AddTask(InHandle, UMars_SmTask_HandsLaunchBinds);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Hands SM: Rest", n"HandsSM", 2.0f, FLinearColor(0.7f, 0.7f, 0.7f, 1.0f));
    }
}

class UMars_SmState_Hands_Reach : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToGrip = AddTransition(InHandle, UMars_SmState_Hands_Grip);
        AddCondition(ToGrip, UMars_SmCondition_HandsPhaseElapsed_Reach);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_Reach);
        AddTask(InHandle, UMars_SmTask_Hands_StopEmote);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Hands SM: Reach", n"HandsSM", 2.0f, FLinearColor(0.3f, 0.8f, 1.0f, 1.0f));
    }
}

class UMars_SmState_Hands_Grip : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToReturn = AddTransition(InHandle, UMars_SmState_Hands_Return);
        AddCondition(ToReturn, UMars_SmCondition_HandsPhaseElapsed_Grip);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_Grip);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Hands SM: Grip", n"HandsSM", 2.0f, FLinearColor(1.0f, 0.8f, 0.0f, 1.0f));
    }
}

class UMars_SmState_Hands_Return : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToRest = AddTransition(InHandle, UMars_SmState_Hands_Rest);
        AddCondition(ToRest, UMars_SmCondition_HandsPhaseElapsed_Return);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_Return);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Hands SM: Return", n"HandsSM", 2.0f, FLinearColor(0.3f, 1.0f, 0.6f, 1.0f));
    }
}

class UMars_SmState_Hands_Hold : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToRelease = AddTransition(InHandle, UMars_SmState_Hands_Release);
        AddCondition(ToRelease, UMars_SmCondition_HandsTargetLost);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_Hold);
        AddTask(InHandle, UMars_SmTask_Hands_StopEmote);
        AddTask(InHandle, UMars_SmTask_HandsResolverBinds);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Hands SM: Hold", n"HandsSM", 2.0f, FLinearColor(1.0f, 0.5f, 0.0f, 1.0f));
    }
}

class UMars_SmState_Hands_Release : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToRest = AddTransition(InHandle, UMars_SmState_Hands_Rest);
        AddCondition(ToRest, UMars_SmCondition_HandsPhaseElapsed_Release);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_Release);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Hands SM: Release", n"HandsSM", 2.0f, FLinearColor(1.0f, 0.4f, 0.7f, 1.0f));
    }
}

class UMars_SmState_Hands_Push : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToRest = AddTransition(InHandle, UMars_SmState_Hands_Rest);
        AddCondition(ToRest, UMars_SmCondition_HandsPhaseElapsed_Push);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_Push);
        AddTask(InHandle, UMars_SmTask_Hands_StopEmote);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Hands SM: Push", n"HandsSM", 2.0f, FLinearColor(0.4f, 0.6f, 1.0f, 1.0f));
    }
}
