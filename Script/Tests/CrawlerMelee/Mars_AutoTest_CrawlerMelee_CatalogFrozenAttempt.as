class UMars_AutoTest_CrawlerMelee_CatalogFrozenAttempt : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 120.0f;
    default _Origin = FVector(-440000.0, -180000.0, 600.0);

    private float64 _OriginalDuration = 0.0;
    private FCk_Handle _OldCrawler;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_CatalogSpec(false));
        Add_CatalogSettleSteps();
        Add_Step("spawn an original 15 HP target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("the target's body is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the original target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("original target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("fresh advice permits the original pincer", n"Check_CatalogPincerReady", k_SlowPolls, 0);
        Add_Step("start a frozen authored pincer", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the pincer accepts a real receipt", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("edit source definition, loadout and clip; collect garbage during the attempt", n"Step_EditSourcesAndCollect");
        Add_Step_WaitUntil("the original attempt finishes", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the original claws return", n"Check_CatalogClawsReturned", k_SlowPolls, 0);
        Add_Step("the committed attack retained its original values and motion", n"Step_AssertFrozen");
        Add_Step("destroy the old crawler without touching its shared authored assets", n"Step_DestroyOld");
        Add_Step_WaitUntil("the old crawler is destroyed", n"Check_OldDestroyed", k_SlowPolls, 0);
        Add_Step("reconstruct a crawler from the edited authored sources", n"Step_Reconstruct");
        Add_CatalogSettleSteps();
        Add_Step("spawn a fresh target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("the new target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the reconstructed target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("reconstructed target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("fresh advice permits the reconstructed pincer", n"Check_CatalogPincerReady", k_SlowPolls, 0);
        Add_Step("start the new reconstructed pincer", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the new source values are accepted", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("reconstruction exposes new valid values", n"Step_AssertReconstructedPlan");
        Add_Step_WaitUntil("the edited pincer completes", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("the reconstructed target receives the edited damage", n"Step_AssertReconstructedDamage");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_EditSourcesAndCollect(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Plan = _Crawler.Get_AttackPlan();
        _OriginalDuration = utils_crawler::Get_ClipSeconds(_Crawler.Get_AttackFrozenPlayedClip());
        Assert_True(_Crawler.Get_AttackFrozenPlayedClip() != _CatalogPincerSource && Plan.Entry.Definition.Hit.Damage == 15.0f,
            "the active plan owns a separate frozen clip and original 15 HP policy");
        _CatalogPincer.Def.Hit.Damage = 30.0f;
        _CatalogPincer.Def.Cooldown.ReuseSeconds = 4.0f;
        _Catalog.Spec.Entries[0].Priority = 200;
        auto Draft = Make_DraftOf(_CatalogPincerSource);
        auto Phases = Draft.Get_Phases();
        for (auto& Phase : Phases)
        { Phase.Set_Duration(FCk_Time(Phase.Get_Duration().Get_Seconds() * 2.0)); }
        Draft.Set_Phases(Phases);
        const auto Report = utils_procedural_action_builder::Build_Into(Draft, _CatalogPincerSource);
        Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid, "the deliberately edited source clip compiles");
        auto Locomotion = _Catalog.Spec.Execution.Locomotion;
        auto Support = Locomotion.Get_Support();
        Support.Set_SupportHoldTimeout(FCk_Time(_OriginalDuration * 2.0 +
            _Catalog.Spec.Execution.Tuning.Get_Transition().Get_DedicatedReturn().Get_Seconds()));
        Locomotion.Set_Support(Support);
        _Catalog.Spec.Execution.Locomotion = Locomotion;
        System::CollectGarbage();
        const auto Frozen = _Crawler.Get_AttackPlan();
        Assert_True(Frozen.Entry.Definition.Hit.Damage == 15.0f && Frozen.Entry.Identity.Priority == 100 &&
            Frozen.Entry.Definition.Cooldown.ReuseSeconds == 0.0f,
            "definition/loadout edits and GC cannot change the committed policy");
        Assert_True(ck::IsValid(_Crawler.Get_AttackFrozenPlayedClip()) &&
            Math::Abs(utils_crawler::Get_ClipSeconds(_Crawler.Get_AttackFrozenPlayedClip()) - _OriginalDuration) < 1.0e-6,
            "the entity's pinned frozen clip survives GC with its original duration");
    }

    UFUNCTION()
    private void Step_AssertFrozen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "the active frozen attack still dealt only its original 15 HP");
        Assert_True(Math::Abs(_Crawler.Get_AttackAcceptedInterval().Get_ToTime().Get_Seconds() - _OriginalDuration) < 1.0e-4,
            "actual accepted motion ended at the original frozen clip time");
        Assert_True(_CatalogResults.Num() == 1 && _CatalogResults[0].Native.Get_Outcome() == ECk_ProceduralAction_Outcome::Completed,
            "source edits did not interrupt or replace the committed attempt");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the frozen attempt retained its one-hit ledger");
    }

    UFUNCTION()
    private void Step_DestroyOld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _OldCrawler = _Crawler;
        utils_entity_lifetime::Request_DestroyEntity(_OldCrawler);
        utils_entity_lifetime::Request_DestroyEntity(_Target.Entity);
    }

    UFUNCTION()
    private void Check_OldDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_OldCrawler));
    }

    UFUNCTION()
    private void Step_Reconstruct(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CatalogAdmissions.Reset();
        _CatalogResults.Reset();
        Spawn_CatalogCrawlerOnly(InHandle, _CatalogSpec);
    }

    UFUNCTION()
    private void Step_AssertReconstructedPlan(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Plan = _Crawler.Get_AttackPlan();
        Assert_True(Plan.Entry.Definition.Hit.Damage == 30.0f && Plan.Entry.Identity.Priority == 200 &&
            Plan.Entry.Definition.Cooldown.ReuseSeconds == 4.0f, "reconstruction sees the edited definition and loadout values");
        Assert_True(Math::Abs(utils_crawler::Get_ClipSeconds(_Crawler.Get_AttackFrozenPlayedClip()) - _OriginalDuration * 2.0) < 1.0e-6,
            "reconstruction sees the new source clip in another frozen copy");
    }

    UFUNCTION()
    private void Step_AssertReconstructedDamage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Target.Health.Get_Current(), 70.0f, 0.01f, "the reconstructed crawler applies the edited 30 HP policy once");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "the reconstructed attempt still has one damage ledger");
    }
}
