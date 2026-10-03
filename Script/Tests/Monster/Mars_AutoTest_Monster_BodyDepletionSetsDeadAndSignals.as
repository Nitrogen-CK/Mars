// Body depletion kills the monster once: 200 Blunt on the crawler's body zone depletes its 120 body Health, the monster
// reads IsDead with the hit as its DeathCause, ByteAttribute.Mars.Monster.Dead reads 1 and OnDied fires once. A second
// lethal hit and a direct Die request change nothing (still one OnDied, the first cause kept). The monster's drain sheds
// nothing itself; the crawler HFSM's Dead state does (all 4 legs severed), and the severed limbs - world-owned, debris
// lifetime 1.0 s here - die on their own timer inside the test.
//
// Isolated origin (130000, 96000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_Monster_BodyDepletionSetsDeadAndSignals : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FVector _Origin = FVector(130000.0, 96000.0, 600.0);
    private FCk_Handle_Crawler _Crawler;

    private TArray<FMars_DamageEvent> _DiedCauses;
    private TArray<FCk_Handle_BodyPart> _Legs;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", 0, 10.0f);
        Add_Step("bind OnDied; hit the body zone with 200 Blunt", n"Step_BindAndKill");
        Add_Step_WaitUntil("the monster is dead and the Dead attribute reads 1", n"Check_Dead", 0, 2.0f);
        Add_Step("one OnDied with the lethal hit; hit again and request Die directly", n"Step_AssertDiedAndKillAgain");
        Add_Step_WaitFrames("let the second hit and the direct Die drain", 10);
        Add_Step("still one OnDied, the first cause kept", n"Step_AssertLatched");
        Add_Step_WaitUntil("the Dead state shed every leg and the severed limbs died on their timer", n"Check_LegsShedAndGone", 0, 3.0f);
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        const auto Half = FVector(400.0, 400.0, 200.0);
        auto Spec = FMars_Crawler_Spec(4, FBox(_Origin - Half, _Origin + Half));
        // The Dead state severs every leg; the world-owned limbs must die before the test ends (no leak).
        Spec.Vitals.LegDebris.LifetimeSeconds = 1.0f;
        return Spec;
    }

    private void SpawnFloorAndCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(1500.0, 1500.0, 10.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        auto SpawnParams = UMars_Crawler_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        SpawnParams.Spec = InSpec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Crawler_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnCrawlerConstructed"));
    }

    UFUNCTION()
    private void OnCrawlerConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Crawler = InEntityScriptHandle.As_Crawler();
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Crawler))
        {
            Res.Set(false);
            return;
        }

        const auto Gait = _Crawler.Get_Gait();
        if (utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Failed)
        {
            FinishFailure(f"the crawler's gait failed: {utils_procedural_gait::Get_Failure(Gait) :n}");
            return;
        }

        Res.Set(utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Ready &&
            _Crawler.Get_Monster().Get_Parts().Num() == 4);
    }

    UFUNCTION()
    private void OnDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        _DiedCauses.Add(InCause);
    }

    private FMars_DamageEvent Make_Hit(float32 InAmount, float32 InMarkerX)
    {
        auto Event = FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Blunt);
        Event.Hit.Location = FVector(InMarkerX, 0.0, 0.0);
        return Event;
    }

    UFUNCTION()
    private void Step_BindAndKill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Monster = _Crawler.Get_Monster();
        Assert_Equals_Int(int32(Monster.Get_DeadAttribute().Get_FinalValue()), 0, "the Dead attribute starts at 0");

        Monster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnDied"));

        _Legs = Monster.Get_Parts();

        auto Zone = Monster.Get_BodyZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(Make_Hit(200.0f, 1.0f)));
    }

    UFUNCTION()
    private void Check_Dead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Monster = _Crawler.Get_Monster();
        auto Res = OutResult;
        Res.Set(Monster.Get_IsDead() && Monster.Get_DeadAttribute().Get_FinalValue() == 1);
    }

    UFUNCTION()
    private void Step_AssertDiedAndKillAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Monster = _Crawler.Get_Monster();
        Assert_Equals_Int(_DiedCauses.Num(), 1, "OnDied fired once");
        if (_DiedCauses.Num() == 1)
        { Assert_Equals_Float(_DiedCauses[0].Amount, 200.0f, 0.001f, "OnDied carries the lethal hit"); }

        const auto DeathCause = Monster.Get_DeathCause();
        Assert_True(DeathCause.IsSet(), "the death cause is recorded");
        if (DeathCause.IsSet())
        { Assert_Equals_Float(DeathCause.GetValue().Hit.Location.X, 1.0f, 0.001f, "the death cause is the lethal hit"); }

        Assert_True(Monster.Get_BodyHealth().Get_IsDepleted(), "the body Health is depleted");

        auto Zone = Monster.Get_BodyZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(Make_Hit(200.0f, 2.0f)));
        Monster.Request_Die(FMars_Request_Monster_Die(Make_Hit(1.0f, 3.0f)));
    }

    UFUNCTION()
    private void Step_AssertLatched(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Monster = _Crawler.Get_Monster();
        Assert_Equals_Int(_DiedCauses.Num(), 1, "still one OnDied");
        Assert_True(Monster.Get_IsDead(), "the monster stays dead");

        const auto DeathCause = Monster.Get_DeathCause();
        Assert_True(DeathCause.IsSet(), "the death cause is still recorded");
        if (DeathCause.IsSet())
        { Assert_Equals_Float(DeathCause.GetValue().Hit.Location.X, 1.0f, 0.001f, "the first cause is kept"); }

        Assert_Equals_Int(int32(Monster.Get_DeadAttribute().Get_FinalValue()), 1, "the Dead attribute stays 1");
    }

    UFUNCTION()
    private void Check_LegsShedAndGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Legs.Num() != 4)
        {
            FinishFailure(f"[{_Legs.Num()}] legs were recorded, not 4");
            return;
        }

        for (const auto& Leg : _Legs)
        {
            if (ck::IsValid(Leg))
            { return; }
        }

        Res.Set(_Crawler.Get_Monster().Get_AttachedPartCount() == 0);
    }
}
