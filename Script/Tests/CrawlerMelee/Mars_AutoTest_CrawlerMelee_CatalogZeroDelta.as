// A cancel and a start issued in the same frame, against an accepted pincer: one drain carries both, the cancel wins
// (the start is rejected as CancelPending, never a second admission), offense closes and the candidate evidence is
// dropped on the next real tick, and the accepted attempt keeps exactly one admission, one cancelled native result and
// the one reuse charge its admission made. The clocks' zero-delta rule (no readiness, reuse, recovery or cleanup clock
// moves without positive time) is a pure function test: Mars_AutoTest_CrawlerMelee_ZeroDeltaClocksHold. A world tick
// never carries a zero delta (time dilation clamps to MinGlobalTimeDilation).
class UMars_AutoTest_CrawlerMelee_CatalogZeroDelta : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-510000.0, -180000.0, 600.0);

    private int32 _DamageAtCancel = 0;
    private int64 _StartAtCancel = 0;
    private int64 _CancelMark = 0;
    private FGameplayTag _AttackId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(false);
        _CatalogPincer.Def.Cooldown.ReuseSeconds = 5.0f;
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("spawn a reachable target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step("request authored preparation", n"Step_Prepare");
        Add_Step_WaitUntil("preparation has advanced on a positive world tick", n"Check_Preparation", k_SlowPolls, 0);
        Add_Step_WaitUntil("fresh advice permits a pincer before its one start", n"Check_CatalogPincerReady", k_SlowPolls, 0);
        Add_Step("start a pincer", n"Step_TargetAndStart");
        Add_Step_WaitUntil("a real offensive admission accepts", n"Check_OffensiveAccepted", k_SlowPolls, 0);
        Add_Step("cancel and start again in the same frame", n"Step_CancelAndStart");
        Add_Step_WaitUntil("the cancel drained and the attack recorded it", n"Check_CancelTransported", k_SlowPolls, 0);
        Add_Step("the cancel won the drain: offense closed, the start rejected, nothing charged twice", n"Step_AssertCancel");
        Add_Step_WaitUntil("native return reaches the global cooldown", n"Check_InCooldown", k_SlowPolls, 0);
        Add_Step_WaitUntil("normal positive ticks complete native return and game cleanup", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("claw controls are returned", n"Check_CatalogClawsReturned", k_SlowPolls, 0);
        Add_Step("one accepted cancelled identity retains its exact result and costs", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Prepare(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_PrepareAttack(FMars_Request_Crawler_PrepareAttack(_Target.Entity, ECk_EnableDisable::Enable));
    }

    UFUNCTION()
    private void Check_Preparation(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Preparation = _Crawler.Get_AttackPreparation();
        auto Res = OutResult;
        Res.Set(Preparation.State == EMars_Attack_PreparationState::Active && Preparation.ElapsedReadinessWait > 0.0f);
    }

    UFUNCTION()
    private void Check_OffensiveAccepted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Check_CatalogAccepted(InHandle, OutResult, InPayload);
        const auto Phase = _Crawler.Get_AttackPhase();
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackAdmission().Accepted &&
            (Phase == EMars_Crawler_AttackPhase::Windup || Phase == EMars_Crawler_AttackPhase::Strike));
    }

    UFUNCTION()
    private void Step_CancelAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _AttackId = _Crawler.Get_AttackId();
        _StartAtCancel = Get_CatalogLastStart(_AttackId);
        _DamageAtCancel = _Crawler.Get_IssuedDamageRequests();
        _CancelMark = Get_HistorySequence();
        _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
    }

    UFUNCTION()
    private void Check_CancelTransported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Cancelled = false;
        for (const auto& Entry : _Crawler.Get_AttackHistory())
        { Cancelled = Cancelled || (Entry.Sequence > _CancelMark && Entry.Event == n"Cancelled"); }

        auto Res = OutResult;
        Res.Set(_Crawler.Get_HasPendingCombatRequests() == false && Cancelled);
    }

    UFUNCTION()
    private void Step_AssertCancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Reject = _Crawler.Get_AttackLastReject();
        Assert_True(Reject.IsSet() && Reject.GetValue() == EMars_Crawler_AttackReject::CancelPending,
            f"the start drained beside the cancel was rejected as CancelPending (last reject {Get_LastRejectText()})");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::CancelRecover &&
            _Crawler.Get_AttackWindowClosed() && _Crawler.Get_AttackCandidatePending() == false,
            "the cancel closed damage and discarded candidate evidence on its drain's tick");
        Assert_True(_StartAtCancel > 0 && Get_CatalogLastStart(_AttackId) == _StartAtCancel && Get_CatalogReuseRemaining(_AttackId) > 0.0f,
            "the accepted attempt's one reuse charge stands and no second admission was charged");
        Assert_Equals_Int(_Crawler.Get_IssuedDamageRequests(), _DamageAtCancel, "the cancellation emitted no damage");
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "the accepted cancelled attempt publishes exactly one admission");
        Assert_Equals_Int(_CatalogResults.Num(), 1, "the accepted cancelled attempt publishes exactly one terminal result");
        Assert_Equals_Int(_Crawler.Get_IssuedDamageRequests(), _DamageAtCancel, "no additional request follows closed cancellation");
        Assert_True(_CatalogResults.Num() == 1 && _CatalogResults[0].Accepted &&
            _CatalogResults[0].Native.Get_Outcome() == ECk_ProceduralAction_Outcome::Cancelled,
            "the accepted cancellation remains a native cancelled result after public cleanup");
    }
}
