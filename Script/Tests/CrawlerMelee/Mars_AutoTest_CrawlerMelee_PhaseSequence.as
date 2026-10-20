// One directly requested jab runs Windup -> Strike -> Recover -> Cooldown -> Idle, each posed phase entered on the first
// accepted clip interval of that phase, which starts exactly where the phase before it ended (where the clip holds the
// windup key, then the strike key); Cooldown is entered on the interval that ends the clip, and Cooldown and Idle find
// the presentation at neutral. The target stands where the strike reaches it mid-phase, and its one damage request
// comes from a Strike sample: no request exists when Strike is entered, the committed sample is a Strike interval's
// (no earlier than the one that entered Strike, before the one that entered Recover), and the target loses exactly the
// jab's 15 HP.
class UMars_AutoTest_CrawlerMelee_PhaseSequence : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-170000.0, -150000.0, 600.0);

    private const float64 k_KeyTolerance = 0.01;
    private const float64 k_TimeTolerance = 1.0e-4;
    private const float64 k_NeutralToleranceCm = 1.0;

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

        // Phases follow the accepted clip PhaseId: a phase is entered on its own first accepted interval, which starts on
        // the previous phase's key.
        const auto WindupEnd = Get_AttackPhaseEnd(EMars_Crawler_AttackPhase::Windup);
        const auto StrikeEnd = Get_AttackPhaseEnd(EMars_Crawler_AttackPhase::Strike);
        const auto ClipEnd = Get_AttackPhaseEnd(EMars_Crawler_AttackPhase::Recover);
        Assert_True(ToStrike.AcceptedPhaseId == n"Strike" && Math::Abs(ToStrike.AcceptedFrom - WindupEnd) <= k_TimeTolerance,
            f"Strike is entered on the first accepted Strike interval, from the windup key at [{WindupEnd :.4}] s (got {ToStrike.AcceptedPhaseId} from [{ToStrike.AcceptedFrom :.4}])");
        Assert_True(ToRecover.AcceptedPhaseId == n"Recover" && Math::Abs(ToRecover.AcceptedFrom - StrikeEnd) <= k_TimeTolerance,
            f"Recover is entered on the first accepted Recover interval, from the strike key at [{StrikeEnd :.4}] s (got {ToRecover.AcceptedPhaseId} from [{ToRecover.AcceptedFrom :.4}])");
        Assert_True(ToCooldown.AcceptedPhaseId == n"Recover" && Math::Abs(ToCooldown.AcceptedTo - ClipEnd) <= k_TimeTolerance,
            f"Cooldown is entered on the accepted interval that ends the clip at [{ClipEnd :.4}] s (got {ToCooldown.AcceptedPhaseId} to [{ToCooldown.AcceptedTo :.4}])");
        Assert_True(ToCooldown.PresentationErrorCm <= k_NeutralToleranceCm && ToIdle.PresentationErrorCm <= k_NeutralToleranceCm,
            f"Cooldown and Idle are entered with the presentation at neutral ({ToCooldown.PresentationErrorCm :.3}, {ToIdle.PresentationErrorCm :.3} cm)");

        Assert_True(ToWindup.DamageRequests == 0 && ToStrike.DamageRequests == 0 && ToStrike.DamageCommitted == false,
            f"no damage request exists before Strike (at Windup {ToWindup.DamageRequests}, at Strike {ToStrike.DamageRequests}, committed {ToStrike.DamageCommitted})");
        Assert_True(ToRecover.DamageCommitted && ToCooldown.DamageCommitted,
            "the hit was committed during Strike and the latch survives into Recover and Cooldown");

        // ToStrike carries the first Strike sample and ToRecover the first Recover sample.
        const auto Committed = _Crawler.Get_AttackCommittedSampleId();
        Assert_True(Committed >= ToStrike.AcknowledgedSampleId && Committed < ToRecover.AcknowledgedSampleId,
            f"the committed sample [{Committed}] is a Strike sample: no earlier than the first Strike interval [{ToStrike.AcknowledgedSampleId}], before the first Recover interval [{ToRecover.AcknowledgedSampleId}]");

        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the dealer drained exactly one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the target lost the jab's 15 HP once");
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        const auto BodyPose = _Crawler.Get_BodyPose();
        const auto ExpectedNeutral = utils_procedural_body_pose::Get_Offset(BodyPose) * Root;
        const auto Presented = utils_transform::Get_EntityCurrentTransform(_Crawler.Get_Presentation());
        const auto NeutralErrorCm = (Presented.GetLocation() - ExpectedNeutral.GetLocation()).Size();
        Assert_True(NeutralErrorCm < k_KeyTolerance,
            f"the presentation follows the current support/conform neutral (error {NeutralErrorCm :.5} cm)");
        Assert_True(ck::Is_NOT_Valid(_Crawler.Get_AttackAction()),
            "the action released itself after its terminal receipt");
        Assert_True(_Crawler.Get_AttackLastCancel().IsSet() == false, f"nothing cancelled the attack (last cancel {Get_LastCancelText()})");
    }
}
