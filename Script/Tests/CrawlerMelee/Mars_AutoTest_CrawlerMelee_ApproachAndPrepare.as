// An aggressive armed crawler at rest acquires a tagged hostile 500 cm ahead and engages it:
//   - Approach moves it toward the target with no two MoveTos closer than RepathSeconds (the target stands still, so no
//     displacement lifts the throttle) and hands over to Prepare inside StartDistance;
//   - the target is then moved 60 degrees off the crawler's heading, 90 cm from its root: Prepare's stop drains, no MoveTo
//     goes out, and the crawler turns at zero speed until it faces the target within FacingToleranceDegrees, staying
//     within 15 cm of where it stood;
//   - the attack is admitted exactly once, from a standing start (speed within MaxSpeedToStart, the navigator neither
//     Moving nor holding requests), then Engage waits out the cooldown.
// The stage order is Approach > Prepare > Attack > Wait.
class UMars_AutoTest_CrawlerMelee_ApproachAndPrepare : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-160000.0, -180000.0, 600.0);

    private const FVector k_HalfExtents = FVector(35.0, 25.0, 25.0);
    private const float64 k_StartAhead = 500.0;
    private const float64 k_AsideYawDegrees = 60.0;
    private const float64 k_AsideDistance = 90.0;
    private const float64 k_MaxTurnDrift = 15.0;

    private FVector _InitialTarget;
    private FVector _AsideTarget;
    private FVector _TurnStartLocation;
    private float64 _TurnStartError = 0.0;
    private int32 _MoveTosAtAside = 0;
    private EMars_Crawler_AttackPhase _PhaseAtAside = EMars_Crawler_AttackPhase::Idle;
    private EMars_Crawler_EngageStage _StageAtAside = EMars_Crawler_EngageStage::None;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_AggressiveCrawlerSpec(4);
        // The settle's roam may carry the crawler up to ~200 cm from home along its heading: keep the target inside the leash.
        Spec.Combat.Targeting.LoseRadius = 1000.0f;
        Spec.Combat.Targeting.HomeRadius = 1000.0f;
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("watch Engage; spawn a tagged hostile 500 cm ahead", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the crawler acquires the target", n"Check_TargetAcquired", k_SlowPolls, 0);
        Add_Step_WaitUntil("Engage reaches Prepare", n"Check_InEngagePrepare", k_SlowPolls, 0);
        Add_Step("move the target 60 deg off the heading, 90 cm from the root", n"Step_MoveTargetAside");
        Add_Step_WaitUntil("an attack is admitted (Windup)", n"Check_WindupSinceMark", k_SlowPolls, 0);
        Add_Step_WaitUntil("Engage reaches Wait", n"Check_InEngageWait", k_SlowPolls, 0);
        Add_Step("Approach throttled its MoveTos; Prepare stopped, turned in place and admitted one attack", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Watch_Engage();
        _RecordMark = _Records.Num();
        _InitialTarget = Get_PointFromRoot(k_StartAhead, 0.0);
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(_InitialTarget), k_HalfExtents);
    }

    UFUNCTION()
    private void Step_MoveTargetAside(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhaseAtAside = _Crawler.Get_AttackPhase();
        _StageAtAside = _Crawler.Get_EngageStage();
        _MoveTosAtAside = Get_MoveToRecords().Num();
        _TurnStartLocation = BodyLocation();

        const auto Direction = FRotator(0.0, k_AsideYawDegrees, 0.0).RotateVector(Get_Forward());
        _AsideTarget = BodyLocation() + Direction * k_AsideDistance;
        _AsideTarget.Z = _InitialTarget.Z;
        _TurnStartError = Get_HeadingErrorTo(Get_Forward(), BodyLocation(), _AsideTarget);

        auto Root = _Target.Root;
        utils_transform::Request_SetTransform(Root, FTransform(FRotator::ZeroRotator, _AsideTarget));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = _Crawler.Get_Spec();
        const auto Prepare = Get_ResolvedDefinition(GameplayTags::Attack_Mars_Jab).Prepare;
        const auto Stages = Get_StageRecords();
        const auto MoveTos = Get_MoveToRecords();

        Assert_True(_StageAtAside == EMars_Crawler_EngageStage::Prepare && _PhaseAtAside == EMars_Crawler_AttackPhase::Idle,
            f"the target was moved during Prepare, before any attack (stage {_StageAtAside :n}, phase {_PhaseAtAside :n})");

        Assert_True(Stages.Num() >= 4, f"at least four stage changes (got{Get_StageText(0)})");
        if (Stages.Num() < 4)
        { return; }

        Assert_True(Stages[0].Stage == EMars_Crawler_EngageStage::Approach && Stages[1].Stage == EMars_Crawler_EngageStage::Prepare &&
            Stages[2].Stage == EMars_Crawler_EngageStage::Attack && Stages[3].Stage == EMars_Crawler_EngageStage::Wait,
            f"the stages run Approach > Prepare > Attack > Wait (got{Get_StageText(0)})");

        const auto ApproachStart = (_InitialTarget - Stages[0].RootLocation).Size2D();
        const auto PrepareStart = (_InitialTarget - Stages[1].RootLocation).Size2D();
        Assert_True(ApproachStart >= 400.0, f"Approach began far from the target ({ApproachStart :.1} cm)");
        Assert_True(PrepareStart <= Prepare.MaxDistance + 5.0,
            f"Approach handed over inside the jab's MaxDistance [{Prepare.MaxDistance :.1}] ({PrepareStart :.1} cm)");

        auto ApproachMoveTos = 0;
        for (int32 Index = 0; Index < MoveTos.Num(); ++Index)
        {
            if (MoveTos[Index].Stage == EMars_Crawler_EngageStage::Approach)
            { ++ApproachMoveTos; }

            if (Index == 0)
            { continue; }

            const auto Gap = MoveTos[Index].Time - MoveTos[Index - 1].Time;
            Assert_True(Gap >= Spec.Combat.Targeting.RepathSeconds - 0.001,
                f"MoveTos {Index - 1} and {Index} are at least RepathSeconds apart for a target that did not move (gap {Gap :.3} s)");
        }
        Assert_True(ApproachMoveTos >= 1, f"Approach sent its MoveTo ({MoveTos.Num()} recorded)");
        Assert_Equals_Int(MoveTos.Num() - _MoveTosAtAside, 0, "no MoveTo went out after the target moved during Prepare");

        Assert_True(_TurnStartError >= 45.0, f"the moved target starts well off the heading ({_TurnStartError :.1} deg), so the turn is real");

        const auto WindupIndex = Find_RecordSinceMark(EMars_Crawler_AttackPhase::Windup);
        if (WindupIndex < 0)
        { return; }

        const auto Windup = _Records[WindupIndex];
        const auto FacingError = Get_HeadingErrorTo(Windup.RootForward, Windup.RootLocation, _AsideTarget);
        const auto TurnDrift = (Windup.RootLocation - _TurnStartLocation).Size2D();
        Assert_True(FacingError <= Prepare.FacingToleranceDegrees + 0.5,
            f"the attack started facing the target within tolerance ({FacingError :.2} deg)");
        Assert_True(Windup.Speed <= Prepare.MaxSpeedToStart, f"the attack started standing ({Windup.Speed :.2} cm/s)");
        Assert_True(Windup.NavigatorMoving == false && Windup.NavigatorPending == false,
            f"the navigator had drained its stop when the attack started (moving {Windup.NavigatorMoving}, pending {Windup.NavigatorPending})");
        Assert_True(TurnDrift < k_MaxTurnDrift, f"the crawler turned in place ({TurnDrift :.2} cm from where it stood)");
        Assert_True(Windup.EngageStage == EMars_Crawler_EngageStage::Attack, f"the attack started from the Attack stage ({Windup.EngageStage :n})");
        Assert_Equals_Int(Count_RecordsSinceMark(EMars_Crawler_AttackPhase::Windup), 1, f"exactly one attack was admitted (phases{Get_PhaseText(_RecordMark)})");
    }
}
