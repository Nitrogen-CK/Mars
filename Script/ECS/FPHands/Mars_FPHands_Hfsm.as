// Hands sub-SM (under Alive, sibling of the Alive sub-SM). Rest is the resting glove pose; a Grab reach runs
// Reach -> Grip -> Return and always finishes on its own (a picked-up item removes its own target mid-grab); a Hold reach
// holds until the target is lost, then releases; a dropped or thrown item is followed through by a push. The phase itself
// lives on the FPHands feature: each state's enter task requests it, and leaving the sub-SM puts it back to None.
//
// The resolver is listened to in Rest, Hold, Release and Return: a new target interrupts a release or return (the reach
// continues from the gloves' current alpha) but is ignored mid-grab, mid-hold and mid-push rather than restarting them.
// Entering Rest, Release or Return re-reads the resolver, so a Hold target that became best while the gloves were busy
// and whose interaction is still live is reached for then - the gloves always end up on the device they are using.
// Entering Hold checks the reached target is still best, so a removal broadcast before Hold bound is not missed. Tasks
// and conditions only issue FPHands requests and read its getters; ck::Ctx is the player entity (the sub-SM inherits
// its parent's context).

namespace utils_fphands
{
    // The reach for InTarget: its interactable and owner as the subject, its completion policy and its own gesture. Every
    // task that asks the gloves to reach an interact target builds it here, so the drain sees one request as the reach
    // it is already on (Get_IsOnRequestedTarget) whoever asked first.
    FMars_Request_FPHands_StartReach Make_TargetReach(const FCk_Handle_InteractTarget& InTarget)
    {
        const auto& Context = InTarget.Get_Fragment(FMars_Fragment_InteractionContext);
        const auto Subject = FMars_FPHands_ReachSubject(InTarget, Context.Interactable, Context.InteractableOwner);
        return FMars_Request_FPHands_StartReach(Subject, InTarget.Get_InteractionCompletionPolicy(), Context.ReachKind);
    }
}

// Leaving it (Downed, a teardown) puts the gloves back to rest: the phase goes to None, which also forgets the reach
// target, so nothing is left stretched toward a device. A player already torn down has no gloves to reset.
class UMars_SmTask_HandsSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Hands_Rest;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        auto Hands = ck::Ctx(InHandle).As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hands))
        { return; }

        Hands.Request_SetPhase(FMars_Request_FPHands_SetPhase(EMars_FPHands_Phase::None));
    }
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
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        auto Hands = ck::Ctx(InHandle).As_FPHands();
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
        _Hands = Player.As_FPHands();
        _Use = Player.As_HeldItemUse(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Use))
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
    private void OnItemLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    {
        _Hands.Request_StartPush(FMars_Request_FPHands_StartPush(_Hands.Get_Hold(), InKind));
    }
}

// A reach or a hold interrupts a playing emote.
class UMars_SmTask_Hands_StopEmote : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        utils_fphands::Stop_Emote(ck::Ctx(InHandle).As_FPHands());
    }
}

// What the resolver binds do on enter, beyond listening.
enum EMars_FPHands_EnterSync
{
    // Rest, Release, Return: reach for a best Hold target whose interaction is live (it became best while the gloves were
    // busy).
    Resync,
    // Hold: let go when the reached target is no longer best (its removal may have been broadcast before Hold bound).
    VerifyTarget
}

// Resolver -> feature requests, in the states that can start or lose a target (Rest, Hold, Release, Return). A new
// Use- or Operate-intent target (Operate: a station's grip, opened only by the player's Operating state) starts a reach
// with the gesture its interaction context names (ReachKind); a removed one that is the current reach target releases. An
// entity without a resolver (tests) binds nothing.
class UMars_SmTask_HandsResolverBinds : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    protected EMars_FPHands_EnterSync EnterSync = EMars_FPHands_EnterSync::Resync;

    private FCk_Handle _Player;
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_InteractionResolver _Resolver;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Hands = _Player.As_FPHands();
        _Resolver = _Player.As_InteractionResolver(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Resolver))
        { return; }

        _Resolver.BindTo_OnBestTargetsChanged(
            FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));

        if (EnterSync == EMars_FPHands_EnterSync::VerifyTarget)
        {
            Release_IfNoLongerBest();
            return;
        }

        // Grab targets are never re-reached - a grab always finishes on its own. Use first, then Operate.
        if (TryResync(GameplayTags::InteractionIntent_Mars_Use))
        { return; }

        TryResync(GameplayTags::InteractionIntent_Mars_Operate);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Resolver))
        {
            _Resolver.UnbindFrom_OnBestTargetsChanged(
                FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
        }

        _Player = FCk_Handle();
        _Hands = FCk_Handle_FPHands();
        _Resolver = FCk_Handle_InteractionResolver();
    }

    private bool TryResync(FGameplayTag InIntent)
    {
        auto BestTargets = _Resolver.Get_BestInteractTargets(InIntent);
        for (auto Target : BestTargets)
        {
            if (ck::Is_NOT_Valid(Target) || Target.Has_Fragment(FMars_Fragment_InteractionContext) == false)
            { continue; }

            if (Target.Get_Fragment(FMars_Fragment_InteractionContext).ReachKind == EMars_FPHands_ReachKind::Grab)
            { continue; }

            if (ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(Target, _Player)))
            { continue; }

            Request_Reach(Target);
            return true;
        }

        return false;
    }

    private void Release_IfNoLongerBest()
    {
        if (_Hands.Get_ReachInteractTarget().IsSet() == false)
        { return; }

        if (Get_IsBestReachTarget(GameplayTags::InteractionIntent_Mars_Use)
            || Get_IsBestReachTarget(GameplayTags::InteractionIntent_Mars_Operate))
        { return; }

        _Hands.Request_Release(FMars_Request_FPHands_Release());
    }

    private bool Get_IsBestReachTarget(FGameplayTag InIntent)
    {
        auto BestTargets = _Resolver.Get_BestInteractTargets(InIntent);
        for (auto Target : BestTargets)
        {
            if (_Hands.Get_IsReachTarget(Target))
            { return true; }
        }

        return false;
    }

    private void Request_Reach(FCk_Handle_InteractTarget InTarget)
    {
        _Hands.Request_StartReach(utils_fphands::Make_TargetReach(InTarget));
    }

    UFUNCTION()
    private void OnBestTargetsChanged(FCk_Handle_InteractionResolver InResolver, FGameplayTag InIntent,
                                      const TArray<FCk_Handle_InteractTarget>&in InPreviousTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InNewTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InRemovedTargets)
    {
        const auto IsHandsIntent = InIntent == GameplayTags::InteractionIntent_Mars_Use
            || InIntent == GameplayTags::InteractionIntent_Mars_Operate;
        if (IsHandsIntent == false)
        { return; }

        for (auto Removed : InRemovedTargets)
        {
            if (_Hands.Get_IsReachTarget(Removed))
            { _Hands.Request_Release(FMars_Request_FPHands_Release()); }
        }

        for (auto Target : InNewTargets)
        {
            if (ck::Is_NOT_Valid(Target) || Target.Has_Fragment(FMars_Fragment_InteractionContext) == false)
            { continue; }

            Request_Reach(Target);
            return;
        }
    }
}

// Hold's resolver binds: no re-sync on enter (the reach that entered Hold already chose the target, and the drain would
// reject a second one as busy); instead the target is verified to still be best.
class UMars_SmTask_HandsResolverBinds_NoResync : UMars_SmTask_HandsResolverBinds
{
    default EnterSync = EMars_FPHands_EnterSync::VerifyTarget;
}

// Where a task acting at the gloves' Grip stands.
enum EMars_FPHands_GripWait
{
    // Not waiting: the task acted, failed, or never asked.
    None,
    // For the gloves' push to end before the task asks for the reach to its interaction's own target (a press during the
    // follow-through of a drop or throw).
    PushEnd,
    // For the gloves to answer the reach the task asked for its interaction's own target (a pickup, a dock's take).
    TargetReach,
    // For the gloves to answer the Place reach the task's caller requested (food onto a platter, a platter onto a dock).
    PlaceReach,
    // The gloves are on the awaited reach: only its Grip acts from here.
    Reaching
}

// The base of an interaction task that moves things at the gloves' Grip rather than on enter, so an item follows the hands
// (a pickup lands when the gloves close on it, a placed item leaves them where they set it down). A subclass starts the
// wait with Await_Grip or Await_PlaceGrip and does its work in DoAtGrip; a reach lost, or gloves that Return or let go
// before their Grip, fail the task through DoFail and nothing moves. Await_Grip asks the initiator's gloves for the reach to
// this interaction's target itself (the subject and gesture its interaction context names; once a push in progress has
// ended, waiting no longer than the push's own seconds plus k_PushEndGraceTicks), and acts at once without gloves or when
// they refuse that reach (busy with another target). Await_PlaceGrip waits for the Place reach its caller requests and
// fails when the gloves refuse it. The gloves answer a reach in the drain after it is asked: one neither taken nor refused
// by k_ReachAnswerTicks ticks after it was asked is a defect (an ensure), after which a target reach acts and a place
// fails. A failure names its EMars_Interaction_FailReason on the interaction's stamped context (DoFail), which the
// sub-SM's Failed end reports. The task ticks and returns _Outcome; a subclass that overrides DoTick or DoExitTask calls
// Super.
UCLASS(Abstract)
class UMars_SmTask_ActAtGrip : UMars_SmTask_InteractionWork
{

    // The gloves answer a reach in the drain after it is asked, so by this many ticks after the request it was taken or
    // refused.
    protected const int32 k_ReachAnswerTicks = 2;

    // The gloves' Push leaves for Rest one state-machine step after its seconds run out (utils_fphands::Get_PushSeconds),
    // and that phase edge reaches this task in the drain after: a PushEnd wait this many ticks past the push's seconds has
    // outlived the push (its phase frozen, the gloves' state machine torn down mid-push) and asks for the reach anyway.
    protected const int32 k_PushEndGraceTicks = 2;

    private EMars_FPHands_GripWait _GripWait = EMars_FPHands_GripWait::None;
    private FCk_Handle_FPHands _GripHands;
    // PushEnd and TargetReach only: this interaction's target (the state machine's context).
    private FCk_Handle_InteractTarget _GripTarget;
    // Ticks since the awaited reach was asked for; unset before it is asked and once the gloves answered it.
    private TOptional<int32> _TicksSinceAsked;
    // PushEnd only: how long the wait has run, and the ticks it has run past the push's seconds.
    private float32 _PushWaitSeconds = 0.0f;
    private int32 _TicksPastPush = 0;
    // The last frame's length: the gloves leave their Grip one state-machine step after its seconds run out.
    private float32 _LastDeltaSeconds = 0.0f;

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        _LastDeltaSeconds = float32(InDeltaT.Get_Seconds());
        Tick_ReachAnswer();
        Tick_PushEnd();
        return _Outcome;
    }

    // A task torn down before it acted or failed (its interaction ended under it) has moved nothing: it stops listening.
    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Stop_Waiting();
    }

    // Acts at the Grip of the reach InInitiator's gloves make for this interaction's target, which this task asks for.
    protected void Await_Grip(FCk_Handle InInitiator)
    {
        _GripHands = InInitiator.As_FPHands(ECk_SanityCheck::UnChecked);
        _GripTarget = Get_StateMachineContext().As_InteractTarget(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_GripHands))
        {
            Act_AtGrip();
            return;
        }

        const auto HasContext = ck::IsValid(_GripTarget) && _GripTarget.Has_Fragment(FMars_Fragment_InteractionContext);
        if (ck::EnsureIfNot(HasContext, f"[ActAtGrip] [{GetClass().GetName()}] awaits the gloves for [{_GripTarget.ToString()}], which is no interact target with an interaction context: acting without the grip"))
        {
            Act_AtGrip();
            return;
        }

        Start_Waiting(EMars_FPHands_GripWait::PushEnd);
        if (_GripHands.Get_Phase() == EMars_FPHands_Phase::Push)
        { return; }

        Ask_TargetReach();
    }

    // Acts at the Grip of the Place reach the caller requests on InHands right after this.
    protected void Await_PlaceGrip(FCk_Handle_FPHands InHands)
    {
        _GripHands = InHands;
        _GripTarget = FCk_Handle_InteractTarget();
        Start_Waiting(EMars_FPHands_GripWait::PlaceReach);
        _TicksSinceAsked = TOptional<int32>(0);
    }

    // The work the task waited for. Sets _Outcome.
    protected void DoAtGrip() {}

    // Called from DoAtGrip: how a mount taken now arrives so the item rides the gloves home: still for what is left of
    // their Grip (plus the frame the Hands state machine takes to enter Return), then over their return with its easing.
    // Unset when no gloves are gripping (no gloves, a refused reach): the item arrives as usual.
    protected TOptional<FMars_WorldItem_ArriveSpec> TryGet_RideHome() const
    {
        if (ck::Is_NOT_Valid(_GripHands) || _GripHands.Get_Phase() != EMars_FPHands_Phase::Grip)
        { return TOptional<FMars_WorldItem_ArriveSpec>(); }

        const auto& Grab = _GripHands.Get_Spec().Reach.Grab;
        const auto GripLeft = Math::Max(0.0f, Grab.GripSeconds - _GripHands.Get_PhaseTime()) + _LastDeltaSeconds;
        return TOptional<FMars_WorldItem_ArriveSpec>(FMars_WorldItem_ArriveSpec(GripLeft, Grab.BackSeconds, Grab.BackEasing));
    }

    // The reach the resolver's binds ask for too (UMars_SmTask_HandsResolverBinds), so a reach they already started is the
    // same reach.
    private void Ask_TargetReach()
    {
        _GripWait = EMars_FPHands_GripWait::TargetReach;
        _TicksSinceAsked = TOptional<int32>(0);
        _GripHands.Request_StartReach(utils_fphands::Make_TargetReach(_GripTarget));
    }

    // A push still running k_PushEndGraceTicks ticks past its own seconds: the reach is asked for now, and the gloves take or
    // refuse it.
    private void Tick_PushEnd()
    {
        if (_GripWait != EMars_FPHands_GripWait::PushEnd)
        { return; }

        _PushWaitSeconds += _LastDeltaSeconds;
        if (_PushWaitSeconds < utils_fphands::Get_PushSeconds(_GripHands.Get_Spec().Push))
        { return; }

        _TicksPastPush += 1;
        if (_TicksPastPush < k_PushEndGraceTicks)
        { return; }

        Ask_TargetReach();
    }

    // A reach the gloves have neither taken nor refused k_ReachAnswerTicks ticks after it was asked: they dropped it.
    private void Tick_ReachAnswer()
    {
        if (_TicksSinceAsked.IsSet() == false)
        { return; }

        const auto Ticks = _TicksSinceAsked.GetValue() + 1;
        _TicksSinceAsked = TOptional<int32>(Ticks);
        if (Ticks < k_ReachAnswerTicks)
        { return; }

        const auto Wait = _GripWait;
        if (ck::EnsureIfNot(false,
            f"[ActAtGrip] [{GetClass().GetName()}] the gloves [{_GripHands.ToString()}] neither took nor refused the {Wait :n} reach for [{_GripTarget.ToString()}] within {Ticks} ticks"))
        {
            if (Wait == EMars_FPHands_GripWait::PlaceReach)
            {
                Fail_Grip(EMars_Interaction_FailReason::PlaceReachUnanswered);
                return;
            }

            Act_AtGrip();
        }
    }

    // The gloves took the reach for this target (Reach: wait for its Grip), or already close on it (Grip: act now).
    private void Check_TargetReach()
    {
        if (ck::Is_NOT_Valid(_GripTarget) || _GripHands.Get_IsReachTarget(_GripTarget) == false)
        { return; }

        const auto Phase = _GripHands.Get_Phase();
        if (Phase == EMars_FPHands_Phase::Grip)
        {
            Act_AtGrip();
            return;
        }

        if (Phase == EMars_FPHands_Phase::Reach)
        {
            _TicksSinceAsked.Reset();
            _GripWait = EMars_FPHands_GripWait::Reaching;
        }
    }

    private void Start_Waiting(EMars_FPHands_GripWait InWait)
    {
        _GripWait = InWait;
        _TicksSinceAsked.Reset();
        _PushWaitSeconds = 0.0f;
        _TicksPastPush = 0;
        _GripHands.BindTo_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnGripReachRequested"));
        _GripHands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnGripPhaseChanged"));
        _GripHands.BindTo_OnReachTargetLost(FMars_Delegate_FPHands_OnReachTargetLost(this, n"OnGripReachTargetLost"));
        _GripHands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnGripReachRefused"));
    }

    private void Stop_Waiting()
    {
        if (ck::IsValid(_GripHands))
        {
            _GripHands.UnbindFrom_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnGripReachRequested"));
            _GripHands.UnbindFrom_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnGripPhaseChanged"));
            _GripHands.UnbindFrom_OnReachTargetLost(FMars_Delegate_FPHands_OnReachTargetLost(this, n"OnGripReachTargetLost"));
            _GripHands.UnbindFrom_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnGripReachRefused"));
        }

        _GripWait = EMars_FPHands_GripWait::None;
        _TicksSinceAsked.Reset();
    }

    private void Act_AtGrip()
    {
        Stop_Waiting();
        DoAtGrip();
    }

    private void Fail_Grip(EMars_Interaction_FailReason InReason)
    {
        Stop_Waiting();
        DoFail(InReason);
    }

    UFUNCTION()
    private void OnGripReachRequested(FCk_Handle_FPHands InHands, EMars_FPHands_ReachKind InKind)
    {
        if (_GripWait == EMars_FPHands_GripWait::PlaceReach && InKind == EMars_FPHands_ReachKind::Place)
        {
            _TicksSinceAsked.Reset();
            _GripWait = EMars_FPHands_GripWait::Reaching;
            return;
        }

        if (_GripWait == EMars_FPHands_GripWait::TargetReach)
        { Check_TargetReach(); }
    }

    UFUNCTION()
    private void OnGripPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        if (_GripWait == EMars_FPHands_GripWait::PushEnd)
        {
            if (InNew != EMars_FPHands_Phase::Push)
            { Ask_TargetReach(); }

            return;
        }

        if (_GripWait == EMars_FPHands_GripWait::TargetReach)
        {
            Check_TargetReach();
            return;
        }

        if (_GripWait != EMars_FPHands_GripWait::Reaching || InNew == EMars_FPHands_Phase::Reach)
        { return; }

        if (InNew != EMars_FPHands_Phase::Grip)
        {
            Fail_Grip(EMars_Interaction_FailReason::GlovesLeftBeforeGrip);
            return;
        }

        Act_AtGrip();
    }

    // A refused reach for this target: the gloves will not come, so the work happens now. A refused Place: nothing is set down.
    UFUNCTION()
    private void OnGripReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind,
                                    EMars_FPHands_ReachRefusal InReason)
    {
        if (_GripWait == EMars_FPHands_GripWait::TargetReach && ck::IsValid(_GripTarget) && InTarget == _GripTarget)
        {
            Act_AtGrip();
            return;
        }

        if (_GripWait == EMars_FPHands_GripWait::PlaceReach && InKind == EMars_FPHands_ReachKind::Place)
        { Fail_Grip(EMars_Interaction_FailReason::PlaceReachRefused); }
    }

    UFUNCTION()
    private void OnGripReachTargetLost(FCk_Handle_FPHands InHands)
    {
        if (_GripWait == EMars_FPHands_GripWait::Reaching)
        { Fail_Grip(EMars_Interaction_FailReason::GlovesLostTarget); }
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
        const auto Hands = ck::Ctx(InHandle).As_FPHands();
        const auto PhaseSeconds = utils_fphands::Get_PhaseSeconds(Phase, Hands.Get_Spec());
        return Hands.Get_Phase() == Phase && PhaseSeconds.IsSet() && Hands.Get_PhaseTime() >= PhaseSeconds.GetValue();
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

// Event-driven: OnReachRequested of a reach kind that plays the wanted gesture (Place plays Grab's). Rests at Fail; marks
// only from the signal handler.
class UMars_SmCondition_HandsReachRequested : UCk_SmCondition_EventDriven
{
    protected EMars_FPHands_ReachKind WantedKind = EMars_FPHands_ReachKind::Grab;

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
    private void OnReachRequested(FCk_Handle_FPHands InHands, EMars_FPHands_ReachKind InKind)
    {
        if (utils_fphands::Get_Gesture(InKind) == WantedKind)
        { MarkSatisfied(); }
    }
}

class UMars_SmCondition_HandsReachRequested_Instant : UMars_SmCondition_HandsReachRequested
{
    default WantedKind = EMars_FPHands_ReachKind::Grab;
}

class UMars_SmCondition_HandsReachRequested_Timed : UMars_SmCondition_HandsReachRequested
{
    default WantedKind = EMars_FPHands_ReachKind::Hold;
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
}

class UMars_SmState_Hands_Return : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToReach = AddTransition(InHandle, UMars_SmState_Hands_Reach);
        AddCondition(ToReach, UMars_SmCondition_HandsReachRequested_Instant);

        auto ToHold = AddTransition(InHandle, UMars_SmState_Hands_Hold);
        AddCondition(ToHold, UMars_SmCondition_HandsReachRequested_Timed);

        auto ToRest = AddTransition(InHandle, UMars_SmState_Hands_Rest);
        AddCondition(ToRest, UMars_SmCondition_HandsPhaseElapsed_Return);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_Return);
        AddTask(InHandle, UMars_SmTask_HandsResolverBinds);
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
        AddTask(InHandle, UMars_SmTask_HandsResolverBinds_NoResync);
    }
}

class UMars_SmState_Hands_Release : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToReach = AddTransition(InHandle, UMars_SmState_Hands_Reach);
        AddCondition(ToReach, UMars_SmCondition_HandsReachRequested_Instant);

        auto ToHold = AddTransition(InHandle, UMars_SmState_Hands_Hold);
        AddCondition(ToHold, UMars_SmCondition_HandsReachRequested_Timed);

        auto ToRest = AddTransition(InHandle, UMars_SmState_Hands_Rest);
        AddCondition(ToRest, UMars_SmCondition_HandsPhaseElapsed_Release);

        AddTask(InHandle, UMars_SmTask_Hands_SetPhase_Release);
        AddTask(InHandle, UMars_SmTask_HandsResolverBinds);
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
}
