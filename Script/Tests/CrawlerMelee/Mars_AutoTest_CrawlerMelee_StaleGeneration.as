// Nothing from an abandoned attack can commit. The first target's near face is 30 cm ahead of the neutral hit centre,
// where the strike reaches it; a second target stands 150 cm to the side. In turn:
//   1. during Windup the combat target is replaced by the second target: the attack is cancelled (TargetLost), the
//      target generation advances, and neither target is damaged;
//   2. from Idle, a cancel and a start drain together: the start is rejected (CancelPending) and no attack begins;
//   3. in the frame the strike stores its candidate a cancel is requested: the next attack tick cancels first, so that
//      candidate (of a generation the cancel retires) is discarded, never committed.
class UMars_AutoTest_CrawlerMelee_StaleGeneration : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-260000.0, -150000.0, 600.0);

    private const FVector k_HalfExtents = FVector(10.0, 20.0, 20.0);

    private FMars_AutoTest_CrawlerMelee_Target _OtherTarget;
    private FCk_Handle _TriggerEntity;
    private int32 _TargetGenerationBefore = 0;
    private int32 _GenerationBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn the target in the strike's path and a second target to the side", n"Step_SpawnTargets");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("(1) select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("(1) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("(1) replace the combat target during Windup", n"Step_ReplaceTarget");
        Add_Step_WaitUntil("(1) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("(1) the replacement cancelled the attack", n"Step_AssertReplaced");
        Add_Step("(2) from Idle, request a cancel and a start in one frame", n"Step_CancelAndStart");
        Add_Step_WaitUntil("(2) the requests drained", n"Check_CombatRequestsDrained", k_SlowPolls, 0);
        Add_Step("(2) the start was rejected as CancelPending", n"Step_AssertCancelPending");
        Add_Step("(3) arm a cancel on the stored candidate", n"Step_ArmCancelOnCandidate");
        Add_Step("(3) select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("(3) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("(3) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds("(3) settle 0.5 s", 0.5f);
        Add_Step("(3) the retired candidate was never committed", n"Step_AssertCandidateDiscarded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTargets(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, k_HalfExtents);
        _OtherTarget = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointAhead(30.0 + k_HalfExtents.X, 150.0)), k_HalfExtents);
    }

    UFUNCTION()
    private void Step_ReplaceTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _TargetGenerationBefore = _Crawler.Get_CombatTargetGeneration();
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_OtherTarget.Entity));
    }

    UFUNCTION()
    private void Step_AssertReplaced(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::TargetLost,
            f"(1) the replaced target cancelled the attack (last cancel {Get_LastCancelText()}, phases{Get_PhaseText(_RecordMark)})");
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover) >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Recover) < 0,
            f"(1) the attack eased back through CancelRecover (phases{Get_PhaseText(_RecordMark)})");
        Assert_True(_Crawler.Get_CombatTargetGeneration() > _TargetGenerationBefore, "(1) the target generation advanced");
        Assert_True(_Crawler.Get_CombatTarget() == _OtherTarget.Entity, "(1) the combat target is the second target");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "(1) no damage request was sent");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "(1) the first target is untouched");
        Assert_Equals_Float(_OtherTarget.Health.Get_Current(), 100.0f, 0.01f, "(1) the second target is untouched");
    }

    UFUNCTION()
    private void Step_CancelAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RecordMark = _Records.Num();
        _GenerationBefore = _Crawler.Get_AttackGeneration();
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Target.Entity));
        _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
    }

    UFUNCTION()
    private void Step_AssertCancelPending(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastReject = _Crawler.Get_AttackLastReject();
        Assert_True(LastReject.IsSet() && LastReject.GetValue() == EMars_Crawler_AttackReject::CancelPending,
            f"(2) the start beside a cancel is rejected as CancelPending (last reject {Get_LastRejectText()})");
        Assert_True(_Records.Num() == _RecordMark, f"(2) no attack began (phases{Get_PhaseText(_RecordMark)})");
        Assert_Equals_Int(_Crawler.Get_AttackGeneration(), _GenerationBefore, "(2) the generation did not advance");
    }

    UFUNCTION()
    private void Step_ArmCancelOnCandidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::CandidatePending, EMars_TESTONLY_CrawlerMelee_Action::CancelAttack);
        Trigger.CancelReason = EMars_Crawler_AttackCancel::StateExit;
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Step_AssertCandidateDiscarded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Trigger = _TriggerEntity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger);
        Assert_True(Trigger.SawCandidate && Trigger.Fired, "(3) a candidate was stored and the cancel requested in its frame");

        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::StateExit,
            f"(3) the attack was cancelled (last cancel {Get_LastCancelText()}, phases{Get_PhaseText(_RecordMark)})");

        const auto CancelIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover);
        Assert_True(CancelIndex >= 0 && _Records[CancelIndex].Generation > Trigger.FiredGeneration,
            "(3) the cancel retired the candidate's generation");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "(3) no damage request was sent");
        Assert_False(_Crawler.Get_AttackDamageCommitted(), "(3) nothing was committed");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "(3) the target is untouched");
    }
}
