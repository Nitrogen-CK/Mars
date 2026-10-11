// Target acquisition, retention and loss on an aggressive armed crawler (AcquireRadius 300, LoseRadius 450, HomeRadius
// 600). Its brain is switched off once it rests, so its behaviour holds Roam and only the targeting processor acts; the test
// then drives it 300 cm from its home, so every radius below is measured from where it stands (R) or from home (H):
//   1. two tagged hostiles at 150 and 250 cm: the nearer is chosen and kept. Nearer still stand a tagged entity on the
//      crawler's own team and an untagged hostile: neither is ever chosen;
//   2. both removed, two tagged hostiles at one point (the same distance however the root jitters): the one whose handle
//      string is lower is chosen, and the choice holds;
//   3. the chosen target moved to 380 cm from R (past AcquireRadius, inside LoseRadius and HomeRadius) is kept;
//   4. moved to 480 cm from R (past LoseRadius, still inside HomeRadius) it is lost, and the fact clears;
//   5. brought back it is chosen again; moved 650 cm from H while 450 cm or less from R it is lost to the leash;
//   6. brought back and chosen again, its Health depleted: it is lost.
// A target in another world is not staged: the scan reads only the crawler's own world's tag registry.
class UMars_AutoTest_CrawlerMelee_AcquireAndLeash : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 80.0f;
    default _Origin = FVector(-150000.0, -180000.0, 600.0);

    private const float64 k_DriveDistance = 300.0;
    private const float32 k_HoldSeconds = 1.0f;
    private const FVector k_HalfExtents = FVector(20.0, 20.0, 20.0);

    private FVector _Root;
    private FVector _Home;
    private FVector _AwayFromHome;
    private FVector _Side;
    private float64 _HomeDistance = 0.0;

    private FMars_AutoTest_CrawlerMelee_Target _Far;
    private FMars_AutoTest_CrawlerMelee_Target _Near;
    private FMars_AutoTest_CrawlerMelee_Target _Friendly;
    private FMars_AutoTest_CrawlerMelee_Target _Untagged;
    private FMars_AutoTest_CrawlerMelee_Target _TieA;
    private FMars_AutoTest_CrawlerMelee_Target _TieB;
    private FCk_Handle _Expected;

    private float64 _HoldSince = 0.0;
    private bool _ChoseIgnored = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_AggressiveCrawlerSpec(4);
        Spec.Combat.Targeting.AcquireRadius = 300.0f;
        Spec.Combat.Targeting.LoseRadius = 450.0f;
        Spec.Combat.Targeting.HomeRadius = 600.0f;
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("switch the brain off (behaviour holds Roam) and drive the crawler 300 cm from home", n"Step_HoldAndDrive");
        Add_Step_WaitUntil("the drive arrived", n"Check_Arrived", k_SlowPolls, 0);
        Add_Step("stop the navigator", n"Step_StopCrawlerNavigator");
        Add_Step_WaitUntil("the navigator has drained the stop and is not Moving", n"Check_CrawlerNavigatorStopped", k_SlowPolls, 0);
        Add_Step_WaitUntil("the crawler is at rest again", n"Check_AtRest", k_SlowPolls, 0);
        Add_Step("record root and home", n"Step_RecordGeometry");

        Add_Step("(1) spawn hostiles at 150 and 250 cm, a tagged team-mate at 100 cm and an untagged hostile at 60 cm", n"Step_SpawnPair");
        Add_Step_WaitUntil("(1) the nearer hostile is chosen and the fact is true", n"Check_ExpectedHeld", k_SlowPolls, 0);
        Add_Step("(1) start holding", n"Step_BeginHold");
        Add_Step_WaitUntil("(1) the choice holds for 1 s", n"Check_HoldsExpected", k_SlowPolls, 0);

        Add_Step("(2) remove both hostiles; spawn two at one point", n"Step_SpawnTie");
        Add_Step_WaitUntil("(2) one of the two is chosen", n"Check_TieChosen", k_SlowPolls, 0);
        Add_Step("(2) the lower handle string won; start holding", n"Step_AssertTieAndHold");
        Add_Step_WaitUntil("(2) the choice holds for 1 s", n"Check_HoldsExpected", k_SlowPolls, 0);

        Add_Step("(3) remove the other; move the chosen one 380 cm from the root", n"Step_MoveToRetention");
        Add_Step_WaitUntil("(3) it is kept for 1 s past AcquireRadius", n"Check_HoldsExpected", k_SlowPolls, 0);

        Add_Step("(4) move it 480 cm from the root", n"Step_MovePastLoseRadius");
        Add_Step_WaitUntil("(4) it is lost and the fact is false", n"Check_TargetLost", k_SlowPolls, 0);

        Add_Step("(5) bring it back to 200 cm", n"Step_BringBack");
        Add_Step_WaitUntil("(5) it is chosen again", n"Check_ExpectedHeld", k_SlowPolls, 0);
        Add_Step("(5) move it 650 cm from home", n"Step_MovePastLeash");
        Add_Step_WaitUntil("(5) it is lost to the leash", n"Check_TargetLost", k_SlowPolls, 0);

        Add_Step("(6) bring it back to 200 cm", n"Step_BringBack");
        Add_Step_WaitUntil("(6) it is chosen again", n"Check_ExpectedHeld", k_SlowPolls, 0);
        Add_Step("(6) deplete its Health", n"Step_Deplete");
        Add_Step_WaitUntil("(6) it is lost and the fact is false", n"Check_TargetLost", k_SlowPolls, 0);
        Add_Step("neither the team-mate nor the untagged hostile was ever chosen", n"Step_AssertNeverIgnored");
        Run_Steps(InHandle);
    }

    private FTransform At(FVector InPoint) const
    {
        return FTransform(FRotator::ZeroRotator, InPoint);
    }

    private FVector Lifted(FVector InPoint) const
    {
        return FVector(InPoint.X, InPoint.Y, _Root.Z);
    }

    private void Watch_Ignored()
    {
        const auto Held = _Crawler.Get_CombatTarget();
        if (ck::Is_NOT_Valid(Held))
        { return; }

        if (Held == _Friendly.Entity || Held == _Untagged.Entity)
        { _ChoseIgnored = true; }
    }

    private void Move(FMars_AutoTest_CrawlerMelee_Target& InTarget, FVector InPoint)
    {
        auto Root = InTarget.Root;
        utils_transform::Request_SetTransform(Root, At(Lifted(InPoint)));
    }

    UFUNCTION()
    private void Step_HoldAndDrive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Brain = _Crawler.Get_Brain();
        Brain.Request_SetEnabled(FMars_Request_Brain_SetEnabled(ECk_EnableDisable::Disable));

        auto Navigator = _Crawler.Get_Navigator();
        Navigator.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(_Crawler.Get_CombatHome() + FVector(k_DriveDistance, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Navigator = _Crawler.Get_Navigator();
        auto Res = OutResult;
        Res.Set(Navigator.Get_HasPendingRequests() == false && Navigator.Get_Status() == EMars_SurfaceNavigator_Status::Arrived);
    }

    UFUNCTION()
    private void Step_RecordGeometry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Root = BodyLocation();
        _Home = _Crawler.Get_CombatHome();
        _HomeDistance = (_Root - _Home).Size2D();
        _AwayFromHome = (_Root - _Home).GetSafeNormal2D();
        _Side = FVector::UpVector.CrossProduct(_AwayFromHome);

        Assert_True(_HomeDistance >= 220.0 && _HomeDistance <= 380.0, f"the drive left the crawler 220..380 cm from home (got {_HomeDistance :.1})");
        Assert_True(_Crawler.Get_Brain().Get_LeafClass() == UMars_GoapAction_Crawler_Roam, "the held leaf is Roam");
    }

    // A target on team Two (the crawler's team), tagged: the crawler reads it Friendly.
    private FMars_AutoTest_CrawlerMelee_Target SpawnTeamMate(FCk_Handle InHandle, FVector InPoint)
    {
        auto Target = FMars_AutoTest_CrawlerMelee_Target();
        Target.Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Target.Root = utils_transform::Add(Target.Entity, At(Lifted(InPoint)), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Target.Entity, ECk_Team_ID::Two, ECk_Replication::DoesNotReplicate);
        Target.Health = utils_health::Add(Target.Entity, FMars_Health_Spec(100.0f));
        Target.Zone = utils_hit_zone::Add(Target.Entity, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        Target.Hurtbox = utils_hit_zone::AddHurtbox_Box(Target.Zone, Target.Root, FMars_HitZone_Hurtbox(k_HalfExtents, FTransform::Identity));
        utils_entity_tag::Add(Target.Entity, n"TAG_MarsCombatTarget");
        return Target;
    }

    UFUNCTION()
    private void Step_SpawnPair(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Far = SpawnCombatTarget(InHandle, Lifted(_Root + _Side * 250.0), k_HalfExtents);
        _Near = SpawnCombatTarget(InHandle, Lifted(_Root + _Side * 150.0), k_HalfExtents);
        _Friendly = SpawnTeamMate(InHandle, _Root - _Side * 100.0);
        _Untagged = SpawnBystanderAt(InHandle, At(Lifted(_Root - _Side * 60.0)), k_HalfExtents);
        _Expected = _Near.Entity;
    }

    UFUNCTION()
    private void Check_ExpectedHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Watch_Ignored();
        auto Res = OutResult;
        Res.Set(_Crawler.Get_CombatTarget() == _Expected && Get_HasCombatTargetFact());
    }

    UFUNCTION()
    private void Step_BeginHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _HoldSince = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Check_HoldsExpected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Watch_Ignored();
        if (_Crawler.Get_CombatTarget() != _Expected || Get_HasCombatTargetFact() == false)
        {
            const auto Held = _Crawler.Get_CombatTarget();
            const FString HeldName = ck::IsValid(Held) ? f"{Held.ToString()}" : "none";
            FinishFailure(f"the held target changed during the hold (expected {_Expected.ToString()}, holds {HeldName}, fact {Get_HasCombatTargetFact()})");
        }

        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _HoldSince >= k_HoldSeconds);
    }

    UFUNCTION()
    private void Step_SpawnTie(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Far.Entity);
        utils_entity_lifetime::Request_DestroyEntity(_Near.Entity);

        const auto Point = Lifted(_Root + _Side * 200.0);
        _TieA = SpawnCombatTarget(InHandle, Point, k_HalfExtents);
        _TieB = SpawnCombatTarget(InHandle, Point, k_HalfExtents);
        _Expected = _TieA.Entity.ToString() < _TieB.Entity.ToString() ? _TieA.Entity : _TieB.Entity;
    }

    UFUNCTION()
    private void Check_TieChosen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Watch_Ignored();
        const auto Held = _Crawler.Get_CombatTarget();
        auto Res = OutResult;
        Res.Set(Held == _TieA.Entity || Held == _TieB.Entity);
    }

    UFUNCTION()
    private void Step_AssertTieAndHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_CombatTarget() == _Expected,
            f"(2) of two targets at one point the lower handle string wins (expected {_Expected.ToString()}, got {_Crawler.Get_CombatTarget().ToString()})");
        _HoldSince = System::GetGameTimeInSeconds();
    }

    private FMars_AutoTest_CrawlerMelee_Target Get_Chosen() const
    {
        return _Expected == _TieA.Entity ? _TieA : _TieB;
    }

    UFUNCTION()
    private void Step_MoveToRetention(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Other = _Expected == _TieA.Entity ? _TieB : _TieA;
        utils_entity_lifetime::Request_DestroyEntity(Other.Entity);

        auto Chosen = Get_Chosen();
        Move(Chosen, _Root - _AwayFromHome * 380.0);
        _HoldSince = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Step_MovePastLoseRadius(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Chosen = Get_Chosen();
        const auto Point = _Root - _AwayFromHome * 480.0;
        Assert_True((Point - _Home).Size2D() < 600.0, f"(4) the point past LoseRadius is inside HomeRadius ({(Point - _Home).Size2D() :.1} cm from home)");
        Move(Chosen, Point);
    }

    UFUNCTION()
    private void Check_TargetLost(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Watch_Ignored();
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Crawler.Get_CombatTarget()) && Get_HasCombatTargetFact() == false);
    }

    UFUNCTION()
    private void Step_BringBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Chosen = Get_Chosen();
        Move(Chosen, _Root + _AwayFromHome * 200.0);
    }

    UFUNCTION()
    private void Step_MovePastLeash(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Chosen = Get_Chosen();
        const auto Point = _Home + _AwayFromHome * 650.0;
        Assert_True((Point - _Root).Size2D() <= 450.0, f"(5) the leash point is inside LoseRadius ({(Point - _Root).Size2D() :.1} cm from the root)");
        Move(Chosen, Point);
    }

    UFUNCTION()
    private void Step_Deplete(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Health = Get_Chosen().Health;
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(100.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Step_AssertNeverIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_ChoseIgnored, "the tagged team-mate and the untagged hostile were never chosen");
        Assert_True(Get_Chosen().Health.Get_IsDepleted(), "(6) the lost target is depleted");
    }
}
