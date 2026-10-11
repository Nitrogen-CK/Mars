// One directly requested jab runs Windup -> Strike -> Recover -> Cooldown -> Idle, each phase entered on the acknowledged
// endpoint of the one before it: entering Strike the body pose holds the windup key, entering Recover the strike key,
// entering Cooldown and Idle identity. The target stands where the strike reaches it mid-phase, and its one damage
// request comes from a Strike sample: no request exists when Strike is entered, the committed sample lies after the
// windup's endpoint and no later than the strike's, and the target loses exactly the jab's 15 HP.
class UMars_AutoTest_CrawlerMelee_PhaseSequence : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-170000.0, -150000.0, 600.0);

    private const float64 k_KeyTolerance = 0.01;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("spawn a target the strike reaches mid-phase (near face 30 cm ahead of the neutral hit centre)", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the target's Health has taken the hit", n"Check_TargetHit", k_SlowPolls, 0);
        Add_Step_WaitSeconds("settle 0.5 s", 0.5f);
        Add_Step("the phases ran in order on their endpoints and the one hit came from a Strike sample", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));
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
        const auto Phases = Get_PhaseText(_RecordMark);
        const auto Pose = _Crawler.Get_Spec().Combat.Pose;

        Assert_True(_Records.Num() - _RecordMark == 5, f"exactly five phase changes (got{Phases})");
        if (_Records.Num() - _RecordMark != 5)
        { return; }

        const auto ToWindup = _Records[_RecordMark];
        const auto ToStrike = _Records[_RecordMark + 1];
        const auto ToRecover = _Records[_RecordMark + 2];
        const auto ToCooldown = _Records[_RecordMark + 3];
        const auto ToIdle = _Records[_RecordMark + 4];

        Assert_True(ToWindup.Old == EMars_Crawler_AttackPhase::Idle && ToWindup.New == EMars_Crawler_AttackPhase::Windup &&
            ToStrike.New == EMars_Crawler_AttackPhase::Strike && ToRecover.New == EMars_Crawler_AttackPhase::Recover &&
            ToCooldown.New == EMars_Crawler_AttackPhase::Cooldown && ToIdle.New == EMars_Crawler_AttackPhase::Idle,
            f"the phases are Windup > Strike > Recover > Cooldown > Idle (got{Phases})");

        Assert_True((ToStrike.ActionOffset - Pose.Windup.GetLocation()).Size() <= k_KeyTolerance,
            f"Strike is entered with the windup key posed (action {ToStrike.ActionOffset.ToString()})");
        Assert_True((ToRecover.ActionOffset - Pose.Strike.GetLocation()).Size() <= k_KeyTolerance,
            f"Recover is entered with the strike key posed (action {ToRecover.ActionOffset.ToString()})");
        Assert_True(ToCooldown.ActionOffset.Size() <= k_KeyTolerance && ToIdle.ActionOffset.Size() <= k_KeyTolerance,
            f"Cooldown and Idle are entered at identity (actions {ToCooldown.ActionOffset.ToString()}, {ToIdle.ActionOffset.ToString()})");

        Assert_True(ToWindup.DamageRequests == 0 && ToStrike.DamageRequests == 0 && ToStrike.DamageCommitted == false,
            f"no damage request exists before Strike (at Windup {ToWindup.DamageRequests}, at Strike {ToStrike.DamageRequests}, committed {ToStrike.DamageCommitted})");
        Assert_True(ToRecover.DamageCommitted && ToCooldown.DamageCommitted,
            "the hit was committed during Strike and the latch survives into Recover and Cooldown");

        const auto Committed = _Crawler.Get_AttackCommittedSampleId();
        Assert_True(Committed > ToStrike.AcknowledgedSampleId && Committed <= ToRecover.AcknowledgedSampleId,
            f"the committed sample [{Committed}] is a Strike sample: after the windup endpoint [{ToStrike.AcknowledgedSampleId}], no later than the strike endpoint [{ToRecover.AcknowledgedSampleId}]");

        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the target lost the jab's 15 HP once");
        Assert_True(utils_procedural_body_pose::Get_ActionOffset(_Crawler.Get_BodyPose()).Equals(FTransform::Identity, 0.001),
            "the body pose's action input is identity after the attack");
        Assert_True(_Crawler.Get_AttackLastCancel().IsSet() == false, f"nothing cancelled the attack (last cancel {Get_LastCancelText()})");
    }
}
