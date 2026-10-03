// Death is a state, and the Dead state does the teardown: a roaming 4-leg crawler takes 200 Blunt on its body zone; the
// monster dies and the root HFSM leaves Alive for Dead, whose Die task stops the navigator, disables the brain, severs
// all 4 legs and disables the body zone. The severed legs are handed to the world while the corpse still stands, so they
// die on their own debris timer rather than with the root; the corpse timer then destroys the root.
class UMars_AutoTest_Crawler_DeathDetachesLegsAndDespawns : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(160000.0, 80000.0, 600.0);

    private FCk_Handle _Floor;
    private FCk_Handle _CrawlerRoot;

    private int32 _DiedCount = 0;
    private int32 _SeveredCount = 0;
    private TArray<FCk_Handle> _SeveredLegs;
    private TArray<FCk_Handle> _Debris;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Floor = SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed and its gait Ready", n"Check_GaitReady", 0, 10.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_InRoam", 0, 5.0f);
        Add_Step("bind OnDied and every part's OnSevered; hit the body zone with 200 Blunt", n"Step_BindAndKill");
        Add_Step_WaitUntil("the root state machine is in Dead", n"Check_InDead", 0, 3.0f);
        Add_Step_WaitUntil("the Die task tore the crawler down", n"Check_TornDown", 0, 1.0f);
        Add_Step("one death, four severs, no leg enabled", n"Step_AssertTeardown");
        Add_Step_WaitUntil("every severed leg is world-owned while the corpse stands", n"Check_LegsWorldOwned", 0, 1.0f);
        Add_Step_WaitUntil("the corpse timer destroyed the crawler root", n"Check_RootDestroyed", 0, 2.5f);
        Add_Step("the severed limbs died on their own timer; the floor is untouched", n"Step_AssertDespawned");
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = Make_CrawlerSpec(FVector(300.0, 300.0, 200.0));
        Spec.RoamDwellSeconds = 0.3f;
        // Both overrides keep everything the death releases inside the test (no entity outlives it).
        Spec.Vitals.CorpseSeconds = 1.5f;
        Spec.Vitals.LegDebris.LifetimeSeconds = 1.0f;
        return Spec;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        ++_DiedCount;
    }

    UFUNCTION()
    private void OnSevered(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased)
    {
        ++_SeveredCount;
        _SeveredLegs.Add(InPart);
        for (const auto& Released : InReleased)
        { _Debris.Add(Released); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_BindAndKill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CrawlerRoot = _Crawler;

        auto Monster = _Crawler.Get_Monster();
        Monster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnDied"));

        auto Parts = _Crawler.Get_LegParts();
        Assert_Equals_Int(Parts.Num(), 4, "the crawler has 4 leg parts");
        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            auto Part = Parts[Index];
            Part.BindTo_OnSevered(FMars_Delegate_BodyPart_OnSevered(this, n"OnSevered"));
        }

        auto BodyZone = Monster.Get_BodyZone();
        BodyZone.Request_Hit(FMars_Request_HitZone_Hit(
            FMars_DamageEvent(200.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Check_InDead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::IsInState(_CrawlerRoot.As_StateMachine(), UMars_SmState_Crawler_Dead));
    }

    UFUNCTION()
    private void Check_TornDown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Crawler))
        {
            FinishFailure("the crawler root died before the teardown was observed");
            return;
        }

        auto Severed = 0;
        for (auto Part : _Crawler.Get_LegParts())
        {
            if (ck::IsValid(Part) && Part.Get_State() == EMars_BodyPart_State::Severed)
            { ++Severed; }
        }

        Res.Set(_Crawler.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Idle &&
            _Crawler.Get_Brain().Get_IsEnabled() == false &&
            Severed == 4 && _SeveredCount == 4 &&
            utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait()) == 0 &&
            _Crawler.Get_Monster().Get_BodyZone().Get_IsEnabled() == false);
    }

    UFUNCTION()
    private void Step_AssertTeardown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Monster = _Crawler.Get_Monster();
        Assert_True(Monster.Get_IsDead(), "the monster is dead");
        Assert_Equals_Int(_DiedCount, 1, "OnDied fired once");
        Assert_Equals_Int(_SeveredCount, 4, "OnSevered fired for each of the 4 legs");
        Assert_Equals_Int(Monster.Get_AttachedPartCount(), 0, "no part is still attached");
        Assert_Equals_Int(_Debris.Num(), 12, "each leg released its 2 segments and its foot");
        Assert_True(Monster.Get_BodyHealth().Get_IsDepleted(), "the body Health is depleted");
        Assert_True(ck::IsValid(_CrawlerRoot), "the corpse is still there before CorpseSeconds");
    }

    // Polled while the root still lives: a leg the root kept would die with the corpse and pass the despawn check too.
    UFUNCTION()
    private void Check_LegsWorldOwned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_CrawlerRoot))
        {
            FinishFailure("the corpse was destroyed before every severed leg was seen world-owned");
            return;
        }

        auto AllWorldOwned = _SeveredLegs.Num() == 4;
        for (const auto& Leg : _SeveredLegs)
        {
            const auto LegOwner = utils_entity_lifetime::Get_LifetimeOwner(Leg);
            AllWorldOwned = AllWorldOwned && LegOwner != _CrawlerRoot
                && ck::IsValid(LegOwner) && utils_entity_lifetime::Get_IsTransientEntity(LegOwner);
        }

        Res.Set(AllWorldOwned);
    }

    UFUNCTION()
    private void Check_RootDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_CrawlerRoot));
    }

    UFUNCTION()
    private void Step_AssertDespawned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < _SeveredLegs.Num(); ++Index)
        { Assert_True(ck::Is_NOT_Valid(_SeveredLegs[Index]), f"severed leg [{Index}] died on its debris timer"); }

        for (int32 Index = 0; Index < _Debris.Num(); ++Index)
        { Assert_True(ck::Is_NOT_Valid(_Debris[Index]), f"debris part [{Index}] died with its severed leg"); }

        Assert_True(ck::IsValid(_Floor), "the floor outlives the crawler");
    }
}
