class UMars_AutoTest_CrawlerMelee_CatalogLeastRecent : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 120.0f;
    default _Origin = FVector(-520000.0, -180000.0, 600.0);

    private int32 _Attempt = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(true);
        // Both equal-ranked candidates use body motion; Pincer remains a lower-priority capable option.
        auto Entries = _Catalog.Spec.Entries;
        Entries[1].Priority = 200;
        _Catalog.Spec.Entries = Entries;
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("spawn a reachable target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        for (int32 Index = 0; Index < 3; ++Index)
        {
            Add_Step_WaitUntil("expected least-recent body entry is ready", n"Check_ExpectedAdvice", k_SlowPolls, 0);
            Add_Step("queue one automatic attack", n"Step_TargetAndStart");
            Add_Step_WaitUntil("this automatic attack actually accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
            Add_Step("C09 accepted sequence drives deterministic equal-priority choice", n"Step_InspectAdmission");
            Add_Step_WaitUntil("the committed attempt finishes", n"Check_AttackFinished", k_SlowPolls, 0);
            Add_Step("advance the expected attempt", n"Step_NextAttempt");
        }
        Add_Step("three admissions and results describe three distinct attempts", n"Step_Assert");
        Run_Steps(InHandle);
    }

    // Equal priority: the canonical tag order (Attack.Mars.Jab before Attack.Mars.Test.Fourth) decides the first start,
    // the least recently accepted start every one after.
    private FGameplayTag Expected_Id() const
    { return _Attempt == 1 ? GameplayTags::Attack_Mars_Test_Fourth : GameplayTags::Attack_Mars_Jab; }

    UFUNCTION()
    private void Check_ExpectedAdvice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
        auto Res = OutResult;
        Res.Set(Advice.Selection.Selected.IsSet() && Advice.Selection.Selected.GetValue() == Expected_Id());
    }

    UFUNCTION()
    private void Step_InspectAdmission(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackId() == Expected_Id(),
            "equal priority uses canonical tag order initially and the least-recent accepted start thereafter");
        Assert_True(Get_CatalogLastStart(Expected_Id()) == int64(_Attempt + 1),
            "one real first accepted receipt advances the shared start sequence exactly once");
        Assert_Equals_Int(_CatalogAdmissions.Num(), _Attempt + 1, "one admission signal belongs to each accepted attempt");
        Assert_True(_Crawler.Get_AttackPlan().Entry.Slots.Num() == 0, "the test's selected candidates claim no animated limb slots");
    }

    UFUNCTION()
    private void Step_NextAttempt(FCk_Handle InHandle, FInstancedStruct InPayload)
    { ++_Attempt; }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CatalogAdmissions.Num(), 3, "three automatic accepted starts were recorded");
        Assert_Equals_Int(_CatalogResults.Num(), 3, "three completed game results were recorded");
        Assert_True(Get_CatalogLastStart(GameplayTags::Attack_Mars_Jab) == 3 && Get_CatalogLastStart(GameplayTags::Attack_Mars_Test_Fourth) == 2 &&
            Get_CatalogLastStart(GameplayTags::Attack_Mars_Pincer) == 0, "only accepted selected entries change recency");
        for (int32 Index = 1; Index < _CatalogAdmissions.Num(); ++Index)
        {
            Assert_True(_CatalogAdmissions[Index].ActionIdentity.Get_Value() != _CatalogAdmissions[Index - 1].ActionIdentity.Get_Value(),
                "automatic repeats produce distinct native identities");
        }
    }
}
