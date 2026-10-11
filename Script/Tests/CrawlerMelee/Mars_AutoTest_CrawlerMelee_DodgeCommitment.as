// The attack commits to the direction the root faced at admission and never tracks the target. The target stands where
// the strike would reach it, and steps 80 cm sideways during Windup: the committed direction and the root's heading stay
// where they were, the strike runs straight ahead past the target, and the attack finishes as a miss (no cancel, no
// damage request, the target untouched).
class UMars_AutoTest_CrawlerMelee_DodgeCommitment : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-210000.0, -150000.0, 600.0);

    private const FVector k_HalfExtents = FVector(10.0, 20.0, 20.0);
    private const float64 k_SidestepCm = 80.0;

    private FVector _ForwardAtStart;
    private FVector _CommittedAtWindup;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target the strike would reach", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("during Windup the target steps 80 cm to the side", n"Step_Sidestep");
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds("settle 0.5 s", 0.5f);
        Add_Step("the attack kept its direction and missed", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _ForwardAtStart = Get_Forward();
        _Target = SpawnTargetAhead(InHandle, 30.0, k_HalfExtents);
    }

    UFUNCTION()
    private void Step_Sidestep(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Windup, f"the sidestep happens during Windup (phase {_Crawler.Get_AttackPhase() :n})");
        _CommittedAtWindup = _Crawler.Get_AttackCommittedDirection();

        auto Root = _Target.Root;
        utils_transform::Request_SetTransform(Root, Get_FacingTransform(Get_PointAhead(30.0 + k_HalfExtents.X, k_SidestepCm)));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Committed = _Crawler.Get_AttackCommittedDirection();
        Assert_True(_CommittedAtWindup.DotProduct(_ForwardAtStart) >= Math::Cos(Math::DegreesToRadians(2.0)),
            f"the committed direction is the root's forward at admission (committed {_CommittedAtWindup.ToString()}, forward {_ForwardAtStart.ToString()})");
        Assert_True((Committed - _CommittedAtWindup).Size() <= 0.0001, "the committed direction never changed after the sidestep");
        Assert_True(Get_Forward().DotProduct(_ForwardAtStart) >= Math::Cos(Math::DegreesToRadians(2.0)),
            f"the root did not turn toward the target (forward {Get_Forward().ToString()}, at start {_ForwardAtStart.ToString()})");

        const auto Phases = Get_PhasesSinceMark();
        Assert_True(Phases.Num() == 5 && Phases[1] == EMars_Crawler_AttackPhase::Strike && Phases[2] == EMars_Crawler_AttackPhase::Recover,
            f"the attack ran to the end (got{Get_PhaseText(_RecordMark)}, last cancel {Get_LastCancelText()})");
        Assert_True(_Crawler.Get_AttackLastCancel().IsSet() == false, f"nothing cancelled the attack (last cancel {Get_LastCancelText()})");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "the dodged attack sent no damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "the target is untouched");
    }
}
