// Root (on the crawler root, initial = Alive; context = the crawler root, which overrides its context to itself first)
// |- Alive            ->Dead [IsDead: ByteAttribute.Mars.Monster.Dead == 1]
// |    tasks: BehaviorSubSm
// |    `- Behavior sub-SM (initial = Idle)
// |         Idle    ->Roam [LeafRoam]  ->Flinch [LeafFlinch]  ->Cower [LeafCower]          (no tasks: the hub)
// |         Roam    ->Idle [LeafNotRoam]     tasks: Roam (Tick): pick a goal in RoamBounds -> MoveTo -> arrive/fail -> dwell
// |         Flinch  ->Idle [LeafNotFlinch]   tasks: Flinch (Tick): Stop; after FlinchSeconds -> SetFact(IsHurt, false); a hit restarts it
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

        auto Shed = 0;
        // An index loop: a range-for over the returned array yields read-only elements.
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
        BodyZone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));

        utils_monster::Add_DespawnTimer(Crawler, Monster.Get_CorpseSeconds(), FCk_Delegate_Timer(this, n"OnCorpseExpired"));

        ck::Trace(f"[Crawler] [{Crawler.ToString()}] died: shedding [{Shed}] parts, corpse for [{Monster.Get_CorpseSeconds()}]s");
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
    // A MoveTo is out: waiting for Arrived or Failed.
    Travel,
    Dwell
}

// Pick a goal in RoamBounds -> MoveTo -> on Arrived dwell RoamDwellSeconds -> repeat. A failed move picks again at once,
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
            Navigator.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(_Crawler.Pick_RoamPoint()));
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
