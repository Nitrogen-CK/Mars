// Every way out of an attack ends at neutral with the attack finished, or with the crawler gone. The target stands out
// of reach (near face 55 cm ahead of the neutral hit centre), so no hit is in play. In turn:
//   1-3. Request_CancelAttack(StateExit) in Windup, in Strike (on its first sample) and in Recover: CancelRecover,
//        Cooldown, Idle;
//   4.   Request_CancelAttack(Disabled) in Windup: straight to Cooldown, no CancelRecover;
//   5.   the Windup samples are never published (another writer's sample always lands after the attack's): after
//        PoseTimeoutSeconds the attack cancels as PoseTimeout into CancelRecover, which completes;
//   6.   a StateExit cancel in Windup, then CancelRecover's samples are never published: its own timeout ends the wait in
//        Cooldown instead of starting another recovery;
//   7.   a leg hit as Strike begins cancels as Hurt; as CancelRecover begins the target is destroyed and a second cancel
//        arrives: CancelRecover still completes on acknowledged samples, exactly once, in the same generation, with the
//        second cancel recorded and nothing restarted;
//   8.   the crawler, settled again after its flinch, is destroyed mid-Strike: no ensure, no script error.
// After 1-7 the body pose's action input is identity.
class UMars_AutoTest_CrawlerMelee_EveryExit : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 120.0f;
    default _Origin = FVector(-240000.0, -150000.0, 600.0);

    private const FVector k_HalfExtents = FVector(10.0, 20.0, 20.0);
    private const float64 k_FaceAhead = 55.0;

    private FCk_Handle _TriggerEntity;
    private FCk_Handle _SecondTriggerEntity;
    private FCk_Handle _CrawlerEntity;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target out of reach", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);

        Add_Start("(1)");
        Add_Step("(1) cancel (StateExit) during Windup", n"Step_CancelStateExit");
        Add_Finish("(1)");
        Add_Step("(1) Windup > CancelRecover > Cooldown > Idle", n"Step_AssertCancelInWindup");

        Add_Step("(2) arm a StateExit cancel on the first Strike sample", n"Step_ArmCancelInStrike");
        Add_Start("(2)");
        Add_Finish("(2)");
        Add_Step("(2) Windup > Strike > CancelRecover > Cooldown > Idle", n"Step_AssertCancelInStrike");

        Add_Start("(3)");
        Add_Step_WaitUntil("(3) the attack is in Recover", n"Check_InRecover", k_SlowPolls, 0);
        Add_Step("(3) cancel (StateExit) during Recover", n"Step_CancelStateExit");
        Add_Finish("(3)");
        Add_Step("(3) Windup > Strike > Recover > CancelRecover > Cooldown > Idle", n"Step_AssertCancelInRecover");

        Add_Start("(4)");
        Add_Step("(4) cancel (Disabled) during Windup", n"Step_CancelDisabled");
        Add_Finish("(4)");
        Add_Step("(4) Windup > Cooldown > Idle", n"Step_AssertDisabled");

        Add_Step("(5) arm a pose writer that overwrites every Windup sample", n"Step_ArmStealWindup");
        Add_Start("(5)");
        Add_Finish("(5)");
        Add_Step("(5) PoseTimeout > CancelRecover > Cooldown > Idle", n"Step_AssertWindupTimeout");

        Add_Step("(6) arm a pose writer that overwrites every CancelRecover sample", n"Step_ArmStealCancelRecover");
        Add_Start("(6)");
        Add_Step("(6) cancel (StateExit) during Windup", n"Step_CancelStateExit");
        Add_Finish("(6)");
        Add_Step("(6) CancelRecover's own timeout ends it in Cooldown", n"Step_AssertRecoveryTimeout");

        Add_Step("(7) arm a leg hit as Strike begins, and the target's destruction plus a second cancel as CancelRecover begins", n"Step_ArmHurtAndLoseTarget");
        Add_Start("(7)");
        Add_Finish("(7)");
        Add_Step("(7) CancelRecover completed once on acknowledged samples", n"Step_AssertHurtRecovery");

        Add_Step_WaitSeconds("(8) let the flinch begin", 0.5f);
        Add_Step_WaitUntil("(8) the flinch has cleared IsHurt", n"Check_HurtCleared", k_SlowPolls, 0);
        Add_SettleSteps();
        Add_Step("(8) spawn a target out of reach; arm the crawler's destruction on the first Strike sample", n"Step_ArmDestroyCrawler");
        Add_Step_WaitUntil("(8) the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Start("(8)");
        Add_Step_WaitUntil("(8) the crawler is being destroyed", n"Check_CrawlerGone", k_SlowPolls, 0);
        Add_Step_WaitSeconds("(8) let the teardown run 1 s", 1.0f);
        Add_Step("(8) the crawler went away mid-attack", n"Step_AssertDestroyed");
        Run_Steps(InHandle);
    }

    private void Add_Start(FString InLabel)
    {
        Add_Step(f"{InLabel} select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil(f"{InLabel} the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
    }

    private void Add_Finish(FString InLabel)
    {
        Add_Step_WaitUntil(f"{InLabel} the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
    }

    private void Assert_Exit(FString InLabel, const TArray<EMars_Crawler_AttackPhase>& InExpected, EMars_Crawler_AttackCancel InCancel)
    {
        const auto Phases = Get_PhasesSinceMark();
        auto Matches = Phases.Num() == InExpected.Num();
        for (int32 Index = 0; Matches && Index < Phases.Num(); ++Index)
        { Matches = Phases[Index] == InExpected[Index]; }

        Assert_True(Matches, f"{InLabel} the phases ran as expected (got{Get_PhaseText(_RecordMark)})");

        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == InCancel, f"{InLabel} the last cancel is {InCancel :n} (got {Get_LastCancelText()})");
        Assert_True(utils_procedural_body_pose::Get_ActionOffset(_Crawler.Get_BodyPose()).Equals(FTransform::Identity, 0.001),
            f"{InLabel} the action input is identity again");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, f"{InLabel} no damage request exists");
    }

    private TArray<EMars_Crawler_AttackPhase> Make_Phases(EMars_Crawler_AttackPhase InFirst, EMars_Crawler_AttackPhase InSecond, EMars_Crawler_AttackPhase InThird) const
    {
        auto Phases = TArray<EMars_Crawler_AttackPhase>();
        Phases.Add(EMars_Crawler_AttackPhase::Windup);
        Phases.Add(InFirst);
        Phases.Add(InSecond);
        Phases.Add(InThird);
        return Phases;
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, k_FaceAhead, k_HalfExtents);
    }

    UFUNCTION()
    private void Step_CancelStateExit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));
    }

    UFUNCTION()
    private void Step_CancelDisabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::Disabled));
    }

    UFUNCTION()
    private void Step_AssertCancelInWindup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Exit("(1)", Make_Phases(EMars_Crawler_AttackPhase::CancelRecover, EMars_Crawler_AttackPhase::Cooldown, EMars_Crawler_AttackPhase::Idle),
            EMars_Crawler_AttackCancel::StateExit);
    }

    UFUNCTION()
    private void Step_ArmCancelInStrike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::StrikeSampleSubmitted, EMars_TESTONLY_CrawlerMelee_Action::CancelAttack);
        Trigger.CancelReason = EMars_Crawler_AttackCancel::StateExit;
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Step_AssertCancelInStrike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expected = Make_Phases(EMars_Crawler_AttackPhase::Strike, EMars_Crawler_AttackPhase::CancelRecover, EMars_Crawler_AttackPhase::Cooldown);
        Expected.Add(EMars_Crawler_AttackPhase::Idle);
        Assert_Exit("(2)", Expected, EMars_Crawler_AttackCancel::StateExit);
        utils_entity_lifetime::Request_DestroyEntity(_TriggerEntity);
    }

    UFUNCTION()
    private void Step_AssertCancelInRecover(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expected = Make_Phases(EMars_Crawler_AttackPhase::Strike, EMars_Crawler_AttackPhase::Recover, EMars_Crawler_AttackPhase::CancelRecover);
        Expected.Add(EMars_Crawler_AttackPhase::Cooldown);
        Expected.Add(EMars_Crawler_AttackPhase::Idle);
        Assert_Exit("(3)", Expected, EMars_Crawler_AttackCancel::StateExit);
    }

    UFUNCTION()
    private void Step_AssertDisabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expected = TArray<EMars_Crawler_AttackPhase>();
        Expected.Add(EMars_Crawler_AttackPhase::Windup);
        Expected.Add(EMars_Crawler_AttackPhase::Cooldown);
        Expected.Add(EMars_Crawler_AttackPhase::Idle);
        Assert_Exit("(4)", Expected, EMars_Crawler_AttackCancel::Disabled);
    }

    UFUNCTION()
    private void Step_ArmStealWindup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::WhilePhase, EMars_TESTONLY_CrawlerMelee_Action::StealPose);
        Trigger.StealPhase = EMars_Crawler_AttackPhase::Windup;
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Step_AssertWindupTimeout(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Trigger = _TriggerEntity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger);
        Assert_True(Trigger.StolenSamples > 0, "(5) the other writer overwrote the Windup samples");
        Assert_Exit("(5)", Make_Phases(EMars_Crawler_AttackPhase::CancelRecover, EMars_Crawler_AttackPhase::Cooldown, EMars_Crawler_AttackPhase::Idle),
            EMars_Crawler_AttackCancel::PoseTimeout);
        utils_entity_lifetime::Request_DestroyEntity(_TriggerEntity);
    }

    UFUNCTION()
    private void Step_ArmStealCancelRecover(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::WhilePhase, EMars_TESTONLY_CrawlerMelee_Action::StealPose);
        Trigger.StealPhase = EMars_Crawler_AttackPhase::CancelRecover;
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Step_AssertRecoveryTimeout(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Trigger = _TriggerEntity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger);
        Assert_True(Trigger.StolenSamples > 0, "(6) the other writer overwrote the CancelRecover samples");
        Assert_Exit("(6)", Make_Phases(EMars_Crawler_AttackPhase::CancelRecover, EMars_Crawler_AttackPhase::Cooldown, EMars_Crawler_AttackPhase::Idle),
            EMars_Crawler_AttackCancel::PoseTimeout);
        utils_entity_lifetime::Request_DestroyEntity(_TriggerEntity);
    }

    UFUNCTION()
    private void Step_ArmHurtAndLoseTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Hurt = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::StrikeEntered, EMars_TESTONLY_CrawlerMelee_Action::HitZone);
        Hurt.HitZone = _Crawler.Get_LegParts()[0].Get_Zone();
        Hurt.Amount = 5.0f;
        _TriggerEntity = Add_Trigger(InHandle, Hurt);

        auto LoseTarget = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::CancelRecoverEntered, EMars_TESTONLY_CrawlerMelee_Action::DestroyEntity);
        LoseTarget.Entity = _Target.Entity;
        _SecondTriggerEntity = Add_Trigger(InHandle, LoseTarget);

        auto SecondCancel = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::CancelRecoverEntered, EMars_TESTONLY_CrawlerMelee_Action::CancelAttack);
        SecondCancel.CancelReason = EMars_Crawler_AttackCancel::StateExit;
        Add_Trigger(InHandle, SecondCancel);
    }

    UFUNCTION()
    private void Step_AssertHurtRecovery(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expected = Make_Phases(EMars_Crawler_AttackPhase::Strike, EMars_Crawler_AttackPhase::CancelRecover, EMars_Crawler_AttackPhase::Cooldown);
        Expected.Add(EMars_Crawler_AttackPhase::Idle);
        Assert_Exit("(7)", Expected, EMars_Crawler_AttackCancel::StateExit);

        Assert_True(_SecondTriggerEntity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger).Fired, "(7) the target was destroyed as CancelRecover began");

        const auto RecoverIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover);
        const auto CooldownIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown);
        if (RecoverIndex < 0 || CooldownIndex < 0)
        { return; }

        Assert_True(_Records[RecoverIndex].LastCancel.IsSet() && _Records[RecoverIndex].LastCancel.GetValue() == EMars_Crawler_AttackCancel::Hurt,
            "(7) the attack was cancelled as Hurt");
        Assert_Equals_Int(_Records[CooldownIndex].Generation, _Records[RecoverIndex].Generation,
            "(7) the second cancel did not start another recovery generation");
        Assert_True(_Records[CooldownIndex].AcknowledgedSampleId > _Records[RecoverIndex].AcknowledgedSampleId,
            f"(7) CancelRecover ended on an acknowledged sample of its own (entered at [{_Records[RecoverIndex].AcknowledgedSampleId}], ended at [{_Records[CooldownIndex].AcknowledgedSampleId}])");
    }

    UFUNCTION()
    private void Check_HurtCleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_Brain().Get_Fact(utils_crawler::Get_IsHurtFact()) == false);
    }

    UFUNCTION()
    private void Step_ArmDestroyCrawler(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, k_FaceAhead, k_HalfExtents);
        _CrawlerEntity = _Crawler;

        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::StrikeSampleSubmitted, EMars_TESTONLY_CrawlerMelee_Action::DestroyEntity);
        Trigger.Entity = _CrawlerEntity;
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Check_CrawlerGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_CrawlerEntity) ||
            utils_entity_lifetime::Get_IsPendingDestroy(_CrawlerEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    UFUNCTION()
    private void Step_AssertDestroyed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TriggerEntity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger).Fired, "(8) the crawler was destroyed on the first Strike sample");
        Assert_True(ck::Is_NOT_Valid(_CrawlerEntity), "(8) the crawler entity is gone");
    }
}
