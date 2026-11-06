// Root (on the bat's root, initial = Alive; context = the root, which overrides its context to itself first)
// |- Alive              ->Dead [IsDead: ByteAttribute.Mars.Monster.Dead == 1]
// |    tasks: BehaviorSubSm
// |    `- Behaviour sub-SM (initial = Roost); every flying state also ->Hurt [IsHurt]
// |         Roost      ->Hover [PerchLost] ->Alert [ShouldWake]                 SetPhase(Roosting), Hold
// |         Alert      ->Launch [AlertDone]                                      SetPhase(Alert)
// |         Launch     ->Roost [RouteFailed] ->Approach [LaunchDone + target] ->Patrol [LaunchDone]
// |                                                                              SetPhase(Launching), FlyTo(below perch)
// |         Patrol     ->Approach [HasTarget] ->Return [PatrolDone]              SetPhase(Patrolling), FlyTo(nodes in turn)
// |         Approach   ->Telegraph [CanSwoop: at the strike point + admitted] ->Return [NoTarget]                SetPhase(Approaching), FlyTo(strike point)
// |         Telegraph  ->Swoop [Committed] ->Approach [SwoopDone + target] ->Return [SwoopDone]   StartSwoop(target);
// |                                                                              the sortie's first: SetPhase(Screeching)
// |         Swoop      ->Recover [Recovering] ->Return [SwoopDone]               (the kernel flies it)
// |         Recover    ->Approach [SwoopDone + target] ->Return [SwoopDone]      (the kernel flies it)
// |         Return     ->Approach [HasTarget] ->Hover [PerchLost | RouteFailed] ->Brake [RouteReached]
// |                                                                              SetPhase(Returning), FlyTo(under the perch)
// |         Brake      ->Approach [HasTarget] ->Hover [PerchLost | RouteFailed] ->Perch [RouteReached]
// |                                                                              SetPhase(Braking), FlyTo(hang point, slow)
// |         Perch      ->Hover [PerchLost] ->Roost [PerchDone]                   SetPhase(Perching), Hold
// |         Hover      ->Approach [HasTarget] ->Return [HoverRetry]              SetPhase(Hovering), Hold
// |         Hurt       ->Return [NotHurt]                                        (the kernel holds Hit / Stunned)
// `- Dead               (sink)  tasks: Die: CancelSwoop(Died), Fall, body zone off, ReleaseRoost, corpse timer -> despawn
//
// The control layer over the kernel (Mars_Bat_Processor_Tick.as): it moves the bat only through FlyTo / Hold, names its
// behaviour only through SetPhase and swoops only through StartSwoop; the kernel owns the swoop's clocks and steering,
// the blow, the hurt clocks and the fall. A route condition trusts only an answer to a route issued in the phase its
// state set (Get_IsRouteFailedIn / Get_IsRouteReachedIn), so a stale answer from the previous state never moves it on.

namespace utils_bat
{
    // Launch drops this far under the hang point; Return flies to this far under it and Brake rises the rest of the way at
    // BrakeShare of cruise.
    const float64 LaunchDrop = 150.0;
    const float64 ApproachUnderPerch = 150.0;
    const float32 BrakeShare = 0.4f;

    // Approach re-issues its FlyTo when the strike point moved this far.
    const float64 StrikeRepathDistance = 60.0;

    // Telegraph starts only this close to the strike point.
    const float64 StrikeTolerance = 70.0;

    // While the swoop cools down the bat chases a point this far ahead of itself on the standoff circle, so it circles
    // the target instead of hanging still, and the next telegraph comes from a new bearing.
    const float64 OrbitLeadDeg = 45.0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Conditions
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmCondition_Bat_IsDead : UMars_SmCondition_ByteAttribute
{
    default AttributeTag = GameplayTags::ByteAttribute_Mars_Monster_Dead;
    default Comparison._Operator = ECk_ComparisonOperators::EqualTo;
    default Comparison._RHS = 1;
}

// Polled on the bat (the context).
class UMars_SmCondition_Bat : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        const auto Bat = ck::Ctx(InHandle).As_Bat(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Bat))
        { return false; }

        return Evaluate(Bat);
    }

    protected bool Evaluate(const FCk_Handle_Bat& InBat) const
    {
        return false;
    }
}

class UMars_SmCondition_Bat_IsHurt : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_IsHurt();
    }
}

class UMars_SmCondition_Bat_NotHurt : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_IsHurt() == false;
    }
}

class UMars_SmCondition_Bat_HasTarget : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_HasTarget();
    }
}

class UMars_SmCondition_Bat_NoTarget : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_HasTarget() == false;
    }
}

class UMars_SmCondition_Bat_PerchLost : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_HasPerch() == false;
    }
}

// A target, or (with RoostIdleSeconds and flight nodes) it has hung long enough to patrol.
class UMars_SmCondition_Bat_ShouldWake : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        if (InBat.Get_HasTarget())
        { return true; }

        const auto Spec = InBat.Get_Spec();
        return Spec.Timing.RoostIdleSeconds.IsSet() && Spec.FlightNodes.Num() > 0 &&
            InBat.Get_Phase() == EMars_Bat_Phase::Roosting && InBat.Get_PhaseClock() >= Spec.Timing.RoostIdleSeconds.GetValue();
    }
}

// The kernel has been in Phase for at least the spec's seconds for it.
class UMars_SmCondition_Bat_PhaseDone : UMars_SmCondition_Bat
{
    protected EMars_Bat_Phase Phase = EMars_Bat_Phase::Alert;

    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_Phase() == Phase && InBat.Get_PhaseClock() >= Get_Seconds(InBat.Get_Spec());
    }

    protected float32 Get_Seconds(const FMars_Bat_Spec& InSpec) const
    {
        return InSpec.Roost.AlertSeconds;
    }
}

class UMars_SmCondition_Bat_AlertDone : UMars_SmCondition_Bat_PhaseDone
{
    default Phase = EMars_Bat_Phase::Alert;
}

class UMars_SmCondition_Bat_LaunchDone : UMars_SmCondition_Bat_PhaseDone
{
    default Phase = EMars_Bat_Phase::Launching;

    protected float32 Get_Seconds(const FMars_Bat_Spec& InSpec) const override
    {
        return InSpec.Roost.LaunchSeconds;
    }
}

class UMars_SmCondition_Bat_LaunchDoneWithTarget : UMars_SmCondition_Bat_LaunchDone
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_HasTarget() && Super::Evaluate(InBat);
    }
}

class UMars_SmCondition_Bat_PerchDone : UMars_SmCondition_Bat_PhaseDone
{
    default Phase = EMars_Bat_Phase::Perching;

    protected float32 Get_Seconds(const FMars_Bat_Spec& InSpec) const override
    {
        return InSpec.Roost.PerchSeconds;
    }
}

// Hovering long enough to try the perch again, and it still has one.
class UMars_SmCondition_Bat_HoverRetry : UMars_SmCondition_Bat_PhaseDone
{
    default Phase = EMars_Bat_Phase::Hovering;

    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_HasPerch() && Super::Evaluate(InBat);
    }

    protected float32 Get_Seconds(const FMars_Bat_Spec& InSpec) const override
    {
        return InSpec.Timing.HoverRetrySeconds;
    }
}

// The route this state issued (in Phase) failed, explicitly.
class UMars_SmCondition_Bat_RouteFailed : UMars_SmCondition_Bat
{
    protected EMars_Bat_Phase Phase = EMars_Bat_Phase::Returning;

    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_IsRouteFailedIn(Phase);
    }
}

class UMars_SmCondition_Bat_LaunchFailed : UMars_SmCondition_Bat_RouteFailed
{
    default Phase = EMars_Bat_Phase::Launching;
}

class UMars_SmCondition_Bat_ReturnFailed : UMars_SmCondition_Bat_RouteFailed
{
    default Phase = EMars_Bat_Phase::Returning;
}

class UMars_SmCondition_Bat_BrakeFailed : UMars_SmCondition_Bat_RouteFailed
{
    default Phase = EMars_Bat_Phase::Braking;
}

// The route this state issued (in Phase) arrived.
class UMars_SmCondition_Bat_RouteReached : UMars_SmCondition_Bat
{
    protected EMars_Bat_Phase Phase = EMars_Bat_Phase::Returning;

    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_IsRouteReachedIn(Phase);
    }
}

class UMars_SmCondition_Bat_ReturnReached : UMars_SmCondition_Bat_RouteReached
{
    default Phase = EMars_Bat_Phase::Returning;
}

class UMars_SmCondition_Bat_BrakeReached : UMars_SmCondition_Bat_RouteReached
{
    default Phase = EMars_Bat_Phase::Braking;
}

class UMars_SmCondition_Bat_PatrolDone : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_Phase() == EMars_Bat_Phase::Patrolling &&
            InBat.Get_Fragment(FMars_Fragment_Bat_PatrolBlackboard).Progress == EMars_Bat_PatrolProgress::Finished;
    }
}

// It has reached its strike point (within StrikeTolerance) and the kernel would admit a swoop at the target now (the drain
// asks the same). Swooping from the edge of Range instead lets the committed flight run out short of the target.
class UMars_SmCondition_Bat_CanSwoop : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        if (InBat.Get_IsSwoopBusy() || InBat.Get_HasTarget() == false)
        { return false; }

        if ((InBat.Get_StrikePoint() - InBat.Get_Location()).Size() > utils_bat::StrikeTolerance)
        { return false; }

        return InBat.Get_SwoopAdmission(InBat.Get_Target()) == EMars_Bat_SwoopAdmission::Admitted;
    }
}

class UMars_SmCondition_Bat_SwoopCommitted : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_SwoopStage() == EMars_Bat_SwoopStage::Committed;
    }
}

class UMars_SmCondition_Bat_SwoopRecovering : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_SwoopStage() == EMars_Bat_SwoopStage::Recovering;
    }
}

// Nothing runs and no StartSwoop is queued: the swoop this state started is over (cancelled, refused or run out).
class UMars_SmCondition_Bat_SwoopDone : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_IsSwoopBusy() == false;
    }
}

class UMars_SmCondition_Bat_SwoopDoneWithTarget : UMars_SmCondition_Bat
{
    protected bool Evaluate(const FCk_Handle_Bat& InBat) const override
    {
        return InBat.Get_IsSwoopBusy() == false && InBat.Get_HasTarget();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Root states
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmTask_Bat_BehaviorSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Bat_Roost;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmState_Bat_Alive : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDead = AddTransition(InHandle, UMars_SmState_Bat_Dead);
        AddCondition(ToDead, UMars_SmCondition_Bat_IsDead);

        AddTask(InHandle, UMars_SmTask_Bat_BehaviorSubSm);
    }
}

// A sink: nothing leaves it.
class UMars_SmState_Bat_Dead : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_Bat_Die);
    }
}

// The teardown, all of it requests: end a running swoop (Died; the kernel already stopped its damage the frame the monster
// died), fall (the agent stops and leaves the crowd, the kernel drops the body to the ground), disable the body zone, give
// the roost back (once), then the corpse timer whose expiry destroys the root and everything it owns.
class UMars_SmTask_Bat_Die : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Bat = ck::Ctx(InHandle).As_Bat();
        if (ck::Is_NOT_Valid(Bat))
        { return; }

        Bat.Request_CancelSwoop(FMars_Request_Bat_CancelSwoop(EMars_Bat_SwoopCancel::Died));
        Bat.Request_Fall(FMars_Request_Bat_Fall());

        auto Monster = Bat.Get_Monster();
        auto BodyZone = Monster.Get_BodyZone();
        BodyZone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));

        Bat.Request_ReleaseRoost(FMars_Request_Bat_ReleaseRoost());

        utils_monster::Add_DespawnTimer(Bat, Monster.Get_CorpseSeconds(), FCk_Delegate_Timer(this, n"OnCorpseExpired"));
    }

    UFUNCTION()
    private void OnCorpseExpired(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_monster::Request_DestroyTimerOwner(InTimer);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Behaviour sub-SM states
//--------------------------------------------------------------------------------------------------------------------------

// Every behaviour state but Hurt yields to a blow first (->Hurt [IsHurt], its first transition).

class UMars_SmState_Bat_Roost : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToHover = AddTransition(InHandle, UMars_SmState_Bat_Hover);
        AddCondition(ToHover, UMars_SmCondition_Bat_PerchLost);

        auto ToAlert = AddTransition(InHandle, UMars_SmState_Bat_Alert);
        AddCondition(ToAlert, UMars_SmCondition_Bat_ShouldWake);

        AddTask(InHandle, UMars_SmTask_Bat_Roost);
    }
}

class UMars_SmState_Bat_Alert : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToLaunch = AddTransition(InHandle, UMars_SmState_Bat_Launch);
        AddCondition(ToLaunch, UMars_SmCondition_Bat_AlertDone);

        AddTask(InHandle, UMars_SmTask_Bat_Alert);
    }
}

// A launch that cannot even be routed (no volume, no bake, a blocked spot under the perch) leaves it hanging: Roost.
class UMars_SmState_Bat_Launch : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToRoost = AddTransition(InHandle, UMars_SmState_Bat_Roost);
        AddCondition(ToRoost, UMars_SmCondition_Bat_LaunchFailed);

        auto ToApproach = AddTransition(InHandle, UMars_SmState_Bat_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Bat_LaunchDoneWithTarget);

        auto ToPatrol = AddTransition(InHandle, UMars_SmState_Bat_Patrol);
        AddCondition(ToPatrol, UMars_SmCondition_Bat_LaunchDone);

        AddTask(InHandle, UMars_SmTask_Bat_Launch);
    }
}

class UMars_SmState_Bat_Patrol : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToApproach = AddTransition(InHandle, UMars_SmState_Bat_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Bat_HasTarget);

        auto ToReturn = AddTransition(InHandle, UMars_SmState_Bat_Return);
        AddCondition(ToReturn, UMars_SmCondition_Bat_PatrolDone);

        AddTask(InHandle, UMars_SmTask_Bat_Patrol);
    }
}

// The kernel drops a target it could not fly to (and ignores it a while), so a failed approach leaves through NoTarget.
class UMars_SmState_Bat_Approach : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToTelegraph = AddTransition(InHandle, UMars_SmState_Bat_Telegraph);
        AddCondition(ToTelegraph, UMars_SmCondition_Bat_CanSwoop);

        auto ToReturn = AddTransition(InHandle, UMars_SmState_Bat_Return);
        AddCondition(ToReturn, UMars_SmCondition_Bat_NoTarget);

        AddTask(InHandle, UMars_SmTask_Bat_Approach);
    }
}

class UMars_SmState_Bat_Telegraph : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToSwoop = AddTransition(InHandle, UMars_SmState_Bat_Swoop);
        AddCondition(ToSwoop, UMars_SmCondition_Bat_SwoopCommitted);

        auto ToApproach = AddTransition(InHandle, UMars_SmState_Bat_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Bat_SwoopDoneWithTarget);

        auto ToReturn = AddTransition(InHandle, UMars_SmState_Bat_Return);
        AddCondition(ToReturn, UMars_SmCondition_Bat_SwoopDone);

        AddTask(InHandle, UMars_SmTask_Bat_Telegraph);
    }
}

class UMars_SmState_Bat_Swoop : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToRecover = AddTransition(InHandle, UMars_SmState_Bat_Recover);
        AddCondition(ToRecover, UMars_SmCondition_Bat_SwoopRecovering);

        auto ToReturn = AddTransition(InHandle, UMars_SmState_Bat_Return);
        AddCondition(ToReturn, UMars_SmCondition_Bat_SwoopDone);
    }
}

class UMars_SmState_Bat_Recover : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToApproach = AddTransition(InHandle, UMars_SmState_Bat_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Bat_SwoopDoneWithTarget);

        auto ToReturn = AddTransition(InHandle, UMars_SmState_Bat_Return);
        AddCondition(ToReturn, UMars_SmCondition_Bat_SwoopDone);
    }
}

class UMars_SmState_Bat_Return : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToApproach = AddTransition(InHandle, UMars_SmState_Bat_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Bat_HasTarget);

        auto ToHoverLost = AddTransition(InHandle, UMars_SmState_Bat_Hover);
        AddCondition(ToHoverLost, UMars_SmCondition_Bat_PerchLost);

        auto ToHoverFailed = AddTransition(InHandle, UMars_SmState_Bat_Hover);
        AddCondition(ToHoverFailed, UMars_SmCondition_Bat_ReturnFailed);

        auto ToBrake = AddTransition(InHandle, UMars_SmState_Bat_Brake);
        AddCondition(ToBrake, UMars_SmCondition_Bat_ReturnReached);

        AddTask(InHandle, UMars_SmTask_Bat_Return);
    }
}

class UMars_SmState_Bat_Brake : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToApproach = AddTransition(InHandle, UMars_SmState_Bat_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Bat_HasTarget);

        auto ToHoverLost = AddTransition(InHandle, UMars_SmState_Bat_Hover);
        AddCondition(ToHoverLost, UMars_SmCondition_Bat_PerchLost);

        auto ToHoverFailed = AddTransition(InHandle, UMars_SmState_Bat_Hover);
        AddCondition(ToHoverFailed, UMars_SmCondition_Bat_BrakeFailed);

        auto ToPerch = AddTransition(InHandle, UMars_SmState_Bat_Perch);
        AddCondition(ToPerch, UMars_SmCondition_Bat_BrakeReached);

        AddTask(InHandle, UMars_SmTask_Bat_Brake);
    }
}

class UMars_SmState_Bat_Perch : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToHover = AddTransition(InHandle, UMars_SmState_Bat_Hover);
        AddCondition(ToHover, UMars_SmCondition_Bat_PerchLost);

        auto ToRoost = AddTransition(InHandle, UMars_SmState_Bat_Roost);
        AddCondition(ToRoost, UMars_SmCondition_Bat_PerchDone);

        AddTask(InHandle, UMars_SmTask_Bat_Perch);
    }
}

// The safe state: it holds where it is in the air. It never lands from here: only Return -> Brake -> Perch lands, and only
// while it has a perch.
class UMars_SmState_Bat_Hover : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHurt = AddTransition(InHandle, UMars_SmState_Bat_Hurt);
        AddCondition(ToHurt, UMars_SmCondition_Bat_IsHurt);

        auto ToApproach = AddTransition(InHandle, UMars_SmState_Bat_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Bat_HasTarget);

        auto ToReturn = AddTransition(InHandle, UMars_SmState_Bat_Return);
        AddCondition(ToReturn, UMars_SmCondition_Bat_HoverRetry);

        AddTask(InHandle, UMars_SmTask_Bat_Hover);
    }
}

class UMars_SmState_Bat_Hurt : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToReturn = AddTransition(InHandle, UMars_SmState_Bat_Return);
        AddCondition(ToReturn, UMars_SmCondition_Bat_NotHurt);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Behaviour tasks
//--------------------------------------------------------------------------------------------------------------------------

// Enter: names the phase (and, for the states that hold, stops).
class UMars_SmTask_Bat_Phase : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    protected EMars_Bat_Phase Phase = EMars_Bat_Phase::Roosting;
    protected bool Holds = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Bat = ck::Ctx(InHandle).As_Bat();
        if (ck::Is_NOT_Valid(Bat))
        { return; }

        Bat.Request_SetPhase(FMars_Request_Bat_SetPhase(Phase));
        if (Holds)
        { Bat.Request_Hold(FMars_Request_Bat_Hold()); }

        DoEnter(Bat);
    }

    protected void DoEnter(FCk_Handle_Bat& InBat)
    {
    }
}

class UMars_SmTask_Bat_Roost : UMars_SmTask_Bat_Phase
{
    default Phase = EMars_Bat_Phase::Roosting;
    default Holds = true;
}

class UMars_SmTask_Bat_Alert : UMars_SmTask_Bat_Phase
{
    default Phase = EMars_Bat_Phase::Alert;
}

class UMars_SmTask_Bat_Perch : UMars_SmTask_Bat_Phase
{
    default Phase = EMars_Bat_Phase::Perching;
    default Holds = true;
}

class UMars_SmTask_Bat_Hover : UMars_SmTask_Bat_Phase
{
    default Phase = EMars_Bat_Phase::Hovering;
    default Holds = true;
}

// Drops off the perch to LaunchDrop under the hang point.
class UMars_SmTask_Bat_Launch : UMars_SmTask_Bat_Phase
{
    default Phase = EMars_Bat_Phase::Launching;

    protected void DoEnter(FCk_Handle_Bat& InBat) override
    {
        // A new sortie: its first telegraph screeches again.
        InBat.Get_Fragment(FMars_Fragment_Bat_SortieBlackboard).Screeched = false;
        InBat.Request_FlyTo(FMars_Request_Bat_FlyTo(InBat.Get_HangPoint() - FVector(0.0, 0.0, utils_bat::LaunchDrop),
            InBat.Get_Spec().Flight.CruiseSpeed));
    }
}

// Flies back to ApproachUnderPerch under the hang point.
class UMars_SmTask_Bat_Return : UMars_SmTask_Bat_Phase
{
    default Phase = EMars_Bat_Phase::Returning;

    protected void DoEnter(FCk_Handle_Bat& InBat) override
    {
        InBat.Request_FlyTo(FMars_Request_Bat_FlyTo(InBat.Get_HangPoint() - FVector(0.0, 0.0, utils_bat::ApproachUnderPerch),
            InBat.Get_Spec().Flight.CruiseSpeed));
    }
}

// Rises the last stretch to the hang point, slowly.
class UMars_SmTask_Bat_Brake : UMars_SmTask_Bat_Phase
{
    default Phase = EMars_Bat_Phase::Braking;

    protected void DoEnter(FCk_Handle_Bat& InBat) override
    {
        InBat.Request_FlyTo(FMars_Request_Bat_FlyTo(InBat.Get_HangPoint(), InBat.Get_Spec().Flight.CruiseSpeed * utils_bat::BrakeShare));
    }
}

// Starts the swoop at the target as it enters; the kernel runs it out (or cancels it). The first telegraph of a sortie (since
// the last Launch) is named Screeching once the kernel has admitted it: presentation only (the AnimBP's Screech), the
// ledger runs the telegraph unchanged. It is asked for the frame after the admission because the drain applies SetPhase
// before StartSwoop.
class UMars_SmTask_Bat_Telegraph : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Bat _Bat;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Bat = ck::Ctx(InHandle).As_Bat();
        if (ck::IsValid(_Bat))
        { _Bat.Request_StartSwoop(FMars_Request_Bat_StartSwoop(_Bat.Get_Target())); }
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Bat) || _Bat.Get_Phase() != EMars_Bat_Phase::Telegraphing ||
            _Bat.Get_SwoopStage() != EMars_Bat_SwoopStage::Telegraphing)
        { return ECk_SmTaskResult::Running; }

        auto& Board = _Bat.Get_Fragment(FMars_Fragment_Bat_SortieBlackboard);
        if (Board.Screeched)
        { return ECk_SmTaskResult::Running; }

        Board.Screeched = true;
        _Bat.Request_SetPhase(FMars_Request_Bat_SetPhase(EMars_Bat_Phase::Screeching));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Bat = FCk_Handle_Bat();
    }
}

// Flies to the strike point over the target, following it as it moves. While the swoop cools down (or the dive line is
// blocked) it circles the target on the standoff circle instead, alternating direction every sortie, so it never hangs
// still between attacks and each telegraph comes from a new bearing. The strike point lies on that same circle, so the
// circling bat is always within tolerance of it when the cooldown ends.
class UMars_SmTask_Bat_Approach : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Bat _Bat;
    private TOptional<FVector> _Issued;
    private int32 _OrbitSign = 1;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Bat = ck::Ctx(InHandle).As_Bat();
        _Issued.Reset();
        if (ck::Is_NOT_Valid(_Bat))
        { return; }

        _OrbitSign = _Bat.Get_SwoopLedger().Generation % 2 == 0 ? 1 : -1;
        _Bat.Request_SetPhase(FMars_Request_Bat_SetPhase(EMars_Bat_Phase::Approaching));
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Bat) || _Bat.Get_HasTarget() == false || _Bat.Get_Phase() != EMars_Bat_Phase::Approaching)
        { return ECk_SmTaskResult::Running; }

        const auto Admission = _Bat.Get_SwoopAdmission(_Bat.Get_Target());
        const auto Circle = Admission == EMars_Bat_SwoopAdmission::Cooldown || Admission == EMars_Bat_SwoopAdmission::NoLineOfSight;
        const auto Goal = Circle ? _Bat.Get_OrbitPoint(_OrbitSign, utils_bat::OrbitLeadDeg) : _Bat.Get_StrikePoint();
        if (_Issued.IsSet() && (_Issued.GetValue() - Goal).Size() < utils_bat::StrikeRepathDistance)
        { return ECk_SmTaskResult::Running; }

        _Issued = Goal;
        _Bat.Request_FlyTo(FMars_Request_Bat_FlyTo(Goal, _Bat.Get_Spec().Flight.CruiseSpeed));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Bat = FCk_Handle_Bat();
        _Issued.Reset();
    }
}

// Flies the flight nodes in order, from the one after the last visited; a node whose route fails is skipped. Done once
// every node had its turn (the blackboard's Progress), then Return takes over.
class UMars_SmTask_Bat_Patrol : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Bat _Bat;
    private TOptional<FVector> _Issued;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Bat = ck::Ctx(InHandle).As_Bat();
        _Issued.Reset();
        if (ck::Is_NOT_Valid(_Bat))
        { return; }

        auto& Board = _Bat.Get_Fragment(FMars_Fragment_Bat_PatrolBlackboard);
        Board.Visited = 0;
        Board.Progress = _Bat.Get_Spec().FlightNodes.Num() > 0 ? EMars_Bat_PatrolProgress::Flying : EMars_Bat_PatrolProgress::Finished;
        _Bat.Request_SetPhase(FMars_Request_Bat_SetPhase(EMars_Bat_Phase::Patrolling));
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Bat) || _Bat.Get_Phase() != EMars_Bat_Phase::Patrolling)
        { return ECk_SmTaskResult::Running; }

        const auto Nodes = _Bat.Get_Spec().FlightNodes;
        auto& Board = _Bat.Get_Fragment(FMars_Fragment_Bat_PatrolBlackboard);
        if (Board.Progress == EMars_Bat_PatrolProgress::Finished || Nodes.Num() == 0)
        { return ECk_SmTaskResult::Running; }

        const auto Route = _Bat.Get_Route();
        const auto Answered = _Issued.IsSet() && Route.IssuedIn == EMars_Bat_Phase::Patrolling &&
            (Route.Goal - _Issued.GetValue()).Size() < 1.0 && Route.Outcome != EMars_Bat_RouteOutcome::Pending;
        if (_Issued.IsSet() && Answered == false)
        { return ECk_SmTaskResult::Running; }

        if (_Issued.IsSet())
        {
            Board.Visited += 1;
            Board.NextNode = (Board.NextNode + 1) % Nodes.Num();
            if (Board.Visited >= Nodes.Num())
            {
                Board.Progress = EMars_Bat_PatrolProgress::Finished;
                return ECk_SmTaskResult::Running;
            }
        }

        const auto Node = Nodes[Math::Clamp(Board.NextNode, 0, Nodes.Num() - 1)];
        _Issued = Node;
        _Bat.Request_FlyTo(FMars_Request_Bat_FlyTo(Node, _Bat.Get_Spec().Flight.CruiseSpeed));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Bat = FCk_Handle_Bat();
        _Issued.Reset();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Readouts
//--------------------------------------------------------------------------------------------------------------------------

// The behaviour sub-SM's current state class (null outside Alive): the sub-SM task's machine is a lifetime dependent of the
// root machine's current state, a level or two down.
mixin TSubclassOf<UCk_SmState_EntityScript> Get_BehaviorStateClass(const FCk_Handle_Bat& Self)
{
    auto RootMachine = Self.As_StateMachine(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(RootMachine))
    { return nullptr; }

    const auto RootState = utils_state_machine::Get_CurrentStateHandle(RootMachine);
    if (ck::Is_NOT_Valid(RootState))
    { return nullptr; }

    auto Frontier = utils_entity_lifetime::Get_LifetimeDependents(RootState);
    for (int32 Depth = 0; Depth < 2 && Frontier.Num() > 0; ++Depth)
    {
        auto Next = TArray<FCk_Handle>();
        for (auto Entity : Frontier)
        {
            const auto SubMachine = Entity.As_StateMachine(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(SubMachine))
            { return utils_state_machine::Get_CurrentStateClass(SubMachine); }

            Next.Append(Entity.Get_LifetimeDependents());
        }

        Frontier = Next;
    }

    return nullptr;
}
