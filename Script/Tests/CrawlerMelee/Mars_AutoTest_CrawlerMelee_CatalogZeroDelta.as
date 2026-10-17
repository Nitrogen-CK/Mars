class UMars_AutoTest_CrawlerMelee_CatalogZeroDelta : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-510000.0, -180000.0, 600.0);

    UPROPERTY() private UMars_Processor_Crawler_HandleRequests _Requests;
    UPROPERTY() private UMars_Processor_Crawler_AttackTick _Tick;
    private int32 _DamageAtCancel = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(false);
        _CatalogPincer.Def.Cooldown.ReuseSeconds = 5.0f;
        _Requests = Cast<UMars_Processor_Crawler_HandleRequests>(NewObject(this, UMars_Processor_Crawler_HandleRequests));
        _Tick = Cast<UMars_Processor_Crawler_AttackTick>(NewObject(this, UMars_Processor_Crawler_AttackTick));
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("spawn a reachable target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step("request authored preparation", n"Step_Prepare");
        Add_Step_WaitUntil("preparation has advanced on a positive world tick", n"Check_Preparation", k_SlowPolls, 0);
        Add_Step("zero delta does not advance authored readiness wait", n"Step_ZeroPreparation");
        Add_Step_WaitUntil("fresh advice permits a pincer before its one start", n"Check_CatalogPincerReady", k_SlowPolls, 0);
        Add_Step("start a pincer", n"Step_TargetAndStart");
        Add_Step_WaitUntil("a real offensive admission accepts", n"Check_OffensiveAccepted", k_SlowPolls, 0);
        Add_Step("transport cancellation and invoke the owning attack kernel with actual zero delta", n"Step_ZeroCancel");
        Add_Step_WaitUntil("native return reaches positive global cooldown", n"Check_InCooldown", k_SlowPolls, 0);
        Add_Step("actual zero delta preserves a positive global cooldown", n"Step_ZeroCooldown");
        Add_Step_WaitUntil("normal positive ticks complete native return and game cleanup", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("claw controls are returned", n"Check_CatalogClawsReturned", k_SlowPolls, 0);
        Add_Step("C08 one accepted cancelled identity retains its exact result and costs", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Prepare(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Crawler.Request_PrepareAttack(FMars_Request_Crawler_PrepareAttack(_Target.Entity)); }

    UFUNCTION()
    private void Check_Preparation(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Preparation = _Crawler.Get_AttackPreparation();
        auto Res = OutResult;
        Res.Set(Preparation.Active && Preparation.ElapsedReadinessWait > 0.0f);
    }

    UFUNCTION()
    private void Step_ZeroPreparation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Before = _Crawler.Get_AttackPreparation();
        FCk_Handle Entity = _Crawler;
        _Tick.ForEachEntity(FCk_Time(0.0), Entity);
        const auto After = _Crawler.Get_AttackPreparation();
        Assert_True(Before.Active && After.Active && Before.ElapsedReadinessWait == After.ElapsedReadinessWait,
            "real zero-delta production invocation preserves the preparation clock");
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
    private void Step_ZeroCancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Id = _Crawler.Get_AttackId();
        const auto Reuse = Get_CatalogReuseRemaining(Id);
        const auto Sequence = Get_CatalogLastStart(Id);
        const auto Global = _Crawler.Get_AttackCooldownRemaining();
        const auto Cleanup = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack).Cleanup.Elapsed;
        _DamageAtCancel = utils_mars_test_catalog::Get_IssuedDamageRequests(_Crawler);
        _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));
        // The real request owner receives a local read-copy; the fixture never edits a production fragment.
        FMars_Fragment_Crawler_Requests Requests = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Requests);
        FCk_Handle Entity = _Crawler;
        _Requests.ForEachEntity(FCk_Time(0.0), Entity, Requests);
        _Tick.ForEachEntity(FCk_Time(0.0), Entity);
        _Tick.ForEachEntity(FCk_Time(0.0), Entity);
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::CancelRecover &&
            _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack).WindowClosed &&
            _Crawler.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Candidate.IsSet() == false,
            "zero time still transports cancellation, closes damage and discards candidate evidence");
        Assert_True(Reuse > 0.0f && Get_CatalogReuseRemaining(Id) == Reuse && Get_CatalogLastStart(Id) == Sequence && Sequence > 0,
            "zero-time cancellation neither advances reuse nor charges a second admission");
        Assert_True(_Crawler.Get_AttackCooldownRemaining() == Global &&
            _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack).Cleanup.Elapsed == Cleanup,
            "global recovery and autonomous cleanup clocks do not advance at zero delta");
        Assert_Equals_Int(utils_mars_test_catalog::Get_IssuedDamageRequests(_Crawler), _DamageAtCancel, "zero-time cancellation emits no damage");
    }

    UFUNCTION()
    private void Step_ZeroCooldown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Before = _Crawler.Get_AttackCooldownRemaining();
        const auto Reuse = Get_CatalogReuseRemaining(_Crawler.Get_AttackId());
        FCk_Handle Entity = _Crawler;
        _Tick.ForEachEntity(FCk_Time(0.0), Entity);
        Assert_True(Before > 0.0f && _Crawler.Get_AttackCooldownRemaining() == Before &&
            Get_CatalogReuseRemaining(_Crawler.Get_AttackId()) == Reuse,
            "a real positive global recovery countdown and entry reuse are unchanged by zero delta");
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "the accepted cancelled attempt publishes exactly one admission");
        Assert_Equals_Int(_CatalogResults.Num(), 1, "the accepted cancelled attempt publishes exactly one terminal result");
        Assert_Equals_Int(utils_mars_test_catalog::Get_IssuedDamageRequests(_Crawler), _DamageAtCancel, "no additional request follows closed cancellation");
        Assert_True(_CatalogResults.Num() == 1 && _CatalogResults[0].Accepted &&
            _CatalogResults[0].Native.Get_Outcome() == ECk_ProceduralAction_Outcome::Cancelled,
            "the accepted cancellation remains a native cancelled result after public cleanup");
    }
}
