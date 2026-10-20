class UMars_AutoTest_CrawlerMelee_EndpointSingleReturns : UMars_AutoTestRig_CrawlerEndpointCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-700000.0, -180000.0, 600.0);
    default _CatalogLayout = EMars_Crawler_Layout::Radial;
    default _CatalogLegCount = 4;
    protected bool _Right = true;
    protected bool _Cancel = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_EndpointSpec();
        // A focused authored variant retains the four IDs/priorities and common native policy. Disable the other
        // limb clips so this test can exercise one slot while BOTH real front limbs remain healthy in the gait.
        auto Entries = _Catalog.Spec.Entries;
        for (auto& Entry : Entries)
        {
            if (Entry.Id == GameplayTags::Attack_Mars_Pincer || Entry.Id == (_Right ? GameplayTags::Attack_Mars_SwipeLeft : GameplayTags::Attack_Mars_SwipeRight)) { Entry.Enabled = false; }
        }
        _Catalog.Spec.Entries = Entries;
        _ExpectedEndpointId = _Right ? GameplayTags::Attack_Mars_SwipeRight : GameplayTags::Attack_Mars_SwipeLeft;
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("place a reachable miss target away from the physical claw paths", n"Step_MissTarget");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("focused one-slot entry is fully ready", n"Check_ExpectedEndpointReady", k_SlowPolls, 0);
        Add_Step("start current accepted geometry capture", n"Step_StartCapture");
        Add_Step("request one swipe", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the real single-claw action accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("the swipe claims one front; the unused front stays in the gait", n"Step_InspectClaim");
        Add_Step_WaitUntil("while the claim holds, the unused front stands on trusted support", n"Check_UnusedFrontTrusted", k_SlowPolls, 0);
        if (_Cancel)
        { Add_Step("cancel the accepted one-slot swipe", n"Step_Cancel"); }
        Add_Step_WaitUntil("game cleanup reaches Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("both healthy fronts are Default/Planted again", n"Check_CalibrationReleased", k_SlowPolls, 0);
        Add_Step("one-slot accepted motion and exact native return", n"Step_AssertReturn");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_MissTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnCombatTarget(InHandle, BodyLocation() + Get_Forward() * 250.0, FVector(6.0, 6.0, 6.0));
    }

    UFUNCTION()
    private void Step_InspectClaim(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Plan = _Crawler.Get_AttackPlan();
        Assert_True(Plan.Entry.Identity.Id == _ExpectedEndpointId && Plan.Entry.Slots.Num() == 1, "the independent swipe binds exactly one authored slot");
        const auto ClaimedId = _Right ? n"Leg0" : FName(f"Leg{_CatalogLegCount - 1}");
        const auto UnusedId = _Right ? FName(f"Leg{_CatalogLegCount - 1}") : n"Leg0";
        const auto Claimed = _Crawler.Get_Articulation().Get_LimbControl(ClaimedId);
        const auto Unused = _Crawler.Get_Articulation().Get_LimbControl(UnusedId);
        FCk_Handle Action = _Crawler.Get_AttackAction();
        Assert_True(Claimed.Get_State() == ECk_ProceduralLimbControl_State::Controlled && Claimed.Get_Owner() == Action && Claimed.Get_Participating() == false,
            "the action really borrowed its configured walking limb");
        Assert_True(Unused.Get_State() == ECk_ProceduralLimbControl_State::Default && Unused.Get_Participating(),
            "the healthy unused front stays in the gait");
    }

    // Whether the unused front's foot is on trusted ground in the frame the action is accepted depends on where its own
    // gait step happens to be, so the support claim is waited for while the claimed front is still the action's, never
    // sampled at acceptance.
    UFUNCTION()
    private void Check_UnusedFrontTrusted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto ClaimedId = _Right ? n"Leg0" : FName(f"Leg{_CatalogLegCount - 1}");
        const auto UnusedId = _Right ? FName(f"Leg{_CatalogLegCount - 1}") : n"Leg0";
        const auto Claimed = _Crawler.Get_Articulation().Get_LimbControl(ClaimedId);
        const auto Unused = _Crawler.Get_Articulation().Get_LimbControl(UnusedId);
        FCk_Handle Action = _Crawler.Get_AttackAction();
        if (Claimed.Get_State() != ECk_ProceduralLimbControl_State::Controlled || Claimed.Get_Owner() != Action)
        {
            FinishFailure("the swipe released its claim before the unused front stood on trusted support");
            return;
        }

        auto Res = OutResult;
        Res.Set(Unused.Get_State() == ECk_ProceduralLimbControl_State::Default && Unused.Get_Participating() && Unused.Get_TrustedSupport());
    }

    UFUNCTION()
    private void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));
    }

    UFUNCTION()
    private void Step_AssertReturn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_MeasuredTrace();
        Assert_True(_CatalogResults.Num() == 1 && _CatalogResults[0].Accepted &&
            _CatalogResults[0].Native.Get_Outcome() == (_Cancel ? ECk_ProceduralAction_Outcome::Cancelled : ECk_ProceduralAction_Outcome::Completed) &&
            _CatalogResults[0].Native.Get_Recovery() == ECk_ProceduralAction_Recovery::Succeeded,
            "the exact native completion/cancellation and successful one-limb managed return are observed");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "the off-path target remains a real physical miss");
    }
}

class UMars_AutoTest_CrawlerMelee_EndpointSingleLeftRadialFour : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-710000.0, -180000.0, 600.0);
    default _Right = false;
    default _Cancel = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleRightRadialSix : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-720000.0, -180000.0, 600.0);
    default _CatalogLegCount = 6;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleLeftRadialSix : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-730000.0, -180000.0, 600.0);
    default _CatalogLegCount = 6;
    default _Right = false;
    default _Cancel = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleRightSpiderSix : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-740000.0, -180000.0, 600.0);
    default _CatalogLegCount = 6;
    default _CatalogLayout = EMars_Crawler_Layout::Spider;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleLeftSpiderSix : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-750000.0, -180000.0, 600.0);
    default _CatalogLegCount = 6;
    default _CatalogLayout = EMars_Crawler_Layout::Spider;
    default _Right = false;
    default _Cancel = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleRightCancelRadialFour : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-770000.0, -180000.0, 600.0);
    default _Cancel = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteRadialFour : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-780000.0, -180000.0, 600.0);
    default _Right = false;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleRightCancelRadialSix : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-790000.0, -180000.0, 600.0);
    default _CatalogLegCount = 6;
    default _Cancel = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteRadialSix : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-800000.0, -180000.0, 600.0);
    default _CatalogLegCount = 6;
    default _Right = false;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleRightCancelSpiderSix : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-810000.0, -180000.0, 600.0);
    default _CatalogLegCount = 6;
    default _CatalogLayout = EMars_Crawler_Layout::Spider;
    default _Cancel = true;
}
class UMars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteSpiderSix : UMars_AutoTest_CrawlerMelee_EndpointSingleReturns
{
    default _Origin = FVector(-820000.0, -180000.0, 600.0);
    default _CatalogLegCount = 6;
    default _CatalogLayout = EMars_Crawler_Layout::Spider;
    default _Right = false;
}
