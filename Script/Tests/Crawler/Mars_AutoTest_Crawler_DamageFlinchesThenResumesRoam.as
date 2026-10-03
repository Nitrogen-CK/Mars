// Damage interrupts roaming: a roaming crawler's leg part 0 takes a 5 Sever hit through its zone; the crawler's setup
// writes IsHurt true through the brain, the plan becomes [Flinch, Roam], and the behaviour sub-SM goes Roam -> Idle ->
// Flinch; the flinch stops the navigator (Idle within 0.5 s); after FlinchSeconds (0.6) the Flinch task clears IsHurt
// through the brain, the plan is [Roam] again and the crawler roams on.
class UMars_AutoTest_Crawler_DamageFlinchesThenResumesRoam : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(150000.0, 84000.0, 600.0);

    private float64 _FlinchAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", 0, 10.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam and the navigator Moving", n"Check_RoamingAndMoving", 0, 8.0f);
        Add_Step("hit leg part 0 for 5 Sever through its zone", n"Step_HitLeg");
        Add_Step_WaitUntil("the behaviour sub-SM reaches Flinch", n"Check_InFlinch", 0, 2.0f);
        Add_Step_WaitUntil("the flinch stopped the navigator within 0.5 s", n"Check_NavigatorIdle", 0, 2.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is back in Roam", n"Check_InRoam", 0, 3.0f);
        Add_Step("IsHurt was cleared and the leaf is Roam", n"Step_AssertRecovered");
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = Make_CrawlerSpec(FVector(300.0, 300.0, 200.0));
        Spec.RoamDwellSeconds = 0.3f;
        Spec.FlinchSeconds = 0.6f;
        return Spec;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_RoamingAndMoving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam &&
            _Crawler.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Moving);
    }

    UFUNCTION()
    private void Step_HitLeg(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Crawler.Get_Brain().Get_Fact(GameplayTags::Mars_WS_Crawler_IsHurt), "IsHurt starts false");

        auto Zone = _Crawler.Get_LegParts()[0].Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(5.0f, GameplayTags::DamageType_Mars_Sever)));
    }

    UFUNCTION()
    private void Check_InFlinch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto InFlinch = _Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Flinch;
        if (InFlinch)
        { _FlinchAt = System::GetGameTimeInSeconds(); }

        Res.Set(InFlinch);
    }

    UFUNCTION()
    private void Check_NavigatorIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Elapsed = System::GetGameTimeInSeconds() - _FlinchAt;
        if (_Crawler.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Idle)
        {
            Res.Set(true);
            return;
        }

        if (Elapsed > 0.5)
        { FinishFailure(f"the navigator is still {_Crawler.Get_Navigator().Get_Status() :n} {Elapsed} s into the flinch"); }
    }

    UFUNCTION()
    private void Step_AssertRecovered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Brain = _Crawler.Get_Brain();
        Assert_False(Brain.Get_Fact(GameplayTags::Mars_WS_Crawler_IsHurt), "the flinch cleared IsHurt");
        Assert_True(Brain.Get_LeafClass() == UMars_GoapAction_Crawler_Roam, "the brain's leaf is Roam again");
        Assert_Equals_Float(_Crawler.Get_LegParts()[0].Get_Health().Get_Current(), 25.0f, 0.001f, "leg 0 took the 5");
        Assert_True(System::GetGameTimeInSeconds() - _FlinchAt >= 0.6 - 0.05, "the flinch held for FlinchSeconds");
    }
}
