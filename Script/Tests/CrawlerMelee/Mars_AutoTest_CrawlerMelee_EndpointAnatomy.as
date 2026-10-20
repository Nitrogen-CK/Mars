class UMars_AutoTest_CrawlerMelee_EndpointAnatomy : UMars_AutoTestRig_CrawlerEndpointCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-550000.0, -180000.0, 600.0);
    default _ExpectedEndpointId = GameplayTags::Attack_Mars_Pincer;
    protected bool _DisableRight = false;
    protected bool _DisableLeft = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_EndpointSpec());
        Add_CatalogSettleSteps();
        Add_Step("apply the fixture's front-limb availability through public requests", n"Step_Availability");
        Add_Step_WaitUntil("both requested limb statuses are processed", n"Check_Availability", k_SlowPolls, 0);
        Add_Step("spawn a direct-start target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target requests drain", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("four-entry advice selects the intended anatomy fallback", n"Check_ExpectedEndpointReady", k_SlowPolls, 0);
        Add_Step("request one automatic attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the intended fallback really accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("exact configured slot count and stable anatomical roles", n"Step_AssertSelection");
        Add_Step_WaitUntil("the chosen action finishes", n"Check_AttackFinished", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Availability(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (_DisableRight)
        {
            auto Leg = _Crawler.Get_LegParts()[0].Get_Leg();
            Leg.Request_EnableDisable(FCk_Request_ProceduralLeg_EnableDisable(ECk_EnableDisable::Disable));
        }
        if (_DisableLeft)
        {
            auto Leg = _Crawler.Get_LegParts().Last().Get_Leg();
            Leg.Request_EnableDisable(FCk_Request_ProceduralLeg_EnableDisable(ECk_EnableDisable::Disable));
        }
    }

    UFUNCTION()
    private void Check_Availability(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_DisableRight == false || _Crawler.Get_LegParts()[0].Get_Leg().Get_Status() == ECk_ProceduralLeg_Status::Disabled) &&
            (_DisableLeft == false || _Crawler.Get_LegParts().Last().Get_Leg().Get_Status() == ECk_ProceduralLeg_Status::Disabled));
    }

    UFUNCTION()
    private void Step_AssertSelection(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Plan = _Crawler.Get_AttackPlan();
        Assert_True(Plan.Entry.Identity.Id == _ExpectedEndpointId, "both/right-only/left-only/neither fronts use Pincer/SwipeRight/SwipeLeft/Jab");
        Assert_Equals_Int(Plan.Entry.Slots.Num(), _ExpectedEndpointId == GameplayTags::Attack_Mars_Pincer ? 2 : _ExpectedEndpointId == GameplayTags::Attack_Mars_Jab ? 0 : 1,
            "the accepted fallback binds only its actual configured slots");
        for (const auto& Slot : Plan.Entry.Slots)
        {
            Assert_True(Slot.Binding.LimbId == (Slot.Binding.Role == GameplayTags::AttackRole_Mars_FrontRight ? n"Leg0" : n"Leg5"),
                "fallback never reassigns an anatomical role to another surviving limb");
        }
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "one requested fallback creates one accepted admission");
    }
}

class UMars_AutoTest_CrawlerMelee_EndpointAnatomyRightOnly : UMars_AutoTest_CrawlerMelee_EndpointAnatomy
{
    default _Origin = FVector(-560000.0, -180000.0, 600.0);
    default _DisableLeft = true;
    default _ExpectedEndpointId = GameplayTags::Attack_Mars_SwipeRight;
}
class UMars_AutoTest_CrawlerMelee_EndpointAnatomyLeftOnly : UMars_AutoTest_CrawlerMelee_EndpointAnatomy
{
    default _Origin = FVector(-570000.0, -180000.0, 600.0);
    default _DisableRight = true;
    default _ExpectedEndpointId = GameplayTags::Attack_Mars_SwipeLeft;
}
class UMars_AutoTest_CrawlerMelee_EndpointAnatomyNeither : UMars_AutoTest_CrawlerMelee_EndpointAnatomy
{
    default _Origin = FVector(-580000.0, -180000.0, 600.0);
    default _DisableRight = true;
    default _DisableLeft = true;
    default _ExpectedEndpointId = GameplayTags::Attack_Mars_Jab;
}
