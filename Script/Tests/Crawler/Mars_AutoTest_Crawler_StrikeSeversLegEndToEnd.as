// The production strike path end to end: an attacker (team One, a DamageDealer) swings at a roaming 4-leg crawler's
// leg 0 with utils_damage_dealer::Try_StrikeSweep - the same helper the player's Strike task calls (sphere 25, reach
// 180, Probe.Mars.HitZone, Blocking, Silent) - as 20 Sever events from Make_Event. Each swing starts 150 uu outside the
// leg along the body -> foot direction and sweeps inward through its lower segment; the hit is a probe whose zone is
// leg 0's. Nothing touches a Health directly: dealer -> zone -> part ledger + spill -> Health -> depletion -> sever.
// Two swings sever the 30 HP leg; the first hit makes the crawler flinch (polled: the behaviour sub-SM's signal is not
// reachable from here), and it roams again afterwards on its 3 remaining legs. The body took the spill of both hits as
// the zone scaled them (0.5 x 20 each, before the leg Health clamps the second to its remaining 10): 120 -> 100.
class UMars_AutoTest_Crawler_StrikeSeversLegEndToEnd : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(160000.0, 84000.0, 600.0);

    private const float32 k_Reach = 180.0f;
    private const float32 k_Radius = 25.0f;
    private const float64 k_StandOff = 150.0;
    private const float64 k_SwingInterval = 0.5;
    private const int32 k_MaxSwings = 8;

    private FCk_Handle_DamageDealer _Dealer;
    private FCk_Handle _SeveredLeg;

    private int32 _Swings = 0;
    private int32 _SweepHits = 0;
    private TOptional<float64> _LastSwingAt;
    private bool _SawFlinch = false;
    private TArray<FCk_Handle_HitZone> _DealtZones;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", 0, 10.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_InRoam", 0, 5.0f);
        Add_Step("an attacker on team One with a DamageDealer stands 150 uu outside leg 0's foot", n"Step_AddAttacker");
        Add_Step_WaitUntil("strike leg 0 through the shared sweep until it is severed", n"Check_StrikeUntilSevered", 0, 5.0f);
        Add_Step_WaitUntil("the crawler flinched and roams again", n"Check_FlinchedThenRoams", 0, 4.0f);
        Add_Step("two swept hits on leg 0's zone; body 100; three legs walk", n"Step_AssertEndToEnd");
        Add_Step_WaitUntil("the severed limb died on its debris timer", n"Check_SeveredLegGone", 0, 3.0f);
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = Make_CrawlerSpec(FVector(300.0, 300.0, 200.0));
        Spec.RoamDwellSeconds = 0.3f;
        // The severed limb is world-owned: it must die inside the test (no leak).
        Spec.Vitals.LegDebris.LifetimeSeconds = 1.0f;
        return Spec;
    }

    // The swing for leg 0 as it stands now: from 150 uu outside its lower segment (along the body -> foot direction,
    // read from the leg's published foot) inward through it, at the segment's height so the sphere clears the floor.
    private FMars_DamageDealer_Sweep Make_SwingAtLeg0() const
    {
        const auto Body = BodyLocation();
        const auto Foot = utils_procedural_leg::Get_Foot(_Crawler.Get_Legs()[0]).Get_Position();
        auto Outward = Foot - Body;
        Outward.Z = 0.0;
        Outward = Outward.GetSafeNormal();

        const auto LowerSegment = _Crawler.Get_LegRig(0).Segments.Last();
        const auto Target = utils_transform::Get_EntityCurrentLocation(LowerSegment);
        const auto Start = Target + Outward * k_StandOff;
        return FMars_DamageDealer_Sweep(Start, Start - Outward * k_Reach, k_Radius);
    }

    private FMars_DamageEvent Make_Swing20Sever() const
    {
        return utils_damage_dealer::Make_Event(_Dealer, 20.0f, GameplayTags::DamageType_Mars_Sever);
    }

    private void LatchFlinch()
    {
        if (_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Flinch)
        { _SawFlinch = true; }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDamageDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent)
    {
        _DealtZones.Add(InZone);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_AddAttacker(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Sweep = Make_SwingAtLeg0();

        auto Attacker = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Attacker, FTransform(FRotator::ZeroRotator, Sweep.Start), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Attacker, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _Dealer = utils_damage_dealer::Add(Attacker, FMars_DamageDealer_Spec());
        _Dealer.BindTo_OnDamageDealt(FMars_Delegate_DamageDealer_OnDamageDealt(this, n"OnDamageDealt"));

        Assert_True(ck::IsValid(_Dealer), "the attacker has a DamageDealer");
        Assert_Equals_Float(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), 120.0f, 0.001f, "the body starts at 120");
    }

    // One swing every 0.5 s while leg 0 is attached and the previous swept hit has landed on its Health.
    UFUNCTION()
    private void Check_StrikeUntilSevered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        LatchFlinch();

        auto Part = _Crawler.Get_LegParts()[0];
        if (Part.Get_State() == EMars_BodyPart_State::Severed)
        {
            _SeveredLeg = Part;
            Res.Set(true);
            return;
        }

        const auto Now = System::GetGameTimeInSeconds();
        const auto Landed = Math::IsNearlyEqual(Part.Get_Health().Get_Current(), Math::Max(30.0f - 20.0f * _SweepHits, 0.0f), 0.001f);
        const auto SwingDue = _LastSwingAt.IsSet() == false || Now - _LastSwingAt.GetValue() >= k_SwingInterval;
        if (Landed == false || SwingDue == false)
        { return; }

        if (_Swings >= k_MaxSwings)
        {
            FinishFailure(f"{_Swings} swings, {_SweepHits} swept hits, leg 0 at {Part.Get_Health().Get_Current()} and still attached");
            return;
        }

        ++_Swings;
        _LastSwingAt = Now;

        const auto Sweep = Make_SwingAtLeg0();
        const auto Result = utils_damage_dealer::Try_StrikeSweep(_Dealer, Sweep, Make_Swing20Sever());
        if (Result.Get_HitKind() != ECk_ProbeTrace_HitKind::Probe || ck::Is_NOT_Valid(Result.Get_HitEntity()))
        {
            ck::Trace(f"[StrikeE2E] swing [{_Swings}] from [{Sweep.Start.ToString()}] to [{Sweep.End.ToString()}] missed");
            return;
        }

        ++_SweepHits;
        const auto HitZone = utils_hit_zone::TryGet_Zone(Result.Get_HitEntity());
        if (HitZone != Part.Get_Zone())
        { FinishFailure(f"swing [{_Swings}] hit [{Result.Get_HitEntity().ToString()}] whose zone [{HitZone.ToString()}] is not leg 0's"); }
    }

    UFUNCTION()
    private void Check_FlinchedThenRoams(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        LatchFlinch();
        Res.Set(_SawFlinch && _Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam);
    }

    UFUNCTION()
    private void Step_AssertEndToEnd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Parts = _Crawler.Get_LegParts();
        const auto LegZone = Parts[0].Get_Zone();

        Assert_Equals_Int(_SweepHits, 2, "two swept hits severed the 30 HP leg");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 2, "the dealer forwarded both");
        Assert_Equals_Int(_Dealer.Get_HitsRejected(), 0, "the dealer rejected nothing (team One vs Two)");
        Assert_Equals_Int(_DealtZones.Num(), 2, "OnDamageDealt fired per hit");
        for (int32 Index = 0; Index < _DealtZones.Num(); ++Index)
        { Assert_True(_DealtZones[Index] == LegZone, f"dealt hit [{Index}] went to leg 0's zone"); }

        Assert_True(_SawFlinch, "the first hit made the crawler flinch");
        Assert_True(Parts[0].Get_Health().Get_IsDepleted(), "leg 0's Health is depleted");
        Assert_True(Parts[0].Get_Condition() == EMars_BodyPart_Condition::Damaged,
            f"Sever damages, it does not ruin (got {Parts[0].Get_Condition() :n})");
        for (int32 Index = 1; Index < Parts.Num(); ++Index)
        {
            Assert_True(Parts[Index].Get_State() == EMars_BodyPart_State::Attached,
                f"leg [{Index}] is still attached (got {Parts[Index].Get_State() :n})");
        }

        Assert_Equals_Float(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), 100.0f, 0.001f,
            "the body took 0.5 x 20 spill per hit");
        Assert_Equals_Int(utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait()), 3, "the gait walks on 3 legs");
        Assert_True(_Crawler.Get_Brain().Get_Fact(GameplayTags::Mars_WS_Crawler_CanWalk), "CanWalk holds at 3 of MinLegsToWalk 3");
        Assert_False(_Crawler.Get_Monster().Get_IsDead(), "the crawler is alive");
    }

    UFUNCTION()
    private void Check_SeveredLegGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_SeveredLeg));
    }
}
