class UMars_AutoTest_CrawlerMelee_CatalogExplicitGrace : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-540000.0, -180000.0, 600.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(false);
        _Catalog.Spec.Selection.TemporaryReadiness = EMars_Attack_TemporaryReadinessPolicy::UseReadyAlternative;
        _Catalog.Spec.Selection.ReadyAlternativeDelaySeconds = 0.25f;
        // The target is about 95 cm away. Pincer is capable but temporarily TooClose; Jab is ready.
        _CatalogPincer.Def.Prepare.MinDistance = 110.0f;
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("spawn a target too close for preferred Pincer but ready for Jab", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("authored policy waits for preferred readiness before preparation", n"Check_BeforeGrace", k_SlowPolls, 0);
        Add_Step("explicit current-token fallback cannot bypass authored grace", n"Step_ExplicitJab");
        Add_Step_WaitUntil("explicit request drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step("current token alone is not permission to bypass selection", n"Step_AssertDenied");
        Add_Step("request authored preparation", n"Step_Prepare");
        Add_Step_WaitUntil("positive preparation time makes Jab the permitted alternative", n"Check_AfterGrace", k_SlowPolls, 0);
        Add_Step("explicit current-token Jab now obeys the permitted selection", n"Step_ExplicitJab");
        Add_Step_WaitUntil("the permitted explicit Jab accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("the prepared permitted alternative is admitted exactly once", n"Step_AssertAccepted");
        Add_Step_WaitUntil("the Jab ends", n"Check_AttackFinished", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_BeforeGrace(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = _Crawler.Get_AttackEvaluation();
        auto Res = OutResult;
        Res.Set(Advice.Selection.Preferred.IsSet() && Advice.Selection.Preferred.GetValue() == GameplayTags::Attack_Mars_Pincer &&
            Advice.Selection.ReadyChoice.IsSet() && Advice.Selection.ReadyChoice.GetValue() == GameplayTags::Attack_Mars_Jab && Advice.Selection.Selected.IsSet() == false);
    }

    UFUNCTION()
    private void Step_ExplicitJab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RecordMark = _Records.Num();
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity, GameplayTags::Attack_Mars_Jab, _Crawler.Get_AttackEvaluation().SelectionGeneration));
    }

    UFUNCTION()
    private void Step_AssertDenied(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Reject = _Crawler.Get_AttackLastReject();
        Assert_True(Reject.IsSet() && Reject.GetValue() == EMars_Crawler_AttackReject::SelectionNotPermitted,
            "ready explicit Jab with a current token still rejects before authored preparation grace");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle &&
            _Crawler.Get_AttackActionIdentity().Get_Value() == 0,
            "policy denial creates no native action");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 0, "policy denial emits no admission");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "policy denial emits no damage");
    }

    UFUNCTION()
    private void Step_Prepare(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Crawler.Request_PrepareAttack(FMars_Request_Crawler_PrepareAttack(_Target.Entity, ECk_EnableDisable::Enable)); }

    UFUNCTION()
    private void Check_AfterGrace(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = _Crawler.Get_AttackEvaluation();
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPreparation().ElapsedReadinessWait >= 0.25f &&
            Advice.Selection.Selected.IsSet() && Advice.Selection.Selected.GetValue() == GameplayTags::Attack_Mars_Jab);
    }

    UFUNCTION()
    private void Step_AssertAccepted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackId() == GameplayTags::Attack_Mars_Jab && Get_CatalogLastStart(GameplayTags::Attack_Mars_Jab) == 1,
            "the explicit permitted fallback receives the first accepted admission sequence");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "only the post-grace request admits");
    }
}
