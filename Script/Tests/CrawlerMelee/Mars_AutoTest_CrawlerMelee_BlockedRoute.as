// An aggressive armed crawler engages a tagged hostile 400 cm ahead that stands inside a closed ring of static walls taller
// than it can step. There is no nav field here, so the route is a straight line into the ring's near wall: the navigator's
// stuck watchdog fails the move, Engage waits BlockedRetrySeconds, and Approach tries once more. Over two such rounds:
// the stages run Approach > Wait > Approach > Wait > Approach, each Wait entered on a Stuck failure and lasting at least
// BlockedRetrySeconds; no two MoveTos are closer than BlockedRetrySeconds and none goes out during Wait; no attack starts.
class UMars_AutoTest_CrawlerMelee_BlockedRoute : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 70.0f;
    default _Origin = FVector(-170000.0, -180000.0, 600.0);

    private const FVector k_HalfExtents = FVector(20.0, 20.0, 20.0);
    private const float64 k_TargetAhead = 400.0;
    // The ring's inner half width and its walls' half thickness and half height.
    private const float64 k_RingHalfWidth = 130.0;
    private const float64 k_WallHalfThickness = 10.0;
    private const float64 k_WallHalfHeight = 150.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_AggressiveCrawlerSpec(4);
        // The settle's roam may carry the crawler up to ~200 cm from home along its heading: keep the target inside the leash.
        Spec.Combat.Targeting.LoseRadius = 1000.0f;
        Spec.Combat.Targeting.HomeRadius = 1000.0f;
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("watch Engage; spawn a tagged hostile 400 cm ahead inside a ring of walls", n"Step_SpawnWalledTarget");
        Add_Step_WaitUntil("the crawler acquires the target", n"Check_TargetAcquired", k_SlowPolls, 0);
        Add_Step_WaitUntil("two blocked rounds: Approach > Wait > Approach > Wait > Approach, and the third MoveTo", n"Check_TwoBlockedRounds", 4000, 0);
        Add_Step("each round failed Stuck, waited its retry time, and sent one MoveTo", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnWalledTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Watch_Engage();
        _RecordMark = _Records.Num();

        const auto Center = Get_PointFromRoot(k_TargetAhead, 0.0);
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Center), k_HalfExtents);

        const auto Forward = Get_Forward();
        const auto Right = Get_Right();
        const auto Rotation = Forward.Rotation();
        const auto WallCenter = FVector(Center.X, Center.Y, _Origin.Z + k_WallHalfHeight);
        const auto Offset = k_RingHalfWidth + k_WallHalfThickness;
        const auto Span = k_RingHalfWidth + 2.0 * k_WallHalfThickness;

        SpawnWallAt(InHandle, FTransform(Rotation, WallCenter - Forward * Offset), FVector(k_WallHalfThickness, Span, k_WallHalfHeight));
        SpawnWallAt(InHandle, FTransform(Rotation, WallCenter + Forward * Offset), FVector(k_WallHalfThickness, Span, k_WallHalfHeight));
        SpawnWallAt(InHandle, FTransform(Rotation, WallCenter - Right * Offset), FVector(Span, k_WallHalfThickness, k_WallHalfHeight));
        SpawnWallAt(InHandle, FTransform(Rotation, WallCenter + Right * Offset), FVector(Span, k_WallHalfThickness, k_WallHalfHeight));
    }

    UFUNCTION()
    private void Check_TwoBlockedRounds(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Count_StageRecords(EMars_Crawler_EngageStage::Prepare) > 0 || Count_StageRecords(EMars_Crawler_EngageStage::Attack) > 0)
        {
            FinishFailure(f"the walled-in target was reached (stages{Get_StageText(0)}; {Get_CrawlerDiagnostics()})");
            return;
        }

        auto Res = OutResult;
        Res.Set(Count_StageRecords(EMars_Crawler_EngageStage::Approach) >= 3 && Count_StageRecords(EMars_Crawler_EngageStage::Wait) >= 2 &&
            Get_MoveToRecords().Num() >= 3);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Targeting = _Crawler.Get_Spec().Combat.Targeting;
        const auto Stages = Get_StageRecords();
        const auto MoveTos = Get_MoveToRecords();

        Assert_True(Stages.Num() >= 5 &&
            Stages[0].Stage == EMars_Crawler_EngageStage::Approach && Stages[1].Stage == EMars_Crawler_EngageStage::Wait &&
            Stages[2].Stage == EMars_Crawler_EngageStage::Approach && Stages[3].Stage == EMars_Crawler_EngageStage::Wait &&
            Stages[4].Stage == EMars_Crawler_EngageStage::Approach,
            f"the stages run Approach > Wait > Approach > Wait > Approach (got{Get_StageText(0)})");
        if (Stages.Num() < 5)
        { return; }

        for (int32 Index = 1; Index <= 3; Index += 2)
        {
            const auto Wait = Stages[Index];
            Assert_True(Wait.NavigatorStatus == EMars_SurfaceNavigator_Status::Failed && Wait.FailReason == EMars_SurfaceNavigator_FailReason::Stuck,
                f"Wait {Index} began on a Stuck failure (navigator {Wait.NavigatorStatus :n}, {Wait.FailReason :n})");

            const auto Waited = Stages[Index + 1].Time - Wait.Time;
            Assert_True(Waited >= Targeting.BlockedRetrySeconds - 0.02,
                f"Wait {Index} lasted at least BlockedRetrySeconds [{Targeting.BlockedRetrySeconds :.2}] ({Waited :.3} s)");
        }

        Assert_True(MoveTos.Num() >= 3, f"each Approach sent a MoveTo ({MoveTos.Num()} recorded)");
        for (int32 Index = 0; Index < MoveTos.Num(); ++Index)
        {
            Assert_True(MoveTos[Index].Stage != EMars_Crawler_EngageStage::Wait, f"MoveTo {Index} did not go out during Wait");
            if (Index == 0)
            { continue; }

            const auto Gap = MoveTos[Index].Time - MoveTos[Index - 1].Time;
            Assert_True(Gap >= Targeting.BlockedRetrySeconds, f"MoveTos {Index - 1} and {Index} are at least BlockedRetrySeconds apart ({Gap :.3} s)");
        }

        Assert_Equals_Int(Count_RecordsSinceMark(EMars_Crawler_AttackPhase::Windup), 0, "no attack started");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "the walled-in target is untouched");
    }
}
