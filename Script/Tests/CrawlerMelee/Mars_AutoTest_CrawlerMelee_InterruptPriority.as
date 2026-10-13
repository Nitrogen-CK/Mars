// Flinch, Cower and Dead keep their contracts over Engage, and an attack is cancelled by the kernel's own guards before the
// planner's replan can move the behaviour. An aggressive armed 4-leg crawler (MinLegsToWalk 3) engages a tagged hostile:
//   1. hurt while Approach moves it: the behaviour flinches, Engage is left (its stage reads None) and the navigator stops;
//   2. once the flinch clears Engage resumes; hurt while its attack is in Windup: the attack enters CancelRecover as Hurt
//      within two frames of the hit, by the kernel's own guard while the behaviour is still in Engage's Attack stage
//      (the cancel Engage's exit sends, StateExit, would have won had it arrived first), and no damage is requested;
//   3. Engage resumes again; two legs severed while it is in Prepare: the behaviour cowers, Engage is left, no damage;
//   4. a second crawler on its own floor, killed while its attack is in Windup: it dies (the Dead state sinks), Engage is
//      left, the attack is cancelled as Dead and its target, inside the strike's reach, is never damaged.
class UMars_AutoTest_CrawlerMelee_InterruptPriority : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 120.0f;
    default _Origin = FVector(-190000.0, -180000.0, 600.0);

    private const FVector k_HalfExtents = FVector(35.0, 25.0, 25.0);
    private const FVector k_SecondCrawlerOffset = FVector(0.0, 5000.0, 0.0);

    private int64 _HurtFrame = -1;
    private int32 _DamageBefore = 0;
    private float32 _TargetHealthBefore = 100.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_SettleSteps();
        Add_Step("watch Engage; spawn a tagged hostile 500 cm ahead", n"Step_SpawnFarTarget");
        Add_Step_WaitUntil("(1) Approach is moving the crawler", n"Check_ApproachMoving", k_SlowPolls, 0);
        Add_Step("(1) hurt the crawler", n"Step_HurtBody");
        Add_Step_WaitUntil("(1) the behaviour flinches", n"Check_InFlinch", k_SlowPolls, 0);
        Add_Step_WaitUntil("(1) the navigator has stopped", n"Check_CrawlerNavigatorStopped", k_SlowPolls, 0);
        Add_Step("(1) Engage was left", n"Step_AssertFlinchLeftEngage");

        Add_Step_WaitUntil("(2) Engage resumes and its attack reaches Windup", n"Check_InWindup", 3000, 0);
        Add_Step("(2) hurt the crawler during Windup", n"Step_HurtInWindup");
        Add_Step_WaitUntil("(2) the attack enters CancelRecover", n"Check_CancelRecoverSinceMark", k_SlowPolls, 0);
        Add_Step("(2) the kernel cancelled as Hurt before the behaviour left Engage", n"Step_AssertHurtCancel");

        Add_Step_WaitUntil("(3) Engage resumes and reaches Prepare", n"Check_InEngagePrepare", 3000, 0);
        Add_Step("(3) sever two legs", n"Step_Cripple");
        Add_Step_WaitUntil("(3) the behaviour cowers", n"Check_InCower", k_SlowPolls, 0);
        Add_Step_WaitSeconds("(3) settle 1 s", 1.0f);
        Add_Step("(3) Cower won and nothing was damaged", n"Step_AssertCower");

        Add_Step("(4) spawn a second crawler on its own floor", n"Step_SpawnSecondCrawler");
        Add_SettleSteps();
        Add_Step("(4) watch Engage; spawn a tagged hostile inside the strike's reach", n"Step_SpawnNearTarget");
        Add_Step_WaitUntil("(4) Engage's attack reaches Windup", n"Check_InWindup", 3000, 0);
        Add_Step("(4) kill the crawler", n"Step_Kill");
        Add_Step_WaitUntil("(4) the crawler is dead", n"Check_Dead", k_SlowPolls, 0);
        Add_Step_WaitSeconds("(4) settle 1 s", 1.0f);
        Add_Step("(4) Dead sank Engage and the attack, and nothing was damaged", n"Step_AssertDead");
        Run_Steps(InHandle);
    }

    // The settle's roam may carry the crawler up to ~200 cm from home along its heading: keep the far target inside the leash.
    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = Make_AggressiveCrawlerSpec(4);
        Spec.Combat.Targeting.LoseRadius = 1000.0f;
        Spec.Combat.Targeting.HomeRadius = 1000.0f;
        return Spec;
    }

    private void Damage_Body(float32 InAmount)
    {
        auto Health = _Crawler.Get_Monster().Get_BodyHealth();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Step_SpawnFarTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Watch_Engage();
        _RecordMark = _Records.Num();
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointFromRoot(500.0, 0.0)), k_HalfExtents);
    }

    UFUNCTION()
    private void Check_ApproachMoving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_EngageStage() == EMars_Crawler_EngageStage::Approach &&
            _Crawler.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Moving &&
            utils_surface_motion::Get_Velocity(_Crawler.Get_Motion()).Size() > 20.0);
    }

    UFUNCTION()
    private void Step_HurtBody(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DamageBefore = Get_DamageRequestCount();
        Damage_Body(5.0f);
    }

    UFUNCTION()
    private void Check_InFlinch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Flinch);
    }

    UFUNCTION()
    private void Step_AssertFlinchLeftEngage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_EngageStage() == EMars_Crawler_EngageStage::None, f"(1) Engage was left (stage {_Crawler.Get_EngageStage() :n})");
        Assert_True(_Crawler.Get_Brain().Get_LeafClass() == UMars_GoapAction_Crawler_Flinch, "(1) the leaf is Flinch");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle, f"(1) no attack is running ({_Crawler.Get_AttackPhase() :n})");
        Assert_Equals_Int(Get_DamageRequestCount(), _DamageBefore, "(1) no damage was requested");
    }

    UFUNCTION()
    private void Step_HurtInWindup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RecordMark = _Records.Num() - 1;
        _HurtFrame = utils_time::Get_FrameCounter();
        _DamageBefore = Get_DamageRequestCount();
        _TargetHealthBefore = _Target.Health.Get_Current();
        Assert_True(_Crawler.Get_Brain().Get_LeafClass() == UMars_GoapAction_Crawler_Engage, "(2) the leaf is Engage when the hit lands");
        Damage_Body(5.0f);
    }

    UFUNCTION()
    private void Check_CancelRecoverSinceMark(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover) >= 0);
    }

    UFUNCTION()
    private void Step_AssertHurtCancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Cancel = _Records[Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover)];
        Assert_True(Cancel.Old == EMars_Crawler_AttackPhase::Windup, f"(2) CancelRecover came from Windup (from {Cancel.Old :n})");
        Assert_True(Cancel.LastCancel.IsSet() && Cancel.LastCancel.GetValue() == EMars_Crawler_AttackCancel::Hurt,
            f"(2) the attack was cancelled as Hurt (last cancel {Get_LastCancelText()})");
        Assert_True(Cancel.Frame - _HurtFrame <= 2, f"(2) the cancel landed within two frames of the hit (hit {_HurtFrame}, cancel {Cancel.Frame})");
        Assert_True(Cancel.EngageStage == EMars_Crawler_EngageStage::Attack,
            f"(2) the behaviour was still in Engage's Attack stage when the kernel cancelled (stage {Cancel.EngageStage :n}, brain leaf {utils_brain::Get_ClassName(Cancel.Leaf)})");
        Assert_Equals_Int(Cancel.DamageRequests, _DamageBefore, "(2) no damage was requested");
        Assert_Equals_Float(_Target.Health.Get_Current(), _TargetHealthBefore, 0.01f, "(2) the target is untouched");
    }

    UFUNCTION()
    private void Step_Cripple(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RecordMark = _Records.Num();
        _DamageBefore = Get_DamageRequestCount();
        _TargetHealthBefore = _Target.Health.Get_Current();

        const auto Sever = GameplayTags::DamageType_Mars_Sever;
        for (int32 Index = 0; Index < 2; ++Index)
        {
            auto Health = _Crawler.Get_LegParts()[Index].Get_Health();
            Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(30.0f, Sever)));
        }
    }

    UFUNCTION()
    private void Check_InCower(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Cower);
    }

    UFUNCTION()
    private void Step_AssertCower(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Cower, "(3) the behaviour still cowers");
        Assert_True(_Crawler.Get_Brain().Get_LeafClass() == UMars_GoapAction_Crawler_Cower, "(3) the leaf is Cower");
        Assert_True(_Crawler.Get_EngageStage() == EMars_Crawler_EngageStage::None, f"(3) Engage was left (stage {_Crawler.Get_EngageStage() :n})");
        Assert_Equals_Int(Get_DamageRequestCount(), _DamageBefore, f"(3) no damage was requested (phases{Get_PhaseText(_RecordMark)})");
        Assert_Equals_Float(_Target.Health.Get_Current(), _TargetHealthBefore, 0.01f, "(3) the target is untouched");
        Assert_False(utils_crawler::Get_IsOffensivePhase(_Crawler.Get_AttackPhase()), f"(3) no attack is in flight ({_Crawler.Get_AttackPhase() :n})");
    }

    UFUNCTION()
    private void Step_SpawnSecondCrawler(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Origin = _Origin + k_SecondCrawlerOffset;
        _Crawler = FCk_Handle_Crawler();
        SpawnFloorAndCrawler(InHandle, Make_Spec());
    }

    UFUNCTION()
    private void Step_SpawnNearTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Watch_Engage();
        _RecordMark = _Records.Num();
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointFromRoot(90.0, 0.0)), k_HalfExtents);
    }

    UFUNCTION()
    private void Step_Kill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RecordMark = _Records.Num() - 1;
        _DamageBefore = Get_DamageRequestCount();
        Damage_Body(1000.0f);
    }

    UFUNCTION()
    private void Check_Dead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_Monster().Get_IsDead());
    }

    UFUNCTION()
    private void Step_AssertDead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto StateMachine = _Crawler.As_StateMachine(ECk_SanityCheck::UnChecked);
        Assert_True(ck::IsValid(StateMachine) && utils_state_machine::Get_CurrentStateClass(StateMachine) == UMars_SmState_Crawler_Dead,
            "(4) the root state is Dead");
        Assert_True(_Crawler.Get_EngageStage() == EMars_Crawler_EngageStage::None, f"(4) Engage was left (stage {_Crawler.Get_EngageStage() :n})");
        // Engage's exit cancel arrives during Cooldown and is recorded over Dead, so read the cancel the Cooldown entry saw.
        const auto CooldownIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown);
        Assert_True(CooldownIndex >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover) < 0,
            f"(4) the attack went straight to Cooldown (phases{Get_PhaseText(_RecordMark)})");
        if (CooldownIndex >= 0)
        {
            const auto LastCancel = _Records[CooldownIndex].LastCancel;
            Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::Dead,
                f"(4) the attack was cancelled as Dead (phases{Get_PhaseText(_RecordMark)})");
        }
        Assert_False(utils_crawler::Get_IsOffensivePhase(_Crawler.Get_AttackPhase()), f"(4) no attack is in flight ({_Crawler.Get_AttackPhase() :n})");
        Assert_Equals_Int(Get_DamageRequestCount(), _DamageBefore, "(4) no damage was requested");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "(4) the target inside the strike's reach is untouched");
    }
}
