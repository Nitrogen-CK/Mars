// Losing only the jab's action entity must close offense immediately while the crawler and player survive. The observer
// drains the action's retained identity stream through terminal acknowledgement before another jab is admitted.
class UMars_AutoTest_CrawlerMelee_ActionScopeLoss : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-280000.0, -210000.0, 600.0);

    private int64 _LostIdentity = 0;
    private int32 _LostGeneration = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));
        Add_SettleSteps();
        Add_Step("spawn a target beyond the jab's reach", n"Step_SpawnTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("start the first jab", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the first jab enters Windup", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step_WaitUntil("the clip action is playing and a sample was accepted", n"Check_ActionSampling", k_SlowPolls, 0);
        Add_Step("destroy only the jab's action entity", n"Step_DestroyAction");
        Add_Step_WaitUntil("the lost action drains and the crawler returns to Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("verify the terminal was observed and acknowledged without a hit", n"Step_AssertScopeLossDrained");
        Add_Step("start another jab using the same live crawler and player", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the second jab enters Windup", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("verify a fresh action was admitted", n"Step_AssertFreshAdmission");
        Add_Step_WaitUntil("the second jab finishes", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("verify the second terminal was acknowledged", n"Step_AssertSecondDrained");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 55.0, FVector(10.0, 20.0, 20.0));
    }

    UFUNCTION()
    private void Check_ActionSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        // The jab is a clip action that plays on its own (Playing), not a manual action awaiting samples.
        const auto Action = _Crawler.Get_AttackAction();
        auto Res = OutResult;
        Res.Set(ck::IsValid(Action) && Action.Get_State() == ECk_ProceduralAction_State::Playing &&
            _Crawler.Get_AttackAcknowledgedSampleId() != 0);
    }

    UFUNCTION()
    private void Step_DestroyAction(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Action = _Crawler.Get_AttackAction();
        Assert_True(ck::IsValid(_Crawler) && ck::IsValid(_Crawler.Get_ActionPlayer()) && ck::IsValid(Action),
            "the crawler, player and action exist before the injected loss");
        _LostIdentity = _Crawler.Get_AttackActionIdentity().Get_Value();
        _LostGeneration = _Crawler.Get_AttackGeneration();
        utils_entity_lifetime::Request_DestroyEntity(Action);
    }

    UFUNCTION()
    private void Step_AssertScopeLossDrained(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Crawler) && ck::IsValid(_Crawler.Get_ActionPlayer()),
            "the crawler and player survived loss of the action");
        Assert_True(_Crawler.Get_AttackWindowClosed() && _Crawler.Get_AttackTerminalSeen(),
            "offense closed and the lost action's terminal was observed");
        Assert_True(ck::Is_NOT_Valid(_Crawler.Get_AttackAction()) && _Crawler.Get_AttackActionIdentity().Get_Value() == 0,
            "the lost action no longer owns control");
        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        Assert_True(LastCancel.IsSet() && LastCancel.GetValue() == EMars_Crawler_AttackCancel::PoseFailed,
            "losing the action ended the first jab as PoseFailed");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "the lost jab emitted no damage request");
    }

    UFUNCTION()
    private void Step_AssertFreshAdmission(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Crawler.Get_AttackAction()) && _Crawler.Get_AttackActionIdentity().Get_Value() != _LostIdentity &&
            _Crawler.Get_AttackGeneration() > _LostGeneration,
            "the next jab admitted a fresh action identity and generation");
        Assert_True(_Crawler.Get_AttackWindowClosed() == false && _Crawler.Get_AttackTerminalSeen() == false,
            "terminal and offense state from the lost action did not cross admission");
    }

    UFUNCTION()
    private void Step_AssertSecondDrained(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackTerminalSeen() && ck::Is_NOT_Valid(_Crawler.Get_AttackAction()),
            "the second jab also observed its own terminal and its action released itself");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "neither out-of-reach jab emitted a damage request");
    }
}
