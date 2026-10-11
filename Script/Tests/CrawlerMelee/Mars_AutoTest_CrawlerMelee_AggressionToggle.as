// An armed crawler chooses targets only while aggressive. It spawns passive (StartAggressive = Disable):
//   1. with a valid tagged hostile target in range it selects nothing for 2 s, and its HasCombatTarget fact stays false;
//   2. switched on (Request_SetAggression(Enable)) it acquires that target on a later scan, and the fact turns true;
//   3. switched off during an attack's Windup, the attack is cancelled as Disabled (straight to Cooldown), the combat
//      target is cleared and the fact turns false, with no damage request;
//   4. switched on again, it acquires the target again.
class UMars_AutoTest_CrawlerMelee_AggressionToggle : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 50.0f;
    default _Origin = FVector(-280000.0, -150000.0, 600.0);

    private float64 _PassiveSince = 0.0;
    private bool _EverSelectedWhilePassive = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_ArmedCrawlerSpec(4);
        Spec.Combat.StartAggressive = ECk_EnableDisable::Disable;
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("hold the behaviour in Roam (brain off): an aggressive crawler with a target would engage, and this test starts the attack itself", n"Step_HoldBehaviour");
        Add_Step("spawn a valid tagged target in range", n"Step_SpawnTarget");
        Add_Step_WaitUntil("(1) watch the passive crawler for 2 s", n"Check_PassiveForTwoSeconds", k_SlowPolls, 0);
        Add_Step("(1) the passive crawler selected nothing; switch aggression on", n"Step_AssertPassiveAndEnable");
        Add_Step_WaitUntil("(2) the crawler acquires the target and its fact turns true", n"Check_Acquired", k_SlowPolls, 0);
        Add_Step("(3) request one attack at the acquired target", n"Step_Start");
        Add_Step_WaitUntil("(3) the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("(3) switch aggression off during Windup", n"Step_Disable");
        Add_Step_WaitUntil("(3) the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("(3) the cleared target's fact turns false", n"Check_FactFalse", k_SlowPolls, 0);
        Add_Step("(3) the attack was cancelled as Disabled and the target cleared; switch aggression on again", n"Step_AssertDisabledAndEnable");
        Add_Step_WaitUntil("(4) the crawler acquires the target again", n"Check_Acquired", k_SlowPolls, 0);
        Add_Step("(4) the target is re-acquired", n"Step_AssertReacquired");
        Run_Steps(InHandle);
    }

    // The disabled planner keeps its Roam leaf; facts are still written.
    UFUNCTION()
    private void Step_HoldBehaviour(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Brain = _Crawler.Get_Brain();
        Brain.Request_SetEnabled(FMars_Request_Brain_SetEnabled(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));
        _PassiveSince = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Check_PassiveForTwoSeconds(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::IsValid(_Crawler.Get_CombatTarget()) || Get_HasCombatTargetFact())
        { _EverSelectedWhilePassive = true; }

        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _PassiveSince >= 2.0);
    }

    UFUNCTION()
    private void Step_AssertPassiveAndEnable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_IsCombatArmed(), "(1) the crawler is armed");
        Assert_False(_Crawler.Get_IsAggressive(), "(1) the crawler starts passive");
        Assert_False(_EverSelectedWhilePassive, "(1) the passive crawler never selected a target nor set HasCombatTarget");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle, "(1) no attack ran");

        _Crawler.Request_SetAggression(FMars_Request_Crawler_SetAggression(ECk_EnableDisable::Enable));
    }

    UFUNCTION()
    private void Check_Acquired(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_IsAggressive() && _Crawler.Get_CombatTarget() == _Target.Entity && Get_HasCombatTargetFact());
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RecordMark = _Records.Num();
        _AdmissionPolls = 0;
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
    }

    UFUNCTION()
    private void Step_Disable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Windup, f"(3) aggression is switched off during Windup (phase {_Crawler.Get_AttackPhase() :n})");
        _Crawler.Request_SetAggression(FMars_Request_Crawler_SetAggression(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Check_FactFalse(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasCombatTargetFact() == false);
    }

    UFUNCTION()
    private void Step_AssertDisabledAndEnable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::Disabled,
            f"(3) the attack was cancelled as Disabled (last cancel {Get_LastCancelText()}, phases{Get_PhaseText(_RecordMark)})");
        Assert_True(Find_RecordSinceMark(EMars_Crawler_AttackPhase::CancelRecover) < 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown) >= 0,
            f"(3) Disabled went straight to Cooldown (phases{Get_PhaseText(_RecordMark)})");
        Assert_False(_Crawler.Get_IsAggressive(), "(3) the crawler is passive");
        Assert_True(ck::Is_NOT_Valid(_Crawler.Get_CombatTarget()), "(3) the combat target was cleared");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "(3) no damage request was sent");
        Assert_Equals_Float(_Target.Health.Get_Current(), 100.0f, 0.01f, "(3) the target is untouched");

        _Crawler.Request_SetAggression(FMars_Request_Crawler_SetAggression(ECk_EnableDisable::Enable));
    }

    UFUNCTION()
    private void Step_AssertReacquired(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_CombatTarget() == _Target.Entity, "(4) the target was re-acquired");
        Assert_True(Get_HasCombatTargetFact(), "(4) HasCombatTarget is true again");
    }
}
