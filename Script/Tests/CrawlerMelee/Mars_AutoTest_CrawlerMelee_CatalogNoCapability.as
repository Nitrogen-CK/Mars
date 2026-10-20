class UMars_AutoTest_CrawlerMelee_CatalogNoCapability : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-530000.0, -180000.0, 600.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(true);
        auto Required = FMars_Attack_PartRequirement();
        Required.Role = GameplayTags::AttackRole_Mars_FrontLeft;
        _CatalogJab.Def.Requirements.Parts.Add(Required);
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("spawn a reachable target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step("disable the common required front role using its public request", n"Step_Disable");
        Add_Step_WaitUntil("disabled role produces zero capable entries", n"Check_NoCapability", k_SlowPolls, 0);
        for (int32 Index = 0; Index < 3; ++Index)
        {
            Add_Step("repeat a target-only automatic start with no capable anatomy", n"Step_TargetAndStart");
            Add_Step_WaitUntil("the automatic start transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
            Add_Step("no-capability never creates or charges an action", n"Step_Assert");
        }
        Add_Step("reenable the common front role through its existing public request", n"Step_Enable");
        Add_Step_WaitUntil("normal evaluation sees the recovered eligible custom entry", n"Check_EligibleAgain", k_SlowPolls, 0);
        Add_Step("retry a normal automatic start after recovery", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the reenabled role allows a real admission", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("reenabling restores capability without reconstruction", n"Step_AssertRecovered");
        Add_Step_WaitUntil("the retry completes", n"Check_AttackFinished", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Disable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Leg = _Crawler.Get_LegParts().Last().Get_Leg();
        Leg.Request_EnableDisable(FCk_Request_ProceduralLeg_EnableDisable(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Step_Enable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Leg = _Crawler.Get_LegParts().Last().Get_Leg();
        Leg.Request_EnableDisable(FCk_Request_ProceduralLeg_EnableDisable(ECk_EnableDisable::Enable));
    }

    UFUNCTION()
    private void Check_EligibleAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
        auto Res = OutResult;
        Res.Set(Advice.Selection.Selected.IsSet() && Advice.Selection.Selected.GetValue() == GameplayTags::Attack_Mars_Test_Fourth);
    }

    UFUNCTION()
    private void Step_AssertRecovered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackId() == GameplayTags::Attack_Mars_Test_Fourth && Get_CatalogLastStart(GameplayTags::Attack_Mars_Test_Fourth) == 1,
            "normal retry chooses the restored required role and charges its first accepted sequence");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "only the recovered retry admits");
    }

    UFUNCTION()
    private void Check_NoCapability(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
        auto Capable = 0;
        for (const auto& Evaluation : Advice.Evaluations)
        { if (Evaluation.Capable) { ++Capable; } }
        auto Res = OutResult;
        Res.Set(utils_procedural_leg::Get_Status(_Crawler.Get_LegParts().Last().Get_Leg()) == ECk_ProceduralLeg_Status::Disabled &&
            Capable == 0 && Advice.Selection.Disposition == EMars_Attack_SelectionDisposition::NoCapability);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle &&
            _Crawler.Get_AttackActionIdentity().Get_Value() == 0,
            "repeated no-capability requests create no native action");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 0, "no-capability emits no accepted admission");
        Assert_Equals_Int(_CatalogResults.Num(), 0, "no-capability does not fabricate a native attempt result");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "no-capability emits no damage");
        for (const auto& Reuse : _Crawler.Get_AttackReuse())
        { Assert_True(Reuse.Remaining == 0.0f && Reuse.LastStartSequence == 0, "no-capability charges neither cooldown nor admission recency"); }
    }
}
