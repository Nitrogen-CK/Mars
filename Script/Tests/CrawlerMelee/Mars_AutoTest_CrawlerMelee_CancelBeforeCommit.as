// A hit the resolver has already stored is discarded, not committed, when the next attack tick finds the attack invalid.
// Each target's near face is 5 cm ahead of the neutral hit centre, so the first Strike sample's sweep starts inside it and
// stores a candidate on that sample. Three attacks in turn, each proving the candidate existed and was discarded (no
// damage request, the attack eased back through CancelRecover):
//   1. the target is destroyed in the frame its candidate is stored (FGroup_Overlap, after the resolver): TargetLost;
//   2. a fresh target's Health is depleted in the frame the first Strike sample is staged, before its resolution:
//      TargetLost;
//   3. a fresh target, and one of the crawler's leg zones is hit in the frame the first Strike sample is staged. The
//      zone hit reaches the leg's Health in the same frame, before the resolver, so the crawler's HurtCount changes
//      between the candidate's sample and the commit pass: Hurt, decided by the attack tick's own HurtCount check, before
//      the brain's IsHurt fact can reach the behaviour.
class UMars_AutoTest_CrawlerMelee_CancelBeforeCommit : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-230000.0, -150000.0, 600.0);

    private const FVector k_HalfExtents = FVector(10.0, 20.0, 20.0);
    private const float64 k_FaceAhead = 5.0;

    private FCk_Handle _TriggerEntity;
    private int32 _HurtCountBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("(1) spawn a target; arm its destruction on the stored candidate", n"Step_ArmDestroyTarget");
        Add_AttackSteps("(1)");
        Add_Step("(1) the destroyed target's candidate was discarded", n"Step_AssertDestroyed");
        Add_Step("(2) spawn a fresh target; arm the depletion of its Health as the first Strike sample is staged", n"Step_ArmDepleteTarget");
        Add_AttackSteps("(2)");
        Add_Step("(2) the depleted target's candidate was discarded; remove it", n"Step_AssertDepleted");
        Add_Step_WaitFrames("(3) let the depleted target go", 5);
        Add_Step("(3) spawn a fresh target; arm a hit on a leg zone as the first Strike sample is staged", n"Step_ArmHurtCrawler");
        Add_AttackSteps("(3)");
        Add_Step("(3) the hurt crawler's candidate was discarded", n"Step_AssertHurt");
        Run_Steps(InHandle);
    }

    private void Add_AttackSteps(FString InLabel)
    {
        Add_Step_WaitUntil(f"{InLabel} the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step(f"{InLabel} select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil(f"{InLabel} the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil(f"{InLabel} the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitSeconds(f"{InLabel} settle 0.5 s", 0.5f);
    }

    private void Assert_CandidateDiscarded(FString InLabel, EMars_Crawler_AttackCancel InExpected)
    {
        const auto Trigger = _TriggerEntity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger);
        Assert_True(Trigger.Fired, f"{InLabel} the trigger fired");
        Assert_True(Trigger.SawCandidate, f"{InLabel} a candidate was stored (phases{Get_PhaseText(_RecordMark)}, last cancel {Get_LastCancelText()})");

        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == InExpected,
            f"{InLabel} the attack was cancelled as {InExpected :n} (last cancel {Get_LastCancelText()})");

        const auto CancelIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover);
        Assert_True(CancelIndex >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Recover) < 0,
            f"{InLabel} the attack eased back through CancelRecover (phases{Get_PhaseText(_RecordMark)})");
        if (CancelIndex >= 0)
        {
            Assert_True(_Records[CancelIndex].Frame == Trigger.SawCandidateFrame + 1,
                f"{InLabel} the cancel came on the pass right after the candidate (candidate frame {Trigger.SawCandidateFrame}, cancel frame {_Records[CancelIndex].Frame})");
            Assert_False(_Records[CancelIndex].DamageCommitted, f"{InLabel} nothing was committed before the cancel");
        }

        Assert_Equals_Int(Get_DamageRequestCount(), 0, f"{InLabel} no damage request was sent");
        Assert_False(_Crawler.Get_AttackDamageCommitted(), f"{InLabel} the attack committed nothing");
    }

    UFUNCTION()
    private void Step_ArmDestroyTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, k_FaceAhead, k_HalfExtents);

        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::CandidatePending, EMars_TESTONLY_CrawlerMelee_Action::DestroyEntity);
        Trigger.Entity = _Target.Entity;
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Step_AssertDestroyed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_CandidateDiscarded("(1) destroyed:", EMars_Crawler_AttackCancel::TargetLost);
        Assert_True(ck::Is_NOT_Valid(_Target.Entity) || utils_entity_lifetime::Get_IsPendingDestroy(_Target.Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy),
            "(1) the target is gone");
    }

    UFUNCTION()
    private void Step_ArmDepleteTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, k_FaceAhead, k_HalfExtents);

        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::WindupEndpointAccepted, EMars_TESTONLY_CrawlerMelee_Action::DamageHealth);
        Trigger.Health = _Target.Health;
        Trigger.Amount = 100.0f;
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Step_AssertDepleted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_CandidateDiscarded("(2) depleted:", EMars_Crawler_AttackCancel::TargetLost);
        Assert_True(_Target.Health.Get_IsDepleted(), "(2) the target's Health is depleted (by the test, not the crawler)");
        utils_entity_lifetime::Request_DestroyEntity(_Target.Entity);
    }

    UFUNCTION()
    private void Step_ArmHurtCrawler(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, k_FaceAhead, k_HalfExtents);
        _HurtCountBefore = _Crawler.Get_HurtCount();

        auto Trigger = Make_Trigger(EMars_TESTONLY_CrawlerMelee_When::WindupEndpointAccepted, EMars_TESTONLY_CrawlerMelee_Action::HitZone);
        Trigger.HitZone = _Crawler.Get_LegParts()[0].Get_Zone();
        Trigger.Amount = 5.0f;
        _TriggerEntity = Add_Trigger(InHandle, Trigger);
    }

    UFUNCTION()
    private void Step_AssertHurt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_CandidateDiscarded("(3) hurt:", EMars_Crawler_AttackCancel::Hurt);
        Assert_True(_Crawler.Get_HurtCount() > _HurtCountBefore, f"(3) the leg hit counted (HurtCount {_HurtCountBefore} -> {_Crawler.Get_HurtCount()})");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "(3) the target is untouched");
    }
}
