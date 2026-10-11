// End to end: an aggressive armed crawler at rest with a tagged hostile 300 cm ahead acquires it, approaches, prepares and
// attacks (the target loses the jab's 15 HP), waits out the cooldown and attacks again (15 more), within 20 s of the target
// appearing. Each attack runs Windup > Strike > Recover > Cooldown > Idle, the second admitted only after the first
// reached Idle; the stages run Approach > Prepare > Attack > Wait, then back through Approach and Prepare to Attack.
class UMars_AutoTest_CrawlerMelee_EngagesAndRetries : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 70.0f;
    default _Origin = FVector(-210000.0, -180000.0, 600.0);

    private const FVector k_HalfExtents = FVector(35.0, 25.0, 25.0);
    private const float64 k_TargetAhead = 300.0;
    private const float64 k_BoundSeconds = 20.0;

    private float64 _SpawnedAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_AggressiveCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("watch Engage; spawn a tagged hostile 300 cm ahead", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target takes two jabs within 20 s", n"Check_TwoHits", 4000, 0);
        Add_Step_WaitUntil("the second attack is back in Idle", n"Check_SecondAttackFinished", k_SlowPolls, 0);
        Add_Step("acquire, approach, prepare, attack, wait, attack again: in order", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Watch_Engage();
        _RecordMark = _Records.Num();
        _SpawnedAt = System::GetGameTimeInSeconds();
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointFromRoot(k_TargetAhead, 0.0)), k_HalfExtents);
    }

    UFUNCTION()
    private void Check_TwoHits(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (System::GetGameTimeInSeconds() - _SpawnedAt > k_BoundSeconds)
        {
            FinishFailure(f"two jabs did not land within {k_BoundSeconds :.0} s (target at {_Target.Health.Get_Current() :.0} HP, stages{Get_StageText(0)}, phases{Get_PhaseText(_RecordMark)}, last cancel {Get_LastCancelText()}, last reject {Get_LastRejectText()}; {Get_CrawlerDiagnostics()})");
            return;
        }

        auto Res = OutResult;
        Res.Set(_Target.Health.Get_Current() <= 70.0f + 0.01f);
    }

    UFUNCTION()
    private void Check_SecondAttackFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Count_RecordsSinceMark(EMars_Crawler_AttackPhase::Idle) >= 2);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phases = Get_PhasesSinceMark();
        Assert_True(Phases.Num() >= 10, f"two full attacks were recorded (phases{Get_PhaseText(_RecordMark)})");
        if (Phases.Num() < 10)
        { return; }

        for (int32 Attack = 0; Attack < 2; ++Attack)
        {
            const auto First = Attack * 5;
            Assert_True(Phases[First] == EMars_Crawler_AttackPhase::Windup && Phases[First + 1] == EMars_Crawler_AttackPhase::Strike &&
                Phases[First + 2] == EMars_Crawler_AttackPhase::Recover && Phases[First + 3] == EMars_Crawler_AttackPhase::Cooldown &&
                Phases[First + 4] == EMars_Crawler_AttackPhase::Idle,
                f"attack {Attack + 1} ran Windup > Strike > Recover > Cooldown > Idle (phases{Get_PhaseText(_RecordMark)})");
        }

        const auto FirstIdle = _Records[_RecordMark + 4];
        const auto SecondWindup = _Records[_RecordMark + 5];
        Assert_True(SecondWindup.Frame > FirstIdle.Frame, "the second attack was admitted after the first had cooled down");
        Assert_True(FirstIdle.DamageRequests == 1 && SecondWindup.DamageRequests == 1, "the first attack sent one damage request");
        Assert_Equals_Int(Get_DamageRequestCount(), 2, "two damage requests in all");
        Assert_Equals_Float(_Target.Health.Get_Current(), 70.0f, 0.01f, "the target lost 15 HP twice");

        auto Cursor = 0;
        auto InOrder = true;
        TArray<EMars_Crawler_EngageStage> Order;
        Order.Add(EMars_Crawler_EngageStage::Approach);
        Order.Add(EMars_Crawler_EngageStage::Prepare);
        Order.Add(EMars_Crawler_EngageStage::Attack);
        Order.Add(EMars_Crawler_EngageStage::Wait);
        Order.Add(EMars_Crawler_EngageStage::Approach);
        Order.Add(EMars_Crawler_EngageStage::Prepare);
        Order.Add(EMars_Crawler_EngageStage::Attack);
        for (const auto& Stage : Order)
        {
            const auto Found = Find_StageRecord(Stage, Cursor);
            if (Found < 0)
            {
                InOrder = false;
                break;
            }
            Cursor = Found + 1;
        }
        Assert_True(InOrder, f"the stages ran Approach > Prepare > Attack > Wait > Approach > Prepare > Attack in order (got{Get_StageText(0)})");
        Assert_True(Get_StageRecords().Num() > 0 && Get_StageRecords()[0].Stage == EMars_Crawler_EngageStage::Approach,
            f"Engage began with Approach (got{Get_StageText(0)})");
    }
}
