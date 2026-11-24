// Death is a state, and the Dead state does the teardown: a roaming 4-leg crawler takes 200 Blunt on its body zone; the
// monster dies and the root HFSM leaves Alive for Dead, whose Die task stops the navigator, disables the brain, severs
// all 4 legs and disables the body zone. Within ten frames of each OnSevered its released parts are gone, and four
// severed limbs fall near the corpse, each with a Jolt body on every piece and every joint added. The severed legs stay
// the body's, valid and detached while the corpse stands; the corpse timer then destroys the root and the legs with it,
// and the limbs end on their own 1 s lifetime.
class UMars_AutoTest_Crawler_DeathDetachesLegsAndDespawns : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(160000.0, 80000.0, 600.0);

    private FCk_Handle _Floor;
    private FCk_Handle _CrawlerRoot;

    private int32 _DiedCount = 0;
    private int32 _SeveredCount = 0;
    private int32 _LastSeveredFrame = -1;
    private TArray<FCk_Handle> _SeveredLegs;
    private TArray<FCk_Handle> _Released;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Floor = SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed and its gait Ready", n"Check_GaitReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_InRoam", 0, 0);
        Add_Step("bind OnDied and every part's OnSevered; hit the body zone with 200 Blunt", n"Step_BindAndKill");
        Add_Step_WaitUntil("the root state machine is in Dead", n"Check_InDead", 0, 0);
        Add_Step_WaitUntil("the Die task tore the crawler down", n"Check_TornDown", 0, 0);
        Add_Step("one death, four severs, no leg enabled", n"Step_AssertTeardown");
        Add_Step_WaitUntil("every released part is gone within ten frames of its OnSevered", n"Check_ReleasedGone", 0, 0);
        Add_Step_WaitUntil("four severed limbs are near, each with its bodies and joints", n"Check_FourLimbs", k_SlowPolls, 0);
        Add_Step("every severed leg stays the body's, valid and detached, while the corpse stands", n"Step_AssertLegsKept");
        Add_Step_WaitUntil("the corpse timer destroyed the crawler root", n"Check_RootDestroyed", k_SlowPolls, 0);
        Add_Step_WaitUntil("every limb is gone after its lifetime", n"Check_NoLimbNear", k_SlowPolls, 0);
        Add_Step("the severed legs died with the root; the floor is untouched", n"Step_AssertDespawned");
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = Make_CrawlerSpec(FVector(300.0, 300.0, 200.0));
        Spec.RoamDwellSeconds = 0.3f;
        // Both keep what the death leaves short-lived; the limbs live under the replicated spawn owner and must end
        // inside the test (no leak).
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
        _LastSeveredFrame = int32(utils_time::Get_FrameCounter());
        _SeveredLegs.Add(InPart);
        for (const auto& Released : InReleased)
        { _Released.Add(Released); }
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
        Assert_Equals_Int(_Released.Num(), 12, "each leg released its 2 segments and its foot");
        Assert_True(Monster.Get_BodyHealth().Get_IsDepleted(), "the body Health is depleted");
        Assert_True(ck::IsValid(_CrawlerRoot), "the corpse is still there before CorpseSeconds");
    }

    UFUNCTION()
    private void Check_ReleasedGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Gone = true;
        for (auto Released : _Released)
        { Gone = Gone && (ck::Is_NOT_Valid(Released) || utils_entity_lifetime::Get_IsPendingDestroy(Released, ECk_EntityLifetime_DestructionPhase::BeginDestroy)); }

        const auto Frames = int32(utils_time::Get_FrameCounter()) - _LastSeveredFrame;
        if (Gone == false && Frames > 10)
        {
            FinishFailure(f"a released part is still valid {Frames} frames after the last OnSevered");
            return;
        }

        auto Res = OutResult;
        Res.Set(Gone);
    }

    UFUNCTION()
    private void Check_FourLimbs(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Limbs = Get_LimbsNear(InHandle);
        if (Limbs.Num() > 4)
        {
            FinishFailure(f"{Limbs.Num()} limbs near the corpse for four severed legs");
            return;
        }

        auto Simulated = Limbs.Num() == 4;
        for (auto Limb : Limbs)
        { Simulated = Simulated && Get_IsLimbSimulated(Limb); }

        auto Res = OutResult;
        Res.Set(Simulated);
    }

    UFUNCTION()
    private void Step_AssertLegsKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_CrawlerRoot), "the corpse still stands");
        Assert_Equals_Int(_SeveredLegs.Num(), 4, "four legs severed");
        for (int32 Index = 0; Index < _SeveredLegs.Num(); ++Index)
        {
            const auto Leg = _SeveredLegs[Index];
            Assert_True(ck::IsValid(Leg), f"severed leg [{Index}] is valid");
            if (ck::Is_NOT_Valid(Leg))
            { continue; }

            Assert_True(utils_entity_lifetime::Get_LifetimeOwner(Leg) == _CrawlerRoot, f"severed leg [{Index}] stays the body's");
            Assert_False(utils_procedural_leg::Get_IsAttached(Leg.As_ProceduralLeg()), f"severed leg [{Index}] is not attached");
            Assert_True(Leg.As_BodyPart().Get_State() == EMars_BodyPart_State::Severed, f"severed leg [{Index}]'s part reads Severed");
        }
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
        { Assert_True(ck::Is_NOT_Valid(_SeveredLegs[Index]), f"severed leg [{Index}] died with the root"); }

        for (int32 Index = 0; Index < _Released.Num(); ++Index)
        { Assert_True(ck::Is_NOT_Valid(_Released[Index]), f"released part [{Index}] is gone"); }

        Assert_True(ck::IsValid(_Floor), "the floor outlives the crawler");
    }
}
