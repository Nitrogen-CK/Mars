// Root (on the crawler root, initial = Alive; context = the crawler root, which overrides its context to itself first)
// |- Alive            ->Dead [IsDead: ByteAttribute.Mars.Monster.Dead == 1]
// |    tasks: BehaviorSubSm
// |    `- Behavior sub-SM (initial = Idle)
// |         Idle    ->Roam [LeafRoam]  ->Flinch [LeafFlinch]  ->Cower [LeafCower]  ->Engage [LeafEngage]   (no tasks: the hub)
// |         Roam    ->Idle [LeafNotRoam]     tasks: Roam (Tick): pick a goal in RoamBounds -> MoveTo -> arrive/fail -> dwell
// |         Flinch  ->Idle [LeafNotFlinch]   tasks: Flinch (Tick): Stop; after FlinchSeconds -> SetFact(IsHurt, false); a hit restarts it
// |         Cower   ->Idle [LeafNotCower]    tasks: Cower (EnterExitOnly): Stop
// |         Engage  ->Idle [LeafNotEngage]   tasks: EngageSubSm; exit: Stop + CancelAttack(StateExit), stage None
// |         `- Engage sub-SM (initial = Approach; each state one Tick task; transitions poll the Engage stage)
// |              Approach ->Prepare ->Wait          MoveTo the target (throttled); inside StartDistance or Arrived -> Prepare; Failed -> Wait
// |              Prepare  ->Attack ->Approach ->Wait   Stop; face at zero speed; admissible and not Warded -> Attack; out of range -> Approach; timeout -> Wait
// |              Attack   ->Wait                    StartAttack once; Cooldown -> Wait; not admitted -> Wait; exit cancels an offensive attack
// |              Wait     ->Approach                Stop; cooldown over and RetryUntil passed -> Approach
// `- Dead             (sink)  tasks: Die (EnterExitOnly): stop, brain off, shed legs, body zone off, corpse timer -> despawn
//
// The brain's leaf (the GOAP plan's first action, Mars_Crawler_Goap.as) is the only thing that moves the behaviour
// sub-SM: every leaf state exits to the Idle hub when the leaf stops matching, and Idle dispatches to the new leaf, so a
// new behaviour is one action + one state + one Idle transition. Nothing calls Request_Transition on this machine.
// Leaving Alive tears down the behaviour subtree (the Roam task's exit stops the navigator).
//
// Engage is the control layer over the attack kernel (Mars_Crawler_Processor_AttackTick.as): it moves the root only
// through the navigator and zero-speed SurfaceMotion steering, never a transform write. The kernel owns every attack
// clock and cancels on hurt, crippling and death itself, so the brain's replan latency never gates a cancellation.

//--------------------------------------------------------------------------------------------------------------------------
// Conditions
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmCondition_Crawler_IsDead : UMars_SmCondition_ByteAttribute
{
    default AttributeTag = GameplayTags::ByteAttribute_Mars_Monster_Dead;
    default Comparison._Operator = ECk_ComparisonOperators::EqualTo;
    default Comparison._RHS = 1;
}

class UMars_SmCondition_Crawler_LeafRoam : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Roam;
}

class UMars_SmCondition_Crawler_LeafNotRoam : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Roam;
    default LeafMatch = EMars_BrainLeaf_Match::Absent;
}

class UMars_SmCondition_Crawler_LeafFlinch : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Flinch;
}

class UMars_SmCondition_Crawler_LeafNotFlinch : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Flinch;
    default LeafMatch = EMars_BrainLeaf_Match::Absent;
}

class UMars_SmCondition_Crawler_LeafCower : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Cower;
}

class UMars_SmCondition_Crawler_LeafNotCower : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Cower;
    default LeafMatch = EMars_BrainLeaf_Match::Absent;
}

class UMars_SmCondition_Crawler_LeafEngage : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Engage;
}

class UMars_SmCondition_Crawler_LeafNotEngage : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Engage;
    default LeafMatch = EMars_BrainLeaf_Match::Absent;
}

//--------------------------------------------------------------------------------------------------------------------------
// Root states
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmTask_Crawler_BehaviorSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Crawler_Idle;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmState_Crawler_Alive : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDead = AddTransition(InHandle, UMars_SmState_Crawler_Dead);
        AddCondition(ToDead, UMars_SmCondition_Crawler_IsDead);

        AddTask(InHandle, UMars_SmTask_Crawler_BehaviorSubSm);
    }
}

// A sink: nothing leaves it. The Die task does the teardown (stop, brain off, shed legs, corpse timer, despawn).
class UMars_SmState_Crawler_Dead : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_Crawler_Die);
    }
}

// The teardown, all of it requests: stop the navigator, disable the brain, sever every still-attached part with the
// death's cause (their debris is world-owned and dies on its own timer), disable the body zone, then start the corpse
// timer whose expiry destroys the crawler root and everything it owns. The presentation keeps the body pose's collapse
// (no legs left): that is the corpse pose. This task is the only place the corpse timer exists.
class UMars_SmTask_Crawler_Die : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Crawler = ck::Ctx(InHandle).As_Crawler();
        if (ck::Is_NOT_Valid(Crawler))
        { return; }

        auto Monster = Crawler.Get_Monster();

        auto Navigator = Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());

        auto Brain = Crawler.Get_Brain();
        Brain.Request_SetEnabled(FMars_Request_Brain_SetEnabled(ECk_EnableDisable::Disable));

        // The monster's Die drain records the cause before the Dead attribute that brought this state in can read 1.
        const auto MaybeCause = Monster.Get_DeathCause();
        ck::EnsureIfNot(MaybeCause.IsSet(), f"[Crawler] [{Crawler.ToString()}] entered Dead with no death cause");
        const auto Cause = MaybeCause.IsSet() ? MaybeCause.GetValue() : FMars_DamageEvent();

        // An index loop: a range-for over the returned array yields read-only elements.
        auto Parts = Monster.Get_Parts();
        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            auto Part = Parts[Index];
            if (ck::Is_NOT_Valid(Part) || Part.Get_State() != EMars_BodyPart_State::Attached)
            { continue; }

            Part.Request_Sever(FMars_Request_BodyPart_Sever(Cause));
        }

        auto BodyZone = Monster.Get_BodyZone();
        BodyZone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));

        utils_monster::Add_DespawnTimer(Crawler, Monster.Get_CorpseSeconds(), FCk_Delegate_Timer(this, n"OnCorpseExpired"));
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

// The hub: no tasks; it leaves for whichever leaf state matches the brain's leaf (at most one does).
class UMars_SmState_Crawler_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToRoam = AddTransition(InHandle, UMars_SmState_Crawler_Roam);
        AddCondition(ToRoam, UMars_SmCondition_Crawler_LeafRoam);

        auto ToFlinch = AddTransition(InHandle, UMars_SmState_Crawler_Flinch);
        AddCondition(ToFlinch, UMars_SmCondition_Crawler_LeafFlinch);

        auto ToCower = AddTransition(InHandle, UMars_SmState_Crawler_Cower);
        AddCondition(ToCower, UMars_SmCondition_Crawler_LeafCower);

        auto ToEngage = AddTransition(InHandle, UMars_SmState_Crawler_Engage);
        AddCondition(ToEngage, UMars_SmCondition_Crawler_LeafEngage);
    }
}

class UMars_SmState_Crawler_Roam : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Crawler_Idle);
        AddCondition(ToIdle, UMars_SmCondition_Crawler_LeafNotRoam);

        AddTask(InHandle, UMars_SmTask_Crawler_Roam);
    }
}

class UMars_SmState_Crawler_Flinch : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Crawler_Idle);
        AddCondition(ToIdle, UMars_SmCondition_Crawler_LeafNotFlinch);

        AddTask(InHandle, UMars_SmTask_Crawler_Flinch);
    }
}

class UMars_SmState_Crawler_Cower : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Crawler_Idle);
        AddCondition(ToIdle, UMars_SmCondition_Crawler_LeafNotCower);

        AddTask(InHandle, UMars_SmTask_Crawler_Cower);
    }
}

class UMars_SmTask_Crawler_EngageSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Crawler_Engage_Approach;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

// Only an aggressive armed crawler holding a combat target gets here (its HasCombatTarget fact). However it is left (a
// flinch, a cower, a lost target, death), the navigator stops, any attack is cancelled (the kernel ignores a cancel with
// nothing to cancel) and the stage reads None.
class UMars_SmState_Crawler_Engage : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Crawler_Idle);
        AddCondition(ToIdle, UMars_SmCondition_Crawler_LeafNotEngage);

        AddTask(InHandle, UMars_SmTask_Crawler_EngageSubSm);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Crawler = ck::Ctx(InHandle).As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Crawler))
        { return; }

        auto Navigator = Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
        Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));

        if (Crawler.Has_Fragment(FMars_Fragment_Crawler_Engage) == false)
        { return; }

        auto& Engage = Crawler.Get_Fragment(FMars_Fragment_Crawler_Engage);
        Engage = FMars_Fragment_Crawler_Engage();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Engage sub-SM
//--------------------------------------------------------------------------------------------------------------------------

// Polled on the crawler's Engage stage, which the stage tasks write: each stage's task hands over by writing the next
// stage, and the current state's transition to it passes on the next evaluation.
class UMars_SmCondition_Crawler_EngageStage : UCk_SmCondition_Polled
{
    protected EMars_Crawler_EngageStage Stage = EMars_Crawler_EngageStage::None;

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        const auto Crawler = ck::Ctx(InHandle).As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Crawler))
        { return false; }

        return Crawler.Get_EngageStage() == Stage;
    }
}

class UMars_SmCondition_Crawler_EngageStage_Approach : UMars_SmCondition_Crawler_EngageStage
{
    default Stage = EMars_Crawler_EngageStage::Approach;
}

class UMars_SmCondition_Crawler_EngageStage_Prepare : UMars_SmCondition_Crawler_EngageStage
{
    default Stage = EMars_Crawler_EngageStage::Prepare;
}

class UMars_SmCondition_Crawler_EngageStage_Attack : UMars_SmCondition_Crawler_EngageStage
{
    default Stage = EMars_Crawler_EngageStage::Attack;
}

class UMars_SmCondition_Crawler_EngageStage_Wait : UMars_SmCondition_Crawler_EngageStage
{
    default Stage = EMars_Crawler_EngageStage::Wait;
}

class UMars_SmState_Crawler_Engage_Approach : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToPrepare = AddTransition(InHandle, UMars_SmState_Crawler_Engage_Prepare);
        AddCondition(ToPrepare, UMars_SmCondition_Crawler_EngageStage_Prepare);

        auto ToWait = AddTransition(InHandle, UMars_SmState_Crawler_Engage_Wait);
        AddCondition(ToWait, UMars_SmCondition_Crawler_EngageStage_Wait);

        AddTask(InHandle, UMars_SmTask_Crawler_Engage_Approach);
    }
}

class UMars_SmState_Crawler_Engage_Prepare : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToAttack = AddTransition(InHandle, UMars_SmState_Crawler_Engage_Attack);
        AddCondition(ToAttack, UMars_SmCondition_Crawler_EngageStage_Attack);

        auto ToApproach = AddTransition(InHandle, UMars_SmState_Crawler_Engage_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Crawler_EngageStage_Approach);

        auto ToWait = AddTransition(InHandle, UMars_SmState_Crawler_Engage_Wait);
        AddCondition(ToWait, UMars_SmCondition_Crawler_EngageStage_Wait);

        AddTask(InHandle, UMars_SmTask_Crawler_Engage_Prepare);
    }
}

class UMars_SmState_Crawler_Engage_Attack : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToWait = AddTransition(InHandle, UMars_SmState_Crawler_Engage_Wait);
        AddCondition(ToWait, UMars_SmCondition_Crawler_EngageStage_Wait);

        AddTask(InHandle, UMars_SmTask_Crawler_Engage_Attack);
    }
}

class UMars_SmState_Crawler_Engage_Wait : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToApproach = AddTransition(InHandle, UMars_SmState_Crawler_Engage_Approach);
        AddCondition(ToApproach, UMars_SmCondition_Crawler_EngageStage_Approach);

        AddTask(InHandle, UMars_SmTask_Crawler_Engage_Wait);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Engage stage tasks
//--------------------------------------------------------------------------------------------------------------------------

// The shared shape of the four stage tasks: on enter the crawler's Engage record names this task's stage and restarts the
// stage clock; each tick advances the clock and runs the stage, until the stage hands over (the record names another
// stage) and the transition tears the task down. Always Running.
class UMars_SmTask_Crawler_EngageStage : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    protected EMars_Crawler_EngageStage Stage = EMars_Crawler_EngageStage::None;
    protected FCk_Handle_Crawler _Crawler;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Crawler = ck::Ctx(InHandle).As_Crawler();
        if (ck::Is_NOT_Valid(_Crawler))
        { return; }

        auto& Engage = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Engage);
        Engage.Stage = Stage;
        Engage.StageElapsed = 0.0f;
        EnterStage(Engage);
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        // The enter's checked cast already ensured.
        if (ck::Is_NOT_Valid(_Crawler))
        { return ECk_SmTaskResult::Running; }

        auto& Engage = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Engage);
        if (Engage.Stage != Stage)
        { return ECk_SmTaskResult::Running; }

        Engage.StageElapsed += float32(InDeltaT.Get_Seconds());
        TickStage(Engage);
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Crawler))
        { ExitStage(); }

        _Crawler = FCk_Handle_Crawler();
    }

    protected void EnterStage(FMars_Fragment_Crawler_Engage& InOutEngage) {}

    protected void TickStage(FMars_Fragment_Crawler_Engage& InOutEngage) {}

    protected void ExitStage() {}

    // Wait, which hands back to Approach no sooner than InRetrySeconds from now (0: as soon as the cooldown is over).
    protected void HandOverToWait(FMars_Fragment_Crawler_Engage& InOutEngage, float32 InRetrySeconds)
    {
        InOutEngage.RetryUntil = InRetrySeconds;
        InOutEngage.Stage = EMars_Crawler_EngageStage::Wait;
    }

    protected FVector Get_TargetLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(_Crawler.Get_CombatTarget().As_Transform());
    }
}

// Closes on the combat target through the navigator, once no attack holds the crawler where it stands
// (Get_IsHeldByAttack). A MoveTo goes out on the stage's first tick (unless the target is
// already inside StartDistance), then again only once RepathSeconds have passed AND the target has moved more than
// RepathDistance since the last one: a target that stands still gets one route, so the navigator's stuck watchdog can
// fail it. Inside StartDistance, or Arrived, hands over to Prepare; a Failed move (NoPath or Stuck) hands over to Wait
// for BlockedRetrySeconds. The navigator's status is read only once its queued requests have drained.
class UMars_SmTask_Crawler_Engage_Approach : UMars_SmTask_Crawler_EngageStage
{
    default Stage = EMars_Crawler_EngageStage::Approach;

    protected void EnterStage(FMars_Fragment_Crawler_Engage& InOutEngage) override
    {
        InOutEngage.LastRepathAt.Reset();
    }

    protected void TickStage(FMars_Fragment_Crawler_Engage& InOutEngage) override
    {
        const auto Target = _Crawler.Get_CombatTarget();
        // A target that is no longer valid clears the HasCombatTarget fact, and the replan leaves Engage.
        if (_Crawler.Get_IsCombatTargetValid(Target) == false)
        { return; }

        if (_Crawler.Get_IsHeldByAttack())
        { return; }

        const auto Combat = _Crawler.Get_Spec().Combat;
        const auto TargetLocation = Get_TargetLocation();
        const auto Root = utils_transform::Get_EntityCurrentLocation(_Crawler.As_Transform());
        // The decision the attack tick ended its last pass on: the crawler's current target and its preferred attack.
        const auto Advice = _Crawler.Get_AttackEvaluation();
        if (Advice.Selection.Preferred.IsSet() == false)
        {
            HandOverToWait(InOutEngage, Combat.Targeting.BlockedRetrySeconds);
            return;
        }

        const auto Entry = utils_crawler::Find_ResolvedAttack(_Crawler.Get_Spec().ResolvedAttacks, Advice.Selection.Preferred.GetValue());
        if (ck::EnsureIfNot(Entry.IsSet(), f"[Crawler] [{_Crawler.ToString()}] prefers [{Advice.Selection.Preferred.GetValue().ToString()}], which its loadout does not resolve"))
        { return; }

        if ((TargetLocation - Root).Size2D() <= Entry.GetValue().Definition.Prepare.MaxDistance)
        {
            InOutEngage.Stage = EMars_Crawler_EngageStage::Prepare;
            return;
        }

        auto Navigator = _Crawler.Get_Navigator();
        if (InOutEngage.LastRepathAt.IsSet() == false)
        {
            RequestMoveTo(InOutEngage, TargetLocation);
            return;
        }

        if (Navigator.Get_HasPendingRequests())
        { return; }

        const auto Status = Navigator.Get_Status();
        if (Status == EMars_SurfaceNavigator_Status::Failed)
        {
            HandOverToWait(InOutEngage, Combat.Targeting.BlockedRetrySeconds);
            return;
        }

        if (Status == EMars_SurfaceNavigator_Status::Arrived)
        {
            InOutEngage.Stage = EMars_Crawler_EngageStage::Prepare;
            return;
        }

        const auto SinceRepath = InOutEngage.StageElapsed - InOutEngage.LastRepathAt.GetValue();
        if (SinceRepath < Combat.Targeting.RepathSeconds)
        { return; }

        // Idle here means something outside Engage stopped the move: route again.
        const auto TargetMoved = (TargetLocation - InOutEngage.LastRepathTarget).Size() > Combat.Targeting.RepathDistance;
        if (TargetMoved || Status == EMars_SurfaceNavigator_Status::Idle)
        { RequestMoveTo(InOutEngage, TargetLocation); }
    }

    private void RequestMoveTo(FMars_Fragment_Crawler_Engage& InOutEngage, FVector InTargetLocation)
    {
        auto Navigator = _Crawler.Get_Navigator();
        Navigator.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(InTargetLocation));
        InOutEngage.LastRepathAt = TOptional<float32>(InOutEngage.StageElapsed);
        InOutEngage.LastRepathTarget = InTargetLocation;
    }
}

// Stands and faces the target. One Stop on the first tick; once the navigator has drained it and is not Moving (it has
// relinquished SurfaceMotion's steering), a zero-speed steer toward the target on the support plane turns the root in
// place, re-sent only when that direction turns by more than 2 degrees. Then it polls the start admission: admissible
// hands over to Attack, OutOfRange back to Approach, and anything still in the way after Prepare.TimeoutSeconds to Wait
// for BlockedRetrySeconds. A Shun crawler facing a raised lit lantern (Get_IsWarded) holds here, facing its bearer,
// until the lantern is lowered or the timeout hands over to Wait: it hesitates, never flees.
class UMars_SmTask_Crawler_Engage_Prepare : UMars_SmTask_Crawler_EngageStage
{
    default Stage = EMars_Crawler_EngageStage::Prepare;

    private const float64 k_ReaimDegrees = 2.0;

    private bool _StopRequested = false;
    private TOptional<FVector> _AimedTangent;

    protected void EnterStage(FMars_Fragment_Crawler_Engage& InOutEngage) override
    {
        _StopRequested = false;
        _AimedTangent.Reset();
        _Crawler.Request_PrepareAttack(FMars_Request_Crawler_PrepareAttack(_Crawler.Get_CombatTarget(), ECk_EnableDisable::Enable));
    }

    protected void TickStage(FMars_Fragment_Crawler_Engage& InOutEngage) override
    {
        auto Navigator = _Crawler.Get_Navigator();
        if (_StopRequested == false)
        {
            Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
            _StopRequested = true;
            return;
        }

        const auto Combat = _Crawler.Get_Spec().Combat;
        if (_Crawler.Get_AttackPreparation().State == EMars_Attack_PreparationState::TimedOut)
        {
            HandOverToWait(InOutEngage, Combat.Targeting.BlockedRetrySeconds);
            return;
        }

        if (Navigator.Get_HasPendingRequests() || Navigator.Get_Status() == EMars_SurfaceNavigator_Status::Moving)
        { return; }

        const auto Target = _Crawler.Get_CombatTarget();
        if (_Crawler.Get_IsCombatTargetValid(Target) == false)
        { return; }

        AimAt(Get_TargetLocation());

        if (_Crawler.Get_IsWarded(Target))
        { return; }

        const auto Advice = _Crawler.Get_AttackEvaluation();
        if (Advice.Selection.Selected.IsSet())
        {
            InOutEngage.Stage = EMars_Crawler_EngageStage::Attack;
            return;
        }

        if (Advice.Selection.Preferred.IsSet() == false)
        {
            HandOverToWait(InOutEngage, Combat.Targeting.BlockedRetrySeconds);
            return;
        }

        const auto Entry = utils_crawler::Find_ResolvedAttack(_Crawler.Get_Spec().ResolvedAttacks, Advice.Selection.Preferred.GetValue());
        const auto Distance = (Get_TargetLocation() - utils_transform::Get_EntityCurrentLocation(_Crawler.As_Transform())).Size2D();
        if (Entry.IsSet() && Distance > Entry.GetValue().Definition.Prepare.MaxDistance)
        { InOutEngage.Stage = EMars_Crawler_EngageStage::Approach; }
    }

    // Anywhere but Attack, the readiness wait this stage started is abandoned (the attack it would admit never starts).
    protected void ExitStage() override
    {
        if (_Crawler.Get_EngageStage() != EMars_Crawler_EngageStage::Attack)
        { _Crawler.Request_PrepareAttack(FMars_Request_Crawler_PrepareAttack(_Crawler.Get_CombatTarget(), ECk_EnableDisable::Disable)); }
    }

    private void AimAt(FVector InTargetLocation)
    {
        auto Motion = _Crawler.Get_Motion();
        auto Up = utils_surface_motion::Get_SupportNormal(Motion).GetSafeNormal();
        if (Up.IsNearlyZero())
        { Up = FVector::UpVector; }

        const auto ToTarget = InTargetLocation - utils_transform::Get_EntityCurrentLocation(_Crawler.As_Transform());
        const auto Tangent = (ToTarget - Up * ToTarget.DotProduct(Up)).GetSafeNormal();
        if (Tangent.IsNearlyZero())
        { return; }

        if (_AimedTangent.IsSet() && Tangent.DotProduct(_AimedTangent.GetValue()) >= Math::Cos(Math::DegreesToRadians(k_ReaimDegrees)))
        { return; }

        _AimedTangent = TOptional<FVector>(Tangent);
        utils_surface_motion::Request_Steering(Motion, FCk_Request_SurfaceMotion_Steering(Tangent, 0.0f));
    }
}

// Asks the attack kernel for the evaluated attack on enter and follows it. Admission shows as a new attack generation; the kernel
// captures the root's heading as the committed direction, and the first tick that sees it re-sends that direction as a
// zero-speed steer, once, so nothing turns the root during the attack. Once the attack reaches Cooldown (normally or through
// a cancel) it hands over to Wait. A start that is not admitted shows as Idle with nothing queued on two consecutive
// ticks (the attack tick runs once per frame, after the request drain, so the second look follows it): that hands over
// to Wait for BlockedRetrySeconds, never a second start. Leaving while the attack is still offensive cancels it.
class UMars_SmTask_Crawler_Engage_Attack : UMars_SmTask_Crawler_EngageStage
{
    default Stage = EMars_Crawler_EngageStage::Attack;

    private int32 _GenerationAtStart = 0;
    private int32 _UnadmittedTicks = 0;
    private bool _CommittedSteerSent = false;

    protected void EnterStage(FMars_Fragment_Crawler_Engage& InOutEngage) override
    {
        _GenerationAtStart = _Crawler.Get_AttackGeneration();
        _UnadmittedTicks = 0;
        _CommittedSteerSent = false;

        const auto Advice = _Crawler.Get_AttackEvaluation();
        if (Advice.Selection.Selected.IsSet() == false)
        {
            HandOverToWait(InOutEngage, _Crawler.Get_Spec().Combat.Targeting.BlockedRetrySeconds);
            return;
        }

        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Crawler.Get_CombatTarget(),
            Advice.Selection.Selected.GetValue(), Advice.SelectionGeneration));
    }

    protected void TickStage(FMars_Fragment_Crawler_Engage& InOutEngage) override
    {
        const auto Phase = _Crawler.Get_AttackPhase();
        if (_Crawler.Get_AttackGeneration() != _GenerationAtStart)
        {
            if (_CommittedSteerSent == false)
            {
                _CommittedSteerSent = true;
                auto Motion = _Crawler.Get_Motion();
                utils_surface_motion::Request_Steering(Motion, FCk_Request_SurfaceMotion_Steering(_Crawler.Get_AttackCommittedDirection(), 0.0f));
            }

            if (Phase == EMars_Crawler_AttackPhase::Cooldown || Phase == EMars_Crawler_AttackPhase::Idle)
            { HandOverToWait(InOutEngage, 0.0f); }

            return;
        }

        if (_Crawler.Get_HasPendingCombatRequests() || Phase != EMars_Crawler_AttackPhase::Idle)
        {
            _UnadmittedTicks = 0;
            return;
        }

        ++_UnadmittedTicks;
        if (_UnadmittedTicks >= 2)
        { HandOverToWait(InOutEngage, _Crawler.Get_Spec().Combat.Targeting.BlockedRetrySeconds); }
    }

    protected void ExitStage() override
    {
        if (utils_crawler::Get_IsOffensivePhase(_Crawler.Get_AttackPhase()))
        { _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit)); }
    }
}

// Stands still until no attack holds the crawler (its cooldown is over) and RetryUntil has passed on the stage clock, then hands back to
// Approach while the combat target is still valid.
class UMars_SmTask_Crawler_Engage_Wait : UMars_SmTask_Crawler_EngageStage
{
    default Stage = EMars_Crawler_EngageStage::Wait;

    protected void EnterStage(FMars_Fragment_Crawler_Engage& InOutEngage) override
    {
        auto Navigator = _Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
    }

    protected void TickStage(FMars_Fragment_Crawler_Engage& InOutEngage) override
    {
        if (_Crawler.Get_IsHeldByAttack() || InOutEngage.StageElapsed < InOutEngage.RetryUntil)
        { return; }

        if (_Crawler.Get_IsCombatTargetValid(_Crawler.Get_CombatTarget()))
        { InOutEngage.Stage = EMars_Crawler_EngageStage::Approach; }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Behaviour tasks
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Crawler_RoamPhase
{
    Pick,
    // A MoveTo is out: waiting for Arrived or Failed.
    Travel,
    Dwell
}

// Pick a goal in RoamBounds - a Seek crawler standing in lantern light picks the light (TryGet_LightLure) - (once no
// attack holds the crawler where it stands, Get_IsHeldByAttack) -> MoveTo -> on Arrived
// dwell RoamDwellSeconds -> repeat. A failed move picks again at once,
// except after 3 consecutive failures, when it dwells first (no tight NoPath loop); a move stopped from outside dwells
// too. Always Running; the exit stops the navigator (a leaf change or death tears the state down mid-move).
class UMars_SmTask_Crawler_Roam : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private const int32 k_MaxConsecutiveFailures = 3;

    private FCk_Handle_Crawler _Crawler;
    private EMars_Crawler_RoamPhase _Phase = EMars_Crawler_RoamPhase::Pick;
    private float32 _DwellRemaining = 0.0f;
    private int32 _ConsecutiveFailures = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Crawler = ck::Ctx(InHandle).As_Crawler();

        _Phase = EMars_Crawler_RoamPhase::Pick;
        _DwellRemaining = 0.0f;
        _ConsecutiveFailures = 0;
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        // The enter's checked cast already ensured.
        if (ck::Is_NOT_Valid(_Crawler))
        { return ECk_SmTaskResult::Running; }

        auto Navigator = _Crawler.Get_Navigator();

        if (_Phase == EMars_Crawler_RoamPhase::Pick)
        {
            if (_Crawler.Get_IsHeldByAttack())
            { return ECk_SmTaskResult::Running; }

            const auto Lure = _Crawler.TryGet_LightLure();
            const auto Goal = Lure.IsSet() ? Lure.GetValue() : _Crawler.Pick_RoamPoint();
            Navigator.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(Goal));
            _Phase = EMars_Crawler_RoamPhase::Travel;
            return ECk_SmTaskResult::Running;
        }

        if (_Phase == EMars_Crawler_RoamPhase::Travel)
        {
            // Until the drain runs, the status still describes the previous move.
            if (Navigator.Get_HasPendingRequests())
            { return ECk_SmTaskResult::Running; }

            const auto Status = Navigator.Get_Status();
            if (Status == EMars_SurfaceNavigator_Status::Arrived)
            {
                _ConsecutiveFailures = 0;
                BeginDwell();
            }
            else if (Status == EMars_SurfaceNavigator_Status::Failed)
            {
                ++_ConsecutiveFailures;
                if (_ConsecutiveFailures >= k_MaxConsecutiveFailures)
                {
                    _ConsecutiveFailures = 0;
                    BeginDwell();
                }
                else
                { _Phase = EMars_Crawler_RoamPhase::Pick; }
            }
            else if (Status == EMars_SurfaceNavigator_Status::Idle)
            {
                // Stopped from outside, or the MoveTo was cancelled by a later Stop: rest, then pick again.
                BeginDwell();
            }

            return ECk_SmTaskResult::Running;
        }

        _DwellRemaining -= float32(InDeltaT.Get_Seconds());
        if (_DwellRemaining <= 0.0f)
        { _Phase = EMars_Crawler_RoamPhase::Pick; }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Crawler))
        { return; }

        auto Navigator = _Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());

        _Crawler = FCk_Handle_Crawler();
    }

    private void BeginDwell()
    {
        _DwellRemaining = _Crawler.Get_Spec().RoamDwellSeconds;
        _Phase = EMars_Crawler_RoamPhase::Dwell;
    }
}

enum EMars_Crawler_FlinchPhase
{
    // Stopped, waiting out FlinchSeconds.
    Holding,
    // The IsHurt clear is requested; the replan moves the leaf on and tears this state down.
    Clearing
}

// Stop, hold FlinchSeconds, then clear IsHurt through the brain. Always Running. Every damage event bumps the crawler's
// HurtCount and a bump restarts the hold: a hit that lands while the clear is in flight writes IsHurt back to true, and
// the restarted hold clears it again instead of waiting for a cleared fact that never comes.
class UMars_SmTask_Crawler_Flinch : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Crawler _Crawler;
    private EMars_Crawler_FlinchPhase _Phase = EMars_Crawler_FlinchPhase::Holding;
    private float32 _Elapsed = 0.0f;
    private int32 _SeenHurtCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Crawler = ck::Ctx(InHandle).As_Crawler();
        BeginFlinch();
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        // The enter's checked cast already ensured.
        if (ck::Is_NOT_Valid(_Crawler))
        { return ECk_SmTaskResult::Running; }

        if (_Crawler.Get_HurtCount() != _SeenHurtCount)
        {
            BeginFlinch();
            return ECk_SmTaskResult::Running;
        }

        if (_Phase == EMars_Crawler_FlinchPhase::Clearing)
        { return ECk_SmTaskResult::Running; }

        _Elapsed += float32(InDeltaT.Get_Seconds());
        if (_Elapsed < _Crawler.Get_Spec().FlinchSeconds)
        { return ECk_SmTaskResult::Running; }

        _Phase = EMars_Crawler_FlinchPhase::Clearing;
        auto Brain = _Crawler.Get_Brain();
        Brain.Request_SetFact(FMars_Request_Brain_SetFact(utils_crawler::Get_IsHurtFact(), false));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Crawler = FCk_Handle_Crawler();
    }

    private void BeginFlinch()
    {
        _Elapsed = 0.0f;
        _Phase = EMars_Crawler_FlinchPhase::Holding;

        if (ck::Is_NOT_Valid(_Crawler))
        { return; }

        _SeenHurtCount = _Crawler.Get_HurtCount();

        auto Navigator = _Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
    }
}

class UMars_SmTask_Crawler_Cower : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Crawler = ck::Ctx(InHandle).As_Crawler();
        if (ck::Is_NOT_Valid(Crawler))
        { return; }

        auto Navigator = Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
    }
}
