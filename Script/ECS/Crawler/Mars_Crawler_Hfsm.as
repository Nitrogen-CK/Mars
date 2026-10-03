// Root (on the crawler root, initial = Alive; context = the crawler root, which overrides its context to itself first)
// |- Alive            ->Dead [IsDead: ByteAttribute.Mars.Monster.Dead == 1]
// |    tasks: BehaviorSubSm
// |    `- Behavior sub-SM (initial = Idle)
// |         Idle    ->Roam [LeafRoam]  ->Flinch [LeafFlinch]  ->Cower [LeafCower]          (no tasks: the hub)
// |         Roam    ->Idle [LeafNotRoam]     tasks: Roam (Tick): pick a goal in RoamBounds -> MoveTo -> arrive/fail -> dwell
// |         Flinch  ->Idle [LeafNotFlinch]   tasks: Flinch (Tick): Stop; after FlinchSeconds -> SetFact(IsHurt, false)
// |         Cower   ->Idle [LeafNotCower]    tasks: Cower (EnterExitOnly): Stop
// `- Dead             (sink)  tasks: Die (EnterExitOnly): stop, brain off, shed legs, body zone off, corpse timer -> despawn
//
// The brain's leaf (the GOAP plan's first action, Mars_Crawler_Goap.as) is the only thing that moves the behaviour
// sub-SM: every leaf state exits to the Idle hub when the leaf stops matching, and Idle dispatches to the new leaf, so a
// new behaviour is one action + one state + one Idle transition. Nothing calls Request_Transition on this machine.
// Leaving Alive tears down the behaviour subtree (the Roam task's exit stops the navigator).

//--------------------------------------------------------------------------------------------------------------------------
// Conditions
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmCondition_Crawler_IsDead : UMars_SmCondition_ByteAttribute
{
    default AttributeTag = GameplayTags::ResolveGameplayTag(n"ByteAttribute.Mars.Monster.Dead");
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
    default RequirePresent = false;
}

class UMars_SmCondition_Crawler_LeafFlinch : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Flinch;
}

class UMars_SmCondition_Crawler_LeafNotFlinch : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Flinch;
    default RequirePresent = false;
}

class UMars_SmCondition_Crawler_LeafCower : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Cower;
}

class UMars_SmCondition_Crawler_LeafNotCower : UMars_SmCondition_BrainLeaf
{
    default LeafClass = UMars_GoapAction_Crawler_Cower;
    default RequirePresent = false;
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

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace(f"Crawler SM [{ck::Ctx(InHandle).ToString()}]: Alive", n"CrawlerSM", 2.0f, FLinearColor(0.3f, 1.0f, 0.3f, 1.0f));
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

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace(f"Crawler SM [{ck::Ctx(InHandle).ToString()}]: Dead", n"CrawlerSM", 2.0f, FLinearColor(1.0f, 0.3f, 0.3f, 1.0f));
    }
}

// The teardown, all of it requests: stop the navigator, disable the brain, sever every still-attached part with the
// death's cause (their debris is world-owned and dies on its own timer), disable the body zone, then start the corpse
// timer whose expiry destroys the crawler root and everything it owns. The presentation keeps the body pose's collapse
// (no legs left): that is the corpse pose. This task is the only place the corpse timer exists (D-M3).
class UMars_SmTask_Crawler_Die : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Root = ck::Ctx(InHandle);
        auto Crawler = Root.As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Crawler), f"[Crawler] Die task: context [{Root.ToString()}] is not a crawler"))
        { return; }

        auto Monster = Crawler.Get_Monster();
        auto Brain = Root.As_Brain(ECk_SanityCheck::UnChecked);

        auto Navigator = Crawler.Get_Navigator();
        if (ck::IsValid(Navigator))
        { Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop()); }

        if (ck::IsValid(Brain))
        { Brain.Request_SetEnabled(FMars_Request_Brain_SetEnabled(false)); }

        const auto MaybeCause = Monster.Get_DeathCause();
        const auto Cause = MaybeCause.IsSet() ? MaybeCause.GetValue() : FMars_DamageEvent();

        auto Shed = 0;
        auto Parts = Monster.Get_Parts();
        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            auto Part = Parts[Index];
            if (ck::Is_NOT_Valid(Part) || Part.Get_State() != EMars_BodyPart_State::Attached)
            { continue; }

            Part.Request_Sever(FMars_Request_BodyPart_Sever(Cause));
            ++Shed;
        }

        auto BodyZone = Monster.Get_BodyZone();
        if (ck::IsValid(BodyZone))
        { BodyZone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(false)); }

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(Monster.Get_CorpseSeconds()));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);
        auto Timer = utils_timer::Add(Root, TimerSpec);
        if (ck::IsValid(Timer))
        { utils_timer::BindTo_OnDone(Timer, FCk_Delegate_Timer(this, n"OnCorpseExpired")); }

        ck::Trace(f"[Crawler] [{Root.ToString()}] died: shedding [{Shed}] parts, corpse for [{Monster.Get_CorpseSeconds()}]s");
    }

    // The timer's owner is the crawler root; destroying it takes everything body-owned along.
    UFUNCTION()
    private void OnCorpseExpired(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Root = utils_entity_lifetime::Get_LifetimeOwner(FCk_Handle(InTimer));
        if (ck::IsValid(Root))
        { utils_entity_lifetime::Request_DestroyEntity(Root); }
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
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace(f"Crawler SM [{ck::Ctx(InHandle).ToString()}]: Idle", n"CrawlerSM");
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

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace(f"Crawler SM [{ck::Ctx(InHandle).ToString()}]: Roam", n"CrawlerSM");
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

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace(f"Crawler SM [{ck::Ctx(InHandle).ToString()}]: Flinch", n"CrawlerSM");
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

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace(f"Crawler SM [{ck::Ctx(InHandle).ToString()}]: Cower", n"CrawlerSM");
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Behaviour tasks
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Crawler_RoamPhase
{
    Pick,
    // A MoveTo is out; waiting for its drain, then for Arrived or Failed.
    Travel,
    Dwell
}

// Pick a goal in RoamBounds -> MoveTo -> on Arrived dwell RoamDwellSeconds -> repeat. A failed move picks again at once,
// except after 3 consecutive failures, when it dwells first (no tight NoPath loop). Always Running; the exit stops the
// navigator (a leaf change or death tears the state down mid-move).
class UMars_SmTask_Crawler_Roam : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private const int32 k_MaxConsecutiveFailures = 3;

    private FCk_Handle_Crawler _Crawler;
    private EMars_Crawler_RoamPhase _Phase = EMars_Crawler_RoamPhase::Pick;
    private FVector _Goal;
    private bool _MoveDrained = false;
    private float32 _DwellRemaining = 0.0f;
    private int32 _ConsecutiveFailures = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Crawler = ck::Ctx(InHandle).As_Crawler(ECk_SanityCheck::UnChecked);
        ck::EnsureIfNot(ck::IsValid(_Crawler), f"[Crawler] Roam task: context [{ck::Ctx(InHandle).ToString()}] is not a crawler");

        _Phase = EMars_Crawler_RoamPhase::Pick;
        _MoveDrained = false;
        _DwellRemaining = 0.0f;
        _ConsecutiveFailures = 0;
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Crawler))
        { return ECk_SmTaskResult::Running; }

        auto Navigator = _Crawler.Get_Navigator();
        if (ck::Is_NOT_Valid(Navigator))
        { return ECk_SmTaskResult::Running; }

        if (_Phase == EMars_Crawler_RoamPhase::Pick)
        {
            _Goal = _Crawler.Pick_RoamPoint();
            _MoveDrained = false;
            Navigator.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(_Goal));
            _Phase = EMars_Crawler_RoamPhase::Travel;
            return ECk_SmTaskResult::Running;
        }

        if (_Phase == EMars_Crawler_RoamPhase::Travel)
        {
            const auto Status = Navigator.Get_Status();

            // A status read before the MoveTo drains belongs to the previous move; the drain records the new goal and
            // leaves the navigator Moving (or Failed on NoPath).
            if (_MoveDrained == false)
            {
                _MoveDrained = Navigator.Get_Goal().Equals(_Goal) && Status != EMars_SurfaceNavigator_Status::Idle;
                if (_MoveDrained == false)
                { return ECk_SmTaskResult::Running; }
            }

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
        if (ck::IsValid(Navigator))
        { Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop()); }

        _Crawler = FCk_Handle_Crawler();
    }

    private void BeginDwell()
    {
        _DwellRemaining = _Crawler.Get_Spec().RoamDwellSeconds;
        _Phase = EMars_Crawler_RoamPhase::Dwell;
    }
}

// Stop, hold FlinchSeconds, then clear IsHurt through the brain (the replan moves the leaf on and tears this state down).
// Always Running: a hit landing after the clear but before the replan sets IsHurt again with the plan, and so the leaf,
// unchanged; the task sees the fact back at true and flinches again instead of resting forever on a spent timer.
class UMars_SmTask_Crawler_Flinch : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Crawler _Crawler;
    private float32 _Elapsed = 0.0f;
    private bool _ClearRequested = false;
    private bool _SawCleared = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Crawler = ck::Ctx(InHandle).As_Crawler(ECk_SanityCheck::UnChecked);
        ck::EnsureIfNot(ck::IsValid(_Crawler), f"[Crawler] Flinch task: context [{ck::Ctx(InHandle).ToString()}] is not a crawler");

        BeginFlinch();
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Crawler))
        { return ECk_SmTaskResult::Running; }

        auto Brain = _Crawler.Get_Brain();
        if (ck::Is_NOT_Valid(Brain))
        { return ECk_SmTaskResult::Running; }

        const auto IsHurtFact = utils_crawler::Get_IsHurtFact();

        if (_ClearRequested == false)
        {
            _Elapsed += float32(InDeltaT.Get_Seconds());
            if (_Elapsed >= _Crawler.Get_Spec().FlinchSeconds)
            {
                _ClearRequested = true;
                Brain.Request_SetFact(FMars_Request_Brain_SetFact(IsHurtFact, false));
            }
            return ECk_SmTaskResult::Running;
        }

        // The clear is deferred twice (the brain's drain, then CkGoap's write): see it land before watching for a re-hurt.
        const auto IsHurt = Brain.Get_Fact(IsHurtFact);
        if (_SawCleared == false)
        {
            _SawCleared = IsHurt == false;
            return ECk_SmTaskResult::Running;
        }

        if (IsHurt)
        { BeginFlinch(); }

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
        _ClearRequested = false;
        _SawCleared = false;

        if (ck::Is_NOT_Valid(_Crawler))
        { return; }

        auto Navigator = _Crawler.Get_Navigator();
        if (ck::IsValid(Navigator))
        { Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop()); }
    }
}

class UMars_SmTask_Crawler_Cower : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Crawler = ck::Ctx(InHandle).As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Crawler), f"[Crawler] Cower task: context [{ck::Ctx(InHandle).ToString()}] is not a crawler"))
        { return; }

        auto Navigator = Crawler.Get_Navigator();
        if (ck::IsValid(Navigator))
        { Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop()); }
    }
}
