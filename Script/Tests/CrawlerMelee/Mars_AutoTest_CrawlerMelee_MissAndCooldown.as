// A jab that reaches nothing (the target's near face 55 cm ahead of the neutral hit centre; the strike reaches 44) still
// recovers and cools down: Windup > Strike > Recover > Cooldown > Idle with no damage. A start requested during Windup,
// Recover and Cooldown drains and records exactly one Rejected history event, Busy, and is never queued: once the attack
// is back in Idle no second attack begins, the generation is still the one admission's, and only one Windup was entered.
class UMars_AutoTest_CrawlerMelee_MissAndCooldown : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-200000.0, -150000.0, 600.0);

    private int32 _GenerationAtAdmission = 0;
    private TArray<FString> _BusyChecks;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target beyond the strike's reach", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("record the admission's generation; request another start during Windup", n"Step_StartDuringWindup");
        Add_Step_WaitUntil("the start drained and was rejected", n"Check_StartRejected", k_SlowPolls, 0);
        Add_Step("the Windup start was rejected once, as Busy", n"Step_AssertBusy");
        Add_Step_WaitUntil("the attack is in Recover", n"Check_InRecover", k_SlowPolls, 0);
        Add_Step("request another start during Recover", n"Step_StartAgain");
        Add_Step_WaitUntil("the start drained and was rejected", n"Check_StartRejected", k_SlowPolls, 0);
        Add_Step("the Recover start was rejected once, as Busy", n"Step_AssertBusy");
        Add_Step_WaitUntil("the attack is in Cooldown", n"Check_InCooldown", k_SlowPolls, 0);
        Add_Step("request another start during Cooldown", n"Step_StartAgain");
        Add_Step_WaitUntil("the start drained and was rejected", n"Check_StartRejected", k_SlowPolls, 0);
        Add_Step("the Cooldown start was rejected once, as Busy", n"Step_AssertBusy");
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds("watch Idle for 1 s", 1.0f);
        Add_Step("the miss recovered and cooled down, and no rejected start ran later", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 55.0, FVector(10.0, 20.0, 20.0));
    }

    UFUNCTION()
    private void Step_StartDuringWindup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _GenerationAtAdmission = _Crawler.Get_AttackGeneration();
        Request_StartAndMark();
    }

    UFUNCTION()
    private void Step_StartAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Request_StartAndMark();
    }

    UFUNCTION()
    private void Step_AssertBusy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_RejectedOnce(EMars_Crawler_AttackReject::Busy, f"a start during {_Crawler.Get_AttackPhase() :n}");
        Assert_Equals_Int(_Crawler.Get_AttackGeneration(), _GenerationAtAdmission, "the rejected start did not begin a new attack");
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phases = Get_PhasesSinceMark();
        auto Windups = 0;
        for (const auto Phase : Phases)
        {
            if (Phase == EMars_Crawler_AttackPhase::Windup)
            { ++Windups; }
        }

        Assert_True(Phases.Num() == 5 && Phases[0] == EMars_Crawler_AttackPhase::Windup && Phases[1] == EMars_Crawler_AttackPhase::Strike &&
            Phases[2] == EMars_Crawler_AttackPhase::Recover && Phases[3] == EMars_Crawler_AttackPhase::Cooldown && Phases[4] == EMars_Crawler_AttackPhase::Idle,
            f"the miss ran Windup > Strike > Recover > Cooldown > Idle (got{Get_PhaseText(_RecordMark)})");
        Assert_Equals_Int(Windups, 1, "only one attack ever began");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle, f"the crawler stays in Idle (phase {_Crawler.Get_AttackPhase() :n})");
        Assert_Equals_Int(_Crawler.Get_AttackGeneration(), _GenerationAtAdmission, "the generation is still the one admission's");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "the miss sent no damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "the target is untouched");
        Assert_False(_Crawler.Get_AttackDamageCommitted(), "nothing was committed");
    }
}
