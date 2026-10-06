// A hit on a leg spills to the body: 10 Sever through leg 0's zone (Sever x1 on a limb) leaves the leg at 20 and, with the
// crawler's SpillToBody of 0.5, takes 5 off the body (115 of 120). The other legs are untouched.
class UMars_AutoTest_BodyPart_SpillDamagesBody : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 15.0f;
    default _Origin = FVector(130000.0, 88000.0, 600.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_CrawlerSpec(FVector(400.0, 400.0, 200.0)));

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", 0, 10.0f);
        Add_Step("hit leg 0's zone with 10 Sever", n"Step_HitLeg0");
        Add_Step_WaitUntil("the body reads 115 (half the hit spilled)", n"Check_BodyAt115", 0, 2.0f);
        Add_Step("leg 0 took the full hit; the other legs took nothing", n"Step_AssertLegs");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_HitLeg0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Zone = _Crawler.Get_LegParts()[0].Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(10.0f, GameplayTags::DamageType_Mars_Sever)));
    }

    UFUNCTION()
    private void Check_BodyAt115(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), 115.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertLegs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Parts = _Crawler.Get_LegParts();
        Assert_Equals_Float(Parts[0].Get_Health().Get_Current(), 20.0f, 0.001f, "leg 0 took the full 10");
        for (int32 Index = 1; Index < Parts.Num(); ++Index)
        { Assert_Equals_Float(Parts[Index].Get_Health().Get_Current(), 30.0f, 0.001f, f"leg {Index} is untouched"); }

        Assert_True(Parts[0].Get_State() == EMars_BodyPart_State::Attached,
            f"a non-lethal hit leaves the leg attached (got {Parts[0].Get_State() :n})");
        Assert_Equals_Float(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), 115.0f, 0.001f, "the body took exactly the spill");
    }
}
