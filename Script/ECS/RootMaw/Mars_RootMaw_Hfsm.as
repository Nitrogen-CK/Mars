// Root (on the Maw's root, initial = Alive; context = the root, which overrides its context to itself first)
// |- Alive            ->Dead [IsDead: ByteAttribute.Mars.Monster.Dead == 1]
// |    tasks: BehaviorSubSm
// |    `- Behavior sub-SM (initial = Buried)
// |         Buried    ->Emerging [ShouldWake]                    tasks: Burrow (EnterExitOnly): stop, sink in, jaw shut
// |         Emerging  ->Hunt [IsEmerged]                         tasks: Emerge (EnterExitOnly): burst up, maw wide
// |         Hunt      ->Bite [CanBite] ->Return [NoTarget]       tasks: Hunt (Tick): glide after it, maw agape
// |         Bite      ->Hunt [ActionDone]                        tasks: Bite (EnterExitOnly): Start(Bite)
// |         Return    ->Hunt [HasTarget] ->Buried [AtHome]       tasks: Return (Tick): glide home, jaw shut
// `- Dead             (sink)  tasks: Die (EnterExitOnly): stop, sink in, jaw slack, body zone off, corpse timer -> despawn
//
// The control layer over the kernel (Mars_RootMaw_Processor_Tick.as): it moves the Maw only through Drive / Stop, raises
// and buries it only through SetStance, opens the maw only through Gape and bites only through Start; the kernel owns the
// posture's and the bite's clocks, the steering during a bite and the blow. A condition that admits the bite asks the
// kernel's own admission (Get_Admission), so the Start it leads to is admitted. ShouldWake is a target within WakeRadius,
// or a blow that found it buried (the kernel's startle, fed from the body zone's hits; it also took the attacker as its
// target, so a blow from beyond WakeRadius wakes it onto whoever struck).

namespace utils_root_maw
{
    // How far the maw hangs open (0 teeth meeting .. 1 wide; the model's own mouth is 0.24): wide as it bursts up, agape
    // while it chases, slack once dead.
    const float32 EmergeGape = 1.0f;
    const float32 HuntGape = 0.45f;
    const float32 DeadGape = 0.6f;

    // Return ends (and the burial begins) within this distance of home, along the ground.
    const float64 HomeTolerance = 30.0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Conditions
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmCondition_RootMaw_IsDead : UMars_SmCondition_ByteAttribute
{
    default AttributeTag = GameplayTags::ByteAttribute_Mars_Monster_Dead;
    default Comparison._Operator = ECk_ComparisonOperators::EqualTo;
    default Comparison._RHS = 1;
}

// Polled on the Maw (the context).
class UMars_SmCondition_RootMaw : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        const auto Maw = ck::Ctx(InHandle).As_RootMaw(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Maw))
        { return false; }

        return Evaluate(Maw);
    }

    protected bool Evaluate(const FCk_Handle_RootMaw& InMaw) const
    {
        return false;
    }
}

// A target within WakeRadius, or a blow found it buried.
class UMars_SmCondition_RootMaw_ShouldWake : UMars_SmCondition_RootMaw
{
    protected bool Evaluate(const FCk_Handle_RootMaw& InMaw) const override
    {
        return InMaw.Get_IsStartled() || InMaw.Get_IsTargetNear();
    }
}

class UMars_SmCondition_RootMaw_HasTarget : UMars_SmCondition_RootMaw
{
    protected bool Evaluate(const FCk_Handle_RootMaw& InMaw) const override
    {
        return InMaw.Get_HasTarget();
    }
}

class UMars_SmCondition_RootMaw_NoTarget : UMars_SmCondition_RootMaw
{
    protected bool Evaluate(const FCk_Handle_RootMaw& InMaw) const override
    {
        return InMaw.Get_HasTarget() == false;
    }
}

class UMars_SmCondition_RootMaw_IsEmerged : UMars_SmCondition_RootMaw
{
    protected bool Evaluate(const FCk_Handle_RootMaw& InMaw) const override
    {
        return InMaw.Get_IsEmerged();
    }
}

class UMars_SmCondition_RootMaw_CanBite : UMars_SmCondition_RootMaw
{
    protected bool Evaluate(const FCk_Handle_RootMaw& InMaw) const override
    {
        return InMaw.Get_IsActionBusy() == false &&
            InMaw.Get_Admission(EMars_RootMaw_Action::Bite, InMaw.Get_Target()) == EMars_RootMaw_Admission::Admitted;
    }
}

// Nothing runs and no Start is queued: the bite this state started is over (or was refused).
class UMars_SmCondition_RootMaw_ActionDone : UMars_SmCondition_RootMaw
{
    protected bool Evaluate(const FCk_Handle_RootMaw& InMaw) const override
    {
        return InMaw.Get_IsActionBusy() == false;
    }
}

// Back on its spot (within utils_root_maw::HomeTolerance of home, along the ground).
class UMars_SmCondition_RootMaw_AtHome : UMars_SmCondition_RootMaw
{
    protected bool Evaluate(const FCk_Handle_RootMaw& InMaw) const override
    {
        const auto ToHome = InMaw.Get_Home() - InMaw.Get_Location();
        return FVector(ToHome.X, ToHome.Y, 0.0).Size() <= utils_root_maw::HomeTolerance;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Root states
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmTask_RootMaw_BehaviorSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_RootMaw_Buried;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmState_RootMaw_Alive : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDead = AddTransition(InHandle, UMars_SmState_RootMaw_Dead);
        AddCondition(ToDead, UMars_SmCondition_RootMaw_IsDead);

        AddTask(InHandle, UMars_SmTask_RootMaw_BehaviorSubSm);
    }
}

// A sink: nothing leaves it.
class UMars_SmState_RootMaw_Dead : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_RootMaw_Die);
    }
}

// The teardown, all of it requests: stop, sink back into the ground (over BurrowSeconds), let the jaw hang slack, disable
// the body zone, then start the corpse timer whose expiry destroys the root and everything it owns. The kernel ends a
// running bite itself on death; the entity script wilts the look and dims the eyes (it watches the monster die).
class UMars_SmTask_RootMaw_Die : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Maw = ck::Ctx(InHandle).As_RootMaw();
        if (ck::Is_NOT_Valid(Maw))
        { return; }

        Maw.Request_Stop(FMars_Request_RootMaw_Stop());
        Maw.Request_SetStance(FMars_Request_RootMaw_SetStance(EMars_RootMaw_Stance::Buried));
        Maw.Request_Gape(FMars_Request_RootMaw_Gape(utils_root_maw::DeadGape));

        auto Monster = Maw.Get_Monster();
        auto BodyZone = Monster.Get_BodyZone();
        BodyZone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));

        utils_monster::Add_DespawnTimer(Maw, Monster.Get_CorpseSeconds(), FCk_Delegate_Timer(this, n"OnCorpseExpired"));
    }

    UFUNCTION()
    private void OnCorpseExpired(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_monster::Request_DestroyTimerOwner(InTimer);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Behaviour sub-SM
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_RootMaw_Buried : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToEmerging = AddTransition(InHandle, UMars_SmState_RootMaw_Emerging);
        AddCondition(ToEmerging, UMars_SmCondition_RootMaw_ShouldWake);

        AddTask(InHandle, UMars_SmTask_RootMaw_Burrow);
    }
}

class UMars_SmState_RootMaw_Emerging : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHunt = AddTransition(InHandle, UMars_SmState_RootMaw_Hunt);
        AddCondition(ToHunt, UMars_SmCondition_RootMaw_IsEmerged);

        AddTask(InHandle, UMars_SmTask_RootMaw_Emerge);
    }
}

// The bite is tried before giving up: a target in reach is bitten.
class UMars_SmState_RootMaw_Hunt : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToBite = AddTransition(InHandle, UMars_SmState_RootMaw_Bite);
        AddCondition(ToBite, UMars_SmCondition_RootMaw_CanBite);

        auto ToReturn = AddTransition(InHandle, UMars_SmState_RootMaw_Return);
        AddCondition(ToReturn, UMars_SmCondition_RootMaw_NoTarget);

        AddTask(InHandle, UMars_SmTask_RootMaw_Hunt);
    }
}

class UMars_SmState_RootMaw_Bite : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHunt = AddTransition(InHandle, UMars_SmState_RootMaw_Hunt);
        AddCondition(ToHunt, UMars_SmCondition_RootMaw_ActionDone);

        AddTask(InHandle, UMars_SmTask_RootMaw_Bite);
    }
}

class UMars_SmState_RootMaw_Return : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHunt = AddTransition(InHandle, UMars_SmState_RootMaw_Hunt);
        AddCondition(ToHunt, UMars_SmCondition_RootMaw_HasTarget);

        auto ToBuried = AddTransition(InHandle, UMars_SmState_RootMaw_Buried);
        AddCondition(ToBuried, UMars_SmCondition_RootMaw_AtHome);

        AddTask(InHandle, UMars_SmTask_RootMaw_Return);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Behaviour tasks
//--------------------------------------------------------------------------------------------------------------------------

// The ambush: it stops, sinks into the ground until only its leaves show, and shuts its jaw.
class UMars_SmTask_RootMaw_Burrow : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Maw = ck::Ctx(InHandle).As_RootMaw();
        if (ck::Is_NOT_Valid(Maw))
        { return; }

        Maw.Request_Stop(FMars_Request_RootMaw_Stop());
        Maw.Request_SetStance(FMars_Request_RootMaw_SetStance(EMars_RootMaw_Stance::Buried));
        Maw.Request_Gape(FMars_Request_RootMaw_Gape(0.0f));
    }
}

// It bursts up out of the ground, maw wide, as the eyes come on.
class UMars_SmTask_RootMaw_Emerge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Maw = ck::Ctx(InHandle).As_RootMaw();
        if (ck::Is_NOT_Valid(Maw))
        { return; }

        Maw.Request_SetStance(FMars_Request_RootMaw_SetStance(EMars_RootMaw_Stance::Emerged));
        Maw.Request_Gape(FMars_Request_RootMaw_Gape(utils_root_maw::EmergeGape));
    }
}

// Glides after the target at HuntSpeed along the ground, its maw agape, easing to a stop as it comes within the bite's
// reach so it turns in place to face the target instead of circling it.
class UMars_SmTask_RootMaw_Hunt : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    // It stops at this share of the bite's Range from the target and slows over this share of it beyond that.
    private const float64 k_StopShare = 0.6;
    private const float64 k_SlowShare = 1.2;

    private FCk_Handle_RootMaw _Maw;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Maw = ck::Ctx(InHandle).As_RootMaw();
        if (ck::IsValid(_Maw))
        { _Maw.Request_Gape(FMars_Request_RootMaw_Gape(utils_root_maw::HuntGape)); }
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Maw) || _Maw.Get_HasTarget() == false)
        { return ECk_SmTaskResult::Running; }

        const auto Spec = _Maw.Get_Spec();
        const auto Up = _Maw.Get_SurfaceUp();
        const auto Toward = _Maw.Get_TargetLocation() - _Maw.Get_Location();
        const auto OnGround = Toward - Up * Toward.DotProduct(Up);
        const auto Reach = Spec.Bite.Range;
        const auto Slowdown = Math::Clamp((OnGround.Size() - Reach * k_StopShare) / (Reach * k_SlowShare), 0.0, 1.0);
        _Maw.Request_Drive(FMars_Request_RootMaw_Drive(OnGround, Spec.Locomotion.HuntSpeed * float32(Slowdown)));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Maw))
        { _Maw.Request_Stop(FMars_Request_RootMaw_Stop()); }

        _Maw = FCk_Handle_RootMaw();
    }
}

// Starts the bite on the target as it enters; the state leaves once the kernel has run it out (ActionDone).
class UMars_SmTask_RootMaw_Bite : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Maw = ck::Ctx(InHandle).As_RootMaw();
        if (ck::Is_NOT_Valid(Maw))
        { return; }

        Maw.Request_Start(FMars_Request_RootMaw_Start(EMars_RootMaw_Action::Bite, Maw.Get_Target()));
    }
}

// Glides back to its spot at ReturnSpeed with its jaw shut, slowing over the last stretch (Buried takes over there).
class UMars_SmTask_RootMaw_Return : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_RootMaw _Maw;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Maw = ck::Ctx(InHandle).As_RootMaw();
        if (ck::IsValid(_Maw))
        { _Maw.Request_Gape(FMars_Request_RootMaw_Gape(0.0f)); }
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Maw))
        { return ECk_SmTaskResult::Running; }

        const auto ToHome = _Maw.Get_Home() - _Maw.Get_Location();
        const auto OnGround = FVector(ToHome.X, ToHome.Y, 0.0);
        const auto Slowdown = Math::Clamp(OnGround.Size() / (utils_root_maw::HomeTolerance * 4.0), 0.25, 1.0);
        _Maw.Request_Drive(FMars_Request_RootMaw_Drive(OnGround, _Maw.Get_Spec().Locomotion.ReturnSpeed * float32(Slowdown)));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Maw))
        { _Maw.Request_Stop(FMars_Request_RootMaw_Stop()); }

        _Maw = FCk_Handle_RootMaw();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Readouts
//--------------------------------------------------------------------------------------------------------------------------

// The behaviour sub-SM's current state class (null outside Alive): the sub-SM task's machine is a lifetime dependent of the
// root machine's current state, a level or two down.
mixin TSubclassOf<UCk_SmState_EntityScript> Get_BehaviorStateClass(const FCk_Handle_RootMaw& Self)
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
