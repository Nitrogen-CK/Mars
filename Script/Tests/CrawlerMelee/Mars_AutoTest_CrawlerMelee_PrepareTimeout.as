// A Prepare that can never be satisfied times out into Wait and retries on a bounded cadence. An aggressive armed crawler
// engages a tagged hostile 200 cm ahead; as Engage reaches Prepare the target is lifted 120 cm, beyond
// MaxHeightDifference (the crawler keeps it: a held target is not height-checked, only a start is). The start would be
// rejected for Height every poll, so no start is ever requested: Prepare lasts TimeoutSeconds, Wait lasts
// BlockedRetrySeconds, Approach hands straight back to Prepare (the target is inside StartDistance, so no MoveTo), twice
// over: Prepare > Wait > Approach > Prepare > Wait. No attack starts and no start is rejected.
class UMars_AutoTest_CrawlerMelee_PrepareTimeout : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-180000.0, -180000.0, 600.0);

    private const FVector k_HalfExtents = FVector(20.0, 20.0, 20.0);
    private const float64 k_TargetAhead = 200.0;
    private const float64 k_Lift = 120.0;

    private int32 _PrepareIndex = -1;
    private int32 _MoveTosAtLift = 0;
    private EMars_Crawler_AttackPhase _PhaseAtLift = EMars_Crawler_AttackPhase::Idle;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_AggressiveCrawlerSpec(4));

        Add_SettleSteps();
        Add_Step("watch Engage; spawn a tagged hostile 200 cm ahead", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the crawler acquires the target", n"Check_TargetAcquired", k_SlowPolls, 0);
        Add_Step_WaitUntil("Engage reaches Prepare", n"Check_InEngagePrepare", k_SlowPolls, 0);
        Add_Step("lift the target 120 cm, out of the height band", n"Step_LiftTarget");
        Add_Step_WaitUntil("two Prepare timeouts: Prepare > Wait > Approach > Prepare > Wait", n"Check_TwoTimeouts", 4000, 0);
        Add_Step("each Prepare timed out, each Wait held its retry time, nothing started", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Watch_Engage();
        _RecordMark = _Records.Num();
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointFromRoot(k_TargetAhead, 0.0)), k_HalfExtents);
    }

    UFUNCTION()
    private void Step_LiftTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhaseAtLift = _Crawler.Get_AttackPhase();
        _PrepareIndex = Get_StageRecords().Num() - 1;
        _MoveTosAtLift = Get_MoveToRecords().Num();

        auto Root = _Target.Root;
        auto Lifted = utils_transform::Get_EntityCurrentTransform(Root);
        Lifted.SetLocation(Lifted.GetLocation() + FVector(0.0, 0.0, k_Lift));
        utils_transform::Request_SetTransform(Root, Lifted);
    }

    UFUNCTION()
    private void Check_TwoTimeouts(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Count_StageRecords(EMars_Crawler_EngageStage::Attack) > 0)
        {
            FinishFailure(f"Engage reached Attack with the target out of the height band (stages{Get_StageText(0)}, last reject {Get_LastRejectText()})");
            return;
        }

        auto Res = OutResult;
        Res.Set(_PrepareIndex >= 0 && Get_StageRecords().Num() >= _PrepareIndex + 5);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Combat = _Crawler.Get_Spec().Combat;
        const auto Stages = Get_StageRecords();
        const auto First = _PrepareIndex;

        Assert_True(_PhaseAtLift == EMars_Crawler_AttackPhase::Idle && Stages[First].Stage == EMars_Crawler_EngageStage::Prepare,
            f"the target was lifted during Prepare, before any attack (phase {_PhaseAtLift :n}, stage {Stages[First].Stage :n})");
        Assert_True(Stages[First + 1].Stage == EMars_Crawler_EngageStage::Wait && Stages[First + 2].Stage == EMars_Crawler_EngageStage::Approach &&
            Stages[First + 3].Stage == EMars_Crawler_EngageStage::Prepare && Stages[First + 4].Stage == EMars_Crawler_EngageStage::Wait,
            f"after the lift the stages run Prepare > Wait > Approach > Prepare > Wait (got{Get_StageText(First)})");

        for (int32 Offset = 0; Offset <= 3; Offset += 3)
        {
            const auto Prepared = Stages[First + Offset + 1].Time - Stages[First + Offset].Time;
            Assert_True(Prepared >= Combat.Prepare.TimeoutSeconds - 0.02,
                f"Prepare {Offset} lasted at least TimeoutSeconds [{Combat.Prepare.TimeoutSeconds :.2}] ({Prepared :.3} s)");
        }

        const auto Waited = Stages[First + 2].Time - Stages[First + 1].Time;
        Assert_True(Waited >= Combat.Targeting.BlockedRetrySeconds - 0.02,
            f"Wait lasted at least BlockedRetrySeconds [{Combat.Targeting.BlockedRetrySeconds :.2}] ({Waited :.3} s)");

        Assert_Equals_Int(Get_MoveToRecords().Num() - _MoveTosAtLift, 0, "no MoveTo went out after the lift (the target is inside StartDistance)");
        Assert_Equals_Int(Count_RecordsSinceMark(EMars_Crawler_AttackPhase::Windup), 0, "no attack started");
        Assert_True(_Crawler.Get_AttackLastReject().IsSet() == false, f"no start was requested and rejected (last reject {Get_LastRejectText()})");
    }
}
