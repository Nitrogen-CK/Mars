class UMars_AutoTest_CrawlerMelee_CatalogTokensAndFallback : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 120.0f;
    default _Origin = FVector(-430000.0, -180000.0, 600.0);

    private int32 _OldToken = 0;
    private int32 _AdmissionsBeforeReject = 0;
    private int32 _DamageBeforeBodyDepletion = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_CatalogSpec(true));
        Add_CatalogSettleSteps();
        Add_Step("spawn a body-sphere target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("choose the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target requests drain", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step("reject an explicit unknown attack without fallback", n"Step_Unknown");
        Add_Step_WaitUntil("unknown request drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step("C03 unknown explicit ID created no action", n"Step_AssertUnknown");
        Add_Step("automatically start the data-only custom fourth ID", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the custom ID is actually accepted", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("C02 custom body attack requires an unanimated front role", n"Step_AssertCustom");
        Add_Step_WaitUntil("the custom attempt ends", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("prepare the custom attack and capture its live selection token", n"Step_Prepare");
        Add_Step_WaitUntil("preparation established a preferred attack", n"Check_Prepared", k_SlowPolls, 0);
        Add_Step("sever the custom prerequisite FrontLeft", n"Step_SeverLeft");
        Add_Step_WaitUntil("the actual FrontLeft depletion and detach are processed", n"Check_LeftSevered", k_SlowPolls, 0);
        Add_Step_WaitUntil("the retained preference invalidates and the token changes", n"Check_FreshJabAdvice", k_SlowPolls, 0);
        Add_Step("send the stale explicit custom token", n"Step_Stale");
        Add_Step_WaitUntil("stale request drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step("C03 stale request has no action and no fallback", n"Step_AssertStale");
        Add_Step("fresh target-only admission falls back to Jab", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the first fallback Jab accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("C02 stable anatomical loss selected Jab", n"Step_AssertJab");
        Add_Step_WaitUntil("the first Jab ends", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("disable FrontRight as well", n"Step_DisableRight");
        Add_Step_WaitUntil("both front attack limbs are unavailable", n"Check_BothUnavailable", k_SlowPolls, 0);
        Add_Step("start a body Jab with sufficient rear support", n"Step_TargetAndStart");
        Add_Step_WaitUntil("body Jab still admits", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("body Jab remains independent of front slots", n"Step_AssertJab");
        Add_Step_WaitUntil("the body Jab ends", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("deplete required body Health and request another start", n"Step_DepleteBodyAndStart");
        Add_Step_WaitUntil("body depletion has actually processed", n"Check_BodyDepleted", k_SlowPolls, 0);
        Add_Step("C03 depleted required body cannot emit another attack", n"Step_AssertBodyGuard");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Unknown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _AdmissionsBeforeReject = _CatalogAdmissions.Num();
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity, GameplayTags::Attack_Mars_Test_Unknown, _Crawler.Get_AttackEvaluation().SelectionGeneration));
    }

    UFUNCTION()
    private void Step_AssertUnknown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Reject = _Crawler.Get_AttackLastReject();
        Assert_True(Reject.IsSet() && Reject.GetValue() == EMars_Crawler_AttackReject::AttackUnknown, "explicit unknown ID reports AttackUnknown");
        Assert_True(_Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack).ActionIdentity.Get_Value() == 0 &&
            _CatalogAdmissions.Num() == _AdmissionsBeforeReject, "an unknown explicit request created no action or admission");
    }

    UFUNCTION()
    private void Step_AssertCustom(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Plan = _Crawler.Get_AttackPlan();
        Assert_True(Plan.Entry.Identity.Id == GameplayTags::Attack_Mars_Test_Fourth && Plan.Entry.Slots.Num() == 0,
            "a data-only custom ID executes a body clip without pretending to claim its prerequisite");
        Assert_True(_Crawler.Get_AttackLegacyClipKind().IsSet() == false, "custom identity is never silently labelled as legacy Jab");
        auto RequiredLeft = false;
        for (const auto& Part : Plan.Entry.Parts)
        { RequiredLeft = RequiredLeft || Part.Binding.Role == GameplayTags::AttackRole_Mars_FrontLeft && Part.Binding.LimbId == n"Leg5"; }
        Assert_True(RequiredLeft, "the unanimated required front role is frozen to its stable Leg5 identity");
    }

    UFUNCTION()
    private void Step_Prepare(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_PrepareAttack(FMars_Request_Crawler_PrepareAttack(_Target.Entity));
    }

    UFUNCTION()
    private void Check_Prepared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Preparation = _Crawler.Get_AttackPreparation();
        auto Res = OutResult;
        const auto Ready = Preparation.Active && Preparation.Preferred == GameplayTags::Attack_Mars_Test_Fourth;
        if (Ready)
        { _OldToken = _Crawler.Get_AttackEvaluation().SelectionGeneration; }
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Step_SeverLeft(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Health = _Crawler.Get_LegParts().Last().Get_Health();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(1000.0f, GameplayTags::DamageType_Mars_Sever)));
    }

    UFUNCTION()
    private void Check_LeftSevered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Left = _Crawler.Get_LegParts().Last();
        auto Res = OutResult;
        Res.Set(Left.Get_Health().Get_IsDepleted() && Left.Get_State() == EMars_BodyPart_State::Severed &&
            utils_procedural_leg::Get_IsAttached(Left.Get_Leg()) == false);
    }

    UFUNCTION()
    private void Check_FreshJabAdvice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = _Crawler.Get_AttackEvaluation();
        auto Res = OutResult;
        Res.Set(Advice.SelectionGeneration != _OldToken && Advice.Selection.Preferred.IsSet() && Advice.Selection.Preferred.GetValue() == GameplayTags::Attack_Mars_Jab);
    }

    UFUNCTION()
    private void Step_Stale(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _AdmissionsBeforeReject = _CatalogAdmissions.Num();
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity, GameplayTags::Attack_Mars_Test_Fourth, _OldToken));
    }

    UFUNCTION()
    private void Step_AssertStale(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Reject = _Crawler.Get_AttackLastReject();
        Assert_True(Reject.IsSet() && Reject.GetValue() == EMars_Crawler_AttackReject::SelectionStale,
            "processed anatomy change invalidates the explicit selection generation");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle &&
            _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack).ActionIdentity.Get_Value() == 0 &&
            _CatalogAdmissions.Num() == _AdmissionsBeforeReject, "stale explicit selection neither creates an action nor falls back");
    }

    UFUNCTION()
    private void Step_AssertJab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Plan = _Crawler.Get_AttackPlan();
        Assert_True(Plan.Entry.Identity.Id == GameplayTags::Attack_Mars_Jab && Plan.Entry.Slots.Num() == 0,
            "fresh automatic selection falls back to an eligible body-only Jab");
        auto StableLeft = false;
        for (const auto& Binding : _Crawler.Get_Spec().ResolvedAttacks.Anatomy)
        { StableLeft = StableLeft || Binding.Role == GameplayTags::AttackRole_Mars_FrontLeft && Binding.LimbId == n"Leg5"; }
        Assert_True(StableLeft, "losing a limb never reassigns the FrontLeft role to a survivor");
    }

    UFUNCTION()
    private void Step_DisableRight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Leg = _Crawler.Get_LegParts()[0].Get_Leg();
        Leg.Request_EnableDisable(FCk_Request_ProceduralLeg_EnableDisable(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Check_BothUnavailable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_procedural_leg::Get_Status(_Crawler.Get_LegParts()[0].Get_Leg()) == ECk_ProceduralLeg_Status::Disabled &&
            _Crawler.Get_LegParts().Last().Get_State() == EMars_BodyPart_State::Severed);
    }

    UFUNCTION()
    private void Step_DepleteBodyAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DamageBeforeBodyDepletion = Get_DamageRequestCount();
        _AdmissionsBeforeReject = _CatalogAdmissions.Num();
        auto Health = _Crawler.Get_Monster().Get_BodyHealth();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(1000.0f, GameplayTags::DamageType_Mars_Blunt)));
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
    }

    UFUNCTION()
    private void Check_BodyDepleted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_Monster().Get_BodyHealth().Get_IsDepleted() && _Crawler.Get_HasPendingCombatRequests() == false);
    }

    UFUNCTION()
    private void Step_AssertBodyGuard(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CatalogAdmissions.Num(), _AdmissionsBeforeReject, "depleted required body produced zero additional accepted admissions");
        Assert_Equals_Int(Get_DamageRequestCount(), _DamageBeforeBodyDepletion, "depleted body emitted no additional damage request");
    }
}
