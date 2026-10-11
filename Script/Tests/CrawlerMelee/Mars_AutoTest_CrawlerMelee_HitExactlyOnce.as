// A target with two overlapping hurtboxes on its one zone, both inside the strike's path, takes one damage request per
// attack: one zone hit, 15 HP, one request drained by the crawler's dealer, however many strike samples and hurtboxes
// touch it. Run for the production 4-legged crawler, then for a 6-legged one on its own floor (its longer body moves the
// default hit centre and start distance with it).
class UMars_AutoTest_CrawlerMelee_HitExactlyOnce : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 70.0f;
    default _Origin = FVector(-180000.0, -150000.0, 600.0);

    private const FVector k_SixLegOffset = FVector(0.0, 5000.0, 0.0);

    private int32 _LegCount = 4;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_AttackSteps("4 legs");
        Add_Step("spawn the 6-legged crawler on its own floor", n"Step_SpawnSixLegs");
        Add_AttackSteps("6 legs");
        Run_Steps(InHandle);
    }

    private void Add_AttackSteps(FString InLabel)
    {
        Add_SettleSteps();
        Add_Step(f"{InLabel}: spawn a target with two overlapping hurtboxes in the strike's path", n"Step_SpawnTarget");
        Add_Step_WaitUntil(f"{InLabel}: the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step(f"{InLabel}: select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil(f"{InLabel}: the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil(f"{InLabel}: the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil(f"{InLabel}: the target's Health has taken the hit", n"Check_TargetHit", k_SlowPolls, 0);
        Add_Step_WaitSeconds(f"{InLabel}: settle 1 s, long enough for any second request to land", 1.0f);
        Add_Step(f"{InLabel}: one request, one zone hit, 15 HP", n"Step_Assert");
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));
        AddHurtbox(_Target, FVector(10.0, 20.0, 20.0), FTransform(FRotator::ZeroRotator, FVector(5.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Step_SpawnSixLegs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LegCount = 6;
        _Origin = _Origin + k_SixLegOffset;
        _Crawler = FCk_Handle_Crawler();
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(6));
    }

    UFUNCTION()
    private void Check_TargetHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Target.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Crawler.Get_Spec().LegCount, _LegCount, "the attack ran on the crawler of this round");
        Assert_Equals_Int(_Target.Zone.Get_Hurtboxes().Num(), 2, f"[{_LegCount} legs] the target's zone holds both hurtboxes");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, f"[{_LegCount} legs] the dealer drained exactly one damage request");
        Assert_Equals_Int(_Target.Zone.Get_HitCount(), 1, f"[{_LegCount} legs] the target's zone was hit exactly once");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, f"[{_LegCount} legs] the target lost 15 HP once");
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover) < 0,
            f"[{_LegCount} legs] the attack ran to the end (phases{Get_PhaseText(_RecordMark)}, last cancel {Get_LastCancelText()})");
    }
}
