// Root (on the mimic's root, initial = Alive; context = the root, which overrides its context to itself first)
// |- Alive            ->Dead [IsDead: ByteAttribute.Mars.Monster.Dead == 1]
// |    tasks: BehaviorSubSm
// |    `- Behavior sub-SM (initial = Disguised)
// |         Disguised ->Waking [TargetNear]                      tasks: Disguise (EnterExitOnly): stop, sit down, lid shut
// |         Waking    ->Hunt [IsStanding]                        tasks: Wake (EnterExitOnly): stand up, lid ajar
// |         Hunt      ->Bite [CanBite] ->Return [NoTarget]       tasks: Hunt (Tick): chase on its feet, lid ajar
// |         Bite      ->Hunt [ActionDone]                        tasks: Bite (EnterExitOnly): Start(Bite)
// |         Return    ->Hunt [HasTarget] ->Disguised [AtHome]    tasks: Return (Tick): walk home, lid shut
// `- Dead             (sink)  tasks: Die (EnterExitOnly): stop, slump, lid agape, body zone off, corpse timer -> despawn
//
// The control layer over the kernel (Mars_PickleMimic_Processor_Tick.as): it moves the jar only through Drive / Stop,
// stands and sits only through SetStance, opens the lid only through Gape and bites only through Start; the kernel owns
// the posture's and the bite's clocks, the steering during a bite and the blow. A condition that admits the bite asks the
// kernel's own admission (Get_Admission), so the Start it leads to is admitted.

namespace utils_pickle_mimic
{
    // How far the lid hangs open (0 shut .. 1 wide): cracked as it wakes, ajar while it chases, slack once dead.
    const float32 WakeGape = 0.3f;
    const float32 HuntGape = 0.18f;
    const float32 DeadGape = 0.55f;

    // Return ends (and the disguise begins) within this distance of home, along the ground.
    const float64 HomeTolerance = 30.0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Conditions
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmCondition_PickleMimic_IsDead : UMars_SmCondition_ByteAttribute
{
    default AttributeTag = GameplayTags::ByteAttribute_Mars_Monster_Dead;
    default Comparison._Operator = ECk_ComparisonOperators::EqualTo;
    default Comparison._RHS = 1;
}

// Polled on the mimic (the context).
class UMars_SmCondition_PickleMimic : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        const auto Mimic = ck::Ctx(InHandle).As_PickleMimic(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Mimic))
        { return false; }

        return Evaluate(Mimic);
    }

    protected bool Evaluate(const FCk_Handle_PickleMimic& InMimic) const
    {
        return false;
    }
}

class UMars_SmCondition_PickleMimic_TargetNear : UMars_SmCondition_PickleMimic
{
    protected bool Evaluate(const FCk_Handle_PickleMimic& InMimic) const override
    {
        return InMimic.Get_IsTargetNear();
    }
}

class UMars_SmCondition_PickleMimic_HasTarget : UMars_SmCondition_PickleMimic
{
    protected bool Evaluate(const FCk_Handle_PickleMimic& InMimic) const override
    {
        return InMimic.Get_HasTarget();
    }
}

class UMars_SmCondition_PickleMimic_NoTarget : UMars_SmCondition_PickleMimic
{
    protected bool Evaluate(const FCk_Handle_PickleMimic& InMimic) const override
    {
        return InMimic.Get_HasTarget() == false;
    }
}

class UMars_SmCondition_PickleMimic_IsStanding : UMars_SmCondition_PickleMimic
{
    protected bool Evaluate(const FCk_Handle_PickleMimic& InMimic) const override
    {
        return InMimic.Get_IsStanding();
    }
}

class UMars_SmCondition_PickleMimic_CanBite : UMars_SmCondition_PickleMimic
{
    protected bool Evaluate(const FCk_Handle_PickleMimic& InMimic) const override
    {
        return InMimic.Get_IsActionBusy() == false &&
            InMimic.Get_Admission(EMars_PickleMimic_Action::Bite, InMimic.Get_Target()) == EMars_PickleMimic_Admission::Admitted;
    }
}

// Nothing runs and no Start is queued: the bite this state started is over (or was refused).
class UMars_SmCondition_PickleMimic_ActionDone : UMars_SmCondition_PickleMimic
{
    protected bool Evaluate(const FCk_Handle_PickleMimic& InMimic) const override
    {
        return InMimic.Get_IsActionBusy() == false;
    }
}

// Back on its spot (within utils_pickle_mimic::HomeTolerance of home, along the ground).
class UMars_SmCondition_PickleMimic_AtHome : UMars_SmCondition_PickleMimic
{
    protected bool Evaluate(const FCk_Handle_PickleMimic& InMimic) const override
    {
        const auto ToHome = InMimic.Get_Home() - InMimic.Get_Location();
        return FVector(ToHome.X, ToHome.Y, 0.0).Size() <= utils_pickle_mimic::HomeTolerance;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Root states
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmTask_PickleMimic_BehaviorSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_PickleMimic_Disguised;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmState_PickleMimic_Alive : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDead = AddTransition(InHandle, UMars_SmState_PickleMimic_Dead);
        AddCondition(ToDead, UMars_SmCondition_PickleMimic_IsDead);

        AddTask(InHandle, UMars_SmTask_PickleMimic_BehaviorSubSm);
    }
}

// A sink: nothing leaves it.
class UMars_SmState_PickleMimic_Dead : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_PickleMimic_Die);
    }
}

// The teardown, all of it requests: stop, sit down, let the lid hang open, disable the body zone, then start the corpse
// timer whose expiry destroys the root and everything it owns. The kernel ends a running bite itself on death; the glass
// shatters in the entity script (it watches the monster die).
class UMars_SmTask_PickleMimic_Die : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Mimic = ck::Ctx(InHandle).As_PickleMimic();
        if (ck::Is_NOT_Valid(Mimic))
        { return; }

        Mimic.Request_Stop(FMars_Request_PickleMimic_Stop());
        Mimic.Request_SetStance(FMars_Request_PickleMimic_SetStance(EMars_PickleMimic_Stance::Tucked));
        Mimic.Request_Gape(FMars_Request_PickleMimic_Gape(utils_pickle_mimic::DeadGape));

        auto Monster = Mimic.Get_Monster();
        auto BodyZone = Monster.Get_BodyZone();
        BodyZone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));

        utils_monster::Add_DespawnTimer(Mimic, Monster.Get_CorpseSeconds(), FCk_Delegate_Timer(this, n"OnCorpseExpired"));
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

class UMars_SmState_PickleMimic_Disguised : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToWaking = AddTransition(InHandle, UMars_SmState_PickleMimic_Waking);
        AddCondition(ToWaking, UMars_SmCondition_PickleMimic_TargetNear);

        AddTask(InHandle, UMars_SmTask_PickleMimic_Disguise);
    }
}

class UMars_SmState_PickleMimic_Waking : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHunt = AddTransition(InHandle, UMars_SmState_PickleMimic_Hunt);
        AddCondition(ToHunt, UMars_SmCondition_PickleMimic_IsStanding);

        AddTask(InHandle, UMars_SmTask_PickleMimic_Wake);
    }
}

// The bite is tried before giving up: a target in reach is bitten.
class UMars_SmState_PickleMimic_Hunt : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToBite = AddTransition(InHandle, UMars_SmState_PickleMimic_Bite);
        AddCondition(ToBite, UMars_SmCondition_PickleMimic_CanBite);

        auto ToReturn = AddTransition(InHandle, UMars_SmState_PickleMimic_Return);
        AddCondition(ToReturn, UMars_SmCondition_PickleMimic_NoTarget);

        AddTask(InHandle, UMars_SmTask_PickleMimic_Hunt);
    }
}

class UMars_SmState_PickleMimic_Bite : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHunt = AddTransition(InHandle, UMars_SmState_PickleMimic_Hunt);
        AddCondition(ToHunt, UMars_SmCondition_PickleMimic_ActionDone);

        AddTask(InHandle, UMars_SmTask_PickleMimic_Bite);
    }
}

class UMars_SmState_PickleMimic_Return : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToHunt = AddTransition(InHandle, UMars_SmState_PickleMimic_Hunt);
        AddCondition(ToHunt, UMars_SmCondition_PickleMimic_HasTarget);

        auto ToDisguised = AddTransition(InHandle, UMars_SmState_PickleMimic_Disguised);
        AddCondition(ToDisguised, UMars_SmCondition_PickleMimic_AtHome);

        AddTask(InHandle, UMars_SmTask_PickleMimic_Return);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Behaviour tasks
//--------------------------------------------------------------------------------------------------------------------------

// A still jar: it stops, sits down on its feet and shuts its lid.
class UMars_SmTask_PickleMimic_Disguise : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Mimic = ck::Ctx(InHandle).As_PickleMimic();
        if (ck::Is_NOT_Valid(Mimic))
        { return; }

        Mimic.Request_Stop(FMars_Request_PickleMimic_Stop());
        Mimic.Request_SetStance(FMars_Request_PickleMimic_SetStance(EMars_PickleMimic_Stance::Tucked));
        Mimic.Request_Gape(FMars_Request_PickleMimic_Gape(0.0f));
    }
}

// It springs up, the lid cracking open as the eyes come on.
class UMars_SmTask_PickleMimic_Wake : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Mimic = ck::Ctx(InHandle).As_PickleMimic();
        if (ck::Is_NOT_Valid(Mimic))
        { return; }

        Mimic.Request_SetStance(FMars_Request_PickleMimic_SetStance(EMars_PickleMimic_Stance::Standing));
        Mimic.Request_Gape(FMars_Request_PickleMimic_Gape(utils_pickle_mimic::WakeGape));
    }
}

// Chases the target at HuntSpeed along the ground, its lid ajar, easing to a stop as it comes within the bite's reach so it
// turns in place to face the target instead of circling it.
class UMars_SmTask_PickleMimic_Hunt : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    // It stops at this share of the bite's Range from the target and slows over this share of it beyond that.
    private const float64 k_StopShare = 0.6;
    private const float64 k_SlowShare = 1.2;

    private FCk_Handle_PickleMimic _Mimic;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Mimic = ck::Ctx(InHandle).As_PickleMimic();
        if (ck::IsValid(_Mimic))
        { _Mimic.Request_Gape(FMars_Request_PickleMimic_Gape(utils_pickle_mimic::HuntGape)); }
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Mimic) || _Mimic.Get_HasTarget() == false)
        { return ECk_SmTaskResult::Running; }

        const auto Spec = _Mimic.Get_Spec();
        const auto Up = _Mimic.Get_SurfaceUp();
        const auto Toward = _Mimic.Get_TargetLocation() - _Mimic.Get_Location();
        const auto OnGround = Toward - Up * Toward.DotProduct(Up);
        const auto Reach = Spec.Bite.Range;
        const auto Slowdown = Math::Clamp((OnGround.Size() - Reach * k_StopShare) / (Reach * k_SlowShare), 0.0, 1.0);
        _Mimic.Request_Drive(FMars_Request_PickleMimic_Drive(OnGround, Spec.Locomotion.HuntSpeed * float32(Slowdown)));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Mimic))
        { _Mimic.Request_Stop(FMars_Request_PickleMimic_Stop()); }

        _Mimic = FCk_Handle_PickleMimic();
    }
}

// Starts the bite on the target as it enters; the state leaves once the kernel has run it out (ActionDone).
class UMars_SmTask_PickleMimic_Bite : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Mimic = ck::Ctx(InHandle).As_PickleMimic();
        if (ck::Is_NOT_Valid(Mimic))
        { return; }

        Mimic.Request_Start(FMars_Request_PickleMimic_Start(EMars_PickleMimic_Action::Bite, Mimic.Get_Target()));
    }
}

// Walks back to its spot at ReturnSpeed with its lid shut, slowing over the last stretch (Disguised takes over there).
class UMars_SmTask_PickleMimic_Return : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_PickleMimic _Mimic;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Mimic = ck::Ctx(InHandle).As_PickleMimic();
        if (ck::IsValid(_Mimic))
        { _Mimic.Request_Gape(FMars_Request_PickleMimic_Gape(0.0f)); }
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Mimic))
        { return ECk_SmTaskResult::Running; }

        const auto ToHome = _Mimic.Get_Home() - _Mimic.Get_Location();
        const auto OnGround = FVector(ToHome.X, ToHome.Y, 0.0);
        const auto Slowdown = Math::Clamp(OnGround.Size() / (utils_pickle_mimic::HomeTolerance * 4.0), 0.25, 1.0);
        _Mimic.Request_Drive(FMars_Request_PickleMimic_Drive(OnGround, _Mimic.Get_Spec().Locomotion.ReturnSpeed * float32(Slowdown)));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Mimic))
        { _Mimic.Request_Stop(FMars_Request_PickleMimic_Stop()); }

        _Mimic = FCk_Handle_PickleMimic();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Readouts
//--------------------------------------------------------------------------------------------------------------------------

// The behaviour sub-SM's current state class (null outside Alive): the sub-SM task's machine is a lifetime dependent of the
// root machine's current state, a level or two down.
mixin TSubclassOf<UCk_SmState_EntityScript> Get_BehaviorStateClass(const FCk_Handle_PickleMimic& Self)
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
