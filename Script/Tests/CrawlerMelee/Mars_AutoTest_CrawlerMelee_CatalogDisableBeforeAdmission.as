class UMars_AutoTest_CrawlerMelee_CatalogDisableBeforeAdmission : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-500000.0, -180000.0, 600.0);

    private bool _DisabledPending = false;
    private FCk_ProceduralAction_Identity _PendingIdentity;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(false);
        _CatalogPincer.Def.Cooldown.ReuseSeconds = 5.0f;
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("spawn a reachable target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("bind the pending native admission boundary", n"Step_BindBoundary");
        Add_Step("start a pincer", n"Step_TargetAndStart");
        Add_Step_WaitUntil("disabled pending attempt reaches a reported terminal", n"Check_Reported", k_SlowPolls, 0);
        Add_Step_WaitUntil("game cleanup completes", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("C07 disabled anatomy before native acceptance costs nothing", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_BindBoundary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.BindTo_OnAttackPhaseChanged(FMars_Delegate_Crawler_OnAttackPhaseChanged(this, n"OnPendingBoundary"));
    }

    UFUNCTION()
    private void OnPendingBoundary(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew)
    {
        if (_DisabledPending || InNew != EMars_Crawler_AttackPhase::Windup)
        { return; }
        const auto Action = InCrawler.Get_Fragment(FMars_Fragment_Crawler_Attack).Action;
        Assert_True(ck::IsValid(Action) && Action.Get_State() == ECk_ProceduralAction_State::PendingAdmission &&
            Action.Get_LastReceipt().Get_HasAcceptedPose() == false,
            "Windup callback observes a real pending action with no accepted receipt");
        _PendingIdentity = Action.Get_Identity();
        auto Leg = InCrawler.Get_LegParts().Last().Get_Leg();
        Leg.Request_EnableDisable(FCk_Request_ProceduralLeg_EnableDisable(ECk_EnableDisable::Disable));
        _DisabledPending = true;
    }

    UFUNCTION()
    private void Check_Reported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_DisabledPending && _CatalogResults.Num() > 0 &&
            utils_procedural_leg::Get_Status(_Crawler.Get_LegParts().Last().Get_Leg()) == ECk_ProceduralLeg_Status::Disabled);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CatalogAdmissions.Num(), 0, "disabled-before-accept publishes no admission");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "disabled-before-accept issues no damage");
        Assert_True(Get_CatalogLastStart(GameplayTags::Attack_Mars_Pincer) == 0 && Get_CatalogReuseRemaining(GameplayTags::Attack_Mars_Pincer) == 0.0f,
            "no accepted start sequence or entry reuse was charged");
        Assert_Equals_Int(_CatalogResults.Num(), 1, "one pending game attempt produces one result");
        if (_CatalogResults.Num() != 1)
        { return; }
        const auto Result = _CatalogResults[0];
        Assert_True(Result.ActionIdentity.Get_Value() == _PendingIdentity.Get_Value() && Result.Accepted == false &&
            Result.Native.Get_Outcome() != ECk_ProceduralAction_Outcome::Completed,
            "the pending identity terminates without accepted motion or a fabricated completed outcome");
        Log(f"[CatalogDisableBeforeAdmission] native [{Result.Native.Get_Outcome() :n}/{Result.Native.Get_Reason()}], cleanup [{Result.CleanupOutcome}]");
    }
}
