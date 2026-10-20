// Crawlers that must not engage do not:
//   1. an unarmed crawler (Combat.Enabled false) beside a tagged hostile for 2 s: it carries no Engage state, holds no
//      combat target, its plan stays [Roam] and its behaviour stays in Roam;
//   2. a passive armed crawler beside a tagged hostile for 2 s: it selects nothing, HasCombatTarget stays false, Roam holds
//      and Engage never begins; given the target explicitly it holds it, yet the fact stays false and Roam holds for 1 s;
//      told to attack directly, it still attacks (Windup through Idle).
// The lane's world is a listen server (the automation PIE net mode), which the local-session fence admits; the trace
// line records it. That makes this a scope fence, not multiplayer proof: no client world is staged.
class UMars_AutoTest_CrawlerMelee_PassiveAndNetworkGate : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-200000.0, -180000.0, 600.0);

    private const FVector k_SecondCrawlerOffset = FVector(0.0, 5000.0, 0.0);
    private const FVector k_HalfExtents = FVector(10.0, 20.0, 20.0);

    private float64 _WatchSince = 0.0;
    private FString _Violation = "";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Unarmed = Make_ArmedCrawlerSpec(4);
        Unarmed.Combat.Enabled = false;
        SpawnFloorAndCrawler(InHandle, Unarmed);

        Add_SettleSteps();
        Add_Step("(1) spawn a tagged hostile 200 cm ahead of the unarmed crawler", n"Step_SpawnTargetAndWatch");
        Add_Step_WaitUntil("(1) watch the unarmed crawler for 2 s", n"Check_StaysOutForTwoSeconds", k_SlowPolls, 0);
        Add_Step("(1) the unarmed crawler never engaged", n"Step_AssertUnarmed");

        Add_Step("(2) spawn a passive armed crawler on its own floor", n"Step_SpawnPassiveCrawler");
        Add_SettleSteps();
        Add_Step("(2) spawn a tagged hostile ahead of the passive crawler", n"Step_SpawnTargetAndWatch");
        Add_Step_WaitUntil("(2) watch the passive crawler for 2 s", n"Check_StaysOutForTwoSeconds", k_SlowPolls, 0);
        Add_Step("(2) it selected nothing; give it the target explicitly", n"Step_AssertPassiveAndSetTarget");
        Add_Step_WaitUntil("(2) it holds the explicit target", n"Check_TargetAcquired", k_SlowPolls, 0);
        Add_Step("(2) keep watching", n"Step_RestartWatch");
        Add_Step_WaitUntil("(2) the fact stays false and Roam holds for 1 s", n"Check_StaysOutForOneSecond", k_SlowPolls, 0);
        Add_Step("(2) request one attack directly", n"Step_DirectStart");
        Add_Step_WaitUntil("(2) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("(2) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("(2) it attacked once, and its behaviour never engaged", n"Step_AssertPassiveAttacked");
        Run_Steps(InHandle);
    }

    private FString Get_NetModeText() const
    {
        auto CrawlerWorld = utils_entity_lifetime::Get_WorldForEntity(_Crawler);
        if (ck::Is_NOT_Valid(CrawlerWorld))
        { return "no world"; }

        const auto Mode = CrawlerWorld.GetNetMode();
        if (Mode == ENetMode::NM_Standalone)
        { return "NM_Standalone"; }

        if (Mode == ENetMode::NM_ListenServer)
        { return "NM_ListenServer"; }

        if (Mode == ENetMode::NM_DedicatedServer)
        { return "NM_DedicatedServer"; }

        return "NM_Client";
    }

    // Anything that would mean the crawler's behaviour engaged; empty when nothing did.
    private FString Get_EngageEvidence() const
    {
        if (_Crawler.Get_EngageStage() != EMars_Crawler_EngageStage::None)
        { return f"Engage stage {_Crawler.Get_EngageStage() :n}"; }

        if (_Crawler.Get_Brain().Get_LeafClass() != UMars_GoapAction_Crawler_Roam)
        { return f"leaf {utils_brain::Get_ClassName(_Crawler.Get_Brain().Get_LeafClass())}"; }

        if (_Crawler.Get_BehaviorStateClass() != UMars_SmState_Crawler_Roam)
        { return "behaviour left Roam"; }

        if (Get_HasCombatTargetFact())
        { return "HasCombatTarget is true"; }

        return "";
    }

    private void Watch(float64 InSeconds, FCk_SharedBool OutResult)
    {
        const auto Evidence = Get_EngageEvidence();
        if (Evidence.Len() > 0 && _Violation.Len() == 0)
        { _Violation = Evidence; }

        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _WatchSince >= InSeconds);
    }

    UFUNCTION()
    private void Step_SpawnTargetAndWatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, k_HalfExtents);
        _WatchSince = System::GetGameTimeInSeconds();
        _Violation = "";
    }

    UFUNCTION()
    private void Step_RestartWatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WatchSince = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Check_StaysOutForTwoSeconds(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::IsValid(_Crawler.Get_CombatTarget()) && _Violation.Len() == 0)
        { _Violation = "a combat target was selected"; }

        Watch(2.0, OutResult);
    }

    UFUNCTION()
    private void Check_StaysOutForOneSecond(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Watch(1.0, OutResult);
    }

    UFUNCTION()
    private void Step_AssertUnarmed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        ck::Trace(f"[CrawlerMelee] passive and network gate: world net mode={Get_NetModeText()}");

        Assert_False(_Crawler.Get_IsCombatArmed(), "(1) the crawler is unarmed");
        Assert_False(_Crawler.Has_Fragment(FMars_Fragment_Crawler_EngageBlackboard), "(1) the unarmed crawler carries no Engage state");
        Assert_True(_Violation.Len() == 0, f"(1) the unarmed crawler never engaged ({_Violation})");
    }

    UFUNCTION()
    private void Step_SpawnPassiveCrawler(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Origin = _Origin + k_SecondCrawlerOffset;
        _Crawler = FCk_Handle_Crawler();
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));
    }

    UFUNCTION()
    private void Step_AssertPassiveAndSetTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        ck::Trace(f"[CrawlerMelee] passive and network gate: world net mode={Get_NetModeText()}");

        Assert_True(_Crawler.Get_IsCombatArmed(), "(2) the crawler is armed (the local-session fence admits this world)");
        Assert_False(_Crawler.Get_IsAggressive(), "(2) the crawler is passive");
        Assert_True(_Violation.Len() == 0, f"(2) the passive crawler selected nothing and never engaged ({_Violation})");

        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Target.Entity));
    }

    UFUNCTION()
    private void Step_DirectStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Violation.Len() == 0, f"(2) with an explicit target the fact stayed false and Roam held ({_Violation})");

        _RecordMark = _Records.Num();
        _AdmissionPolls = 0;
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
    }

    UFUNCTION()
    private void Step_AssertPassiveAttacked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phases = Get_PhasesSinceMark();
        Assert_True(Phases.Num() == 5 && Phases[0] == EMars_Crawler_AttackPhase::Windup && Phases[4] == EMars_Crawler_AttackPhase::Idle,
            f"(2) the direct attack ran Windup through Idle (phases{Get_PhaseText(_RecordMark)})");

        const auto Evidence = Get_EngageEvidence();
        Assert_True(Evidence.Len() == 0, f"(2) the behaviour never engaged ({Evidence})");
    }
}
