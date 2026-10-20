// The player's own hurtbox never intercepts the player's swing: a real Request_StrikeSweep from the
// production pawn's dealer, starting behind the pawn and travelling along its forward through its own hurtbox, hits a
// hostile dummy's hurtbox ahead (10 Blunt lands, the player's Health is untouched, nothing is rejected as friendly).
// With a static Jolt wall between the pawn and the dummy, the same swing stops at the wall. Isolated origin
// (-205000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_PlayerStrikeSelfExclusion : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-205000.0, 210000.0, 8000.0);

    private FCk_Handle_Health _DummyHealth;
    private FCk_Handle _DummyHurtbox;
    private FCk_Handle _Wall;
    private FCk_ShapeCast_Result _Result;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndPlayer(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("the local player composed its combat receiver", n"Step_AssertLocalReceiver");
        Add_Step_WaitUntil("the hurtbox probe is in the physics world", n"Check_HurtboxTraceable", k_SlowPolls, 0);
        Add_Step("put a hostile dummy 150 ahead of the pawn", n"Step_SpawnDummy");
        Add_Step_WaitUntil("the dummy's hurtbox is in the physics world", n"Check_DummyTraceable", k_SlowPolls, 0);
        Add_Step("the swing through the player's own hurtbox", n"Step_Swing");
        Add_Step_WaitUntil("the dummy's Health reads 90", n"Check_DummyAt90", k_SlowPolls, 0);
        Add_Step("only the dummy was hurt; put a wall between", n"Step_AssertDummyHitAndWall");
        Add_Step_WaitUntil("the wall is in the physics world", n"Check_WallTraceable", k_SlowPolls, 0);
        Add_Step("the swing again", n"Step_Swing");
        // Deliberately a fixed window: a blocked swing deals nothing, so there is no event to wait on.
        Add_Step_WaitSeconds("let any damage request drain", 0.3f);
        Add_Step("the wall stopped the swing", n"Step_AssertWallBlocked");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    private FVector Forward() const
    {
        return _Pawn.GetActorForwardVector();
    }

    // From 120 behind the capsule's centre (clear of the capsule and the sphere) to 300 ahead of it.
    private FMars_DamageDealer_Sweep Make_Swing() const
    {
        const auto Centre = PawnLocation();
        return FMars_DamageDealer_Sweep(Centre - Forward() * 120.0, Centre + Forward() * 300.0, 10.0f);
    }

    UFUNCTION()
    private void Step_SpawnDummy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Dummy = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Dummy, FTransform(FRotator::ZeroRotator, PawnLocation() + Forward() * 150.0), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Dummy, ECk_Team_ID::Two, ECk_Replication::DoesNotReplicate);
        _DummyHealth = utils_health::Add(Dummy, FMars_Health_Spec(100.0f));
        auto Zone = utils_hit_zone::Add(Dummy, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        _DummyHurtbox = utils_hit_zone::AddHurtbox_Box(Zone, Root, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 40.0), FTransform::Identity));
    }

    UFUNCTION()
    private void Check_DummyTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Swing = Make_Swing();
        auto Settings = FCk_ShapeCast_Settings(Swing.Start + Forward() * 200.0, Swing.End,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(Swing.Radius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);

        auto Res = OutResult;
        Res.Set(ck::IsValid(_DummyHurtbox) && utils_probe_trace::Request_SingleShapeTrace(_Self, Settings).Get_HitEntity() == _DummyHurtbox);
    }

    UFUNCTION()
    private void Step_Swing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Dealer = _Player.As_DamageDealer();
        auto Template = utils_damage_dealer::Make_Event(Dealer, 10.0f, GameplayTags::DamageType_Mars_Blunt);
        _Result = Dealer.Request_StrikeSweep(Make_Swing(), Template);
    }

    UFUNCTION()
    private void Check_DummyAt90(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_DummyHealth.Get_Current(), 90.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertDummyHitAndWall(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hit = _Result.Get_HitEntity();
        Assert_True(Hit == _DummyHurtbox, "the swing hit the dummy's hurtbox");
        Assert_True(Hit != Get_Hurtbox(), "the swing did not hit the player's own hurtbox");
        Assert_Equals_Float(Get_Health().Get_Current(), 100.0f, 0.001f, "the player's Health is untouched");

        const auto Dealer = _Player.As_DamageDealer();
        Assert_Equals_Int(Dealer.Get_HitsDealt(), 1, "the dealer dealt one hit");
        Assert_Equals_Int(Dealer.Get_HitsRejected(), 0, "nothing was rejected as friendly");

        _Wall = SpawnJoltWall(PawnLocation() + Forward() * 90.0, FVector(5.0, 80.0, 120.0));
    }

    UFUNCTION()
    private void Check_WallTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Swing = Make_Swing();
        auto Settings = FCk_ShapeCast_Settings(Swing.Start + Forward() * 170.0, Swing.End,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(Swing.Radius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_WorldHitPolicy(ECk_ProbeTrace_WorldHitPolicy::Blocking);
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);

        auto Res = OutResult;
        Res.Set(utils_probe_trace::Request_SingleShapeTrace(_Self, Settings).Get_HitKind() == ECk_ProbeTrace_HitKind::World);
    }

    UFUNCTION()
    private void Step_AssertWallBlocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Result.Get_HitKind() == ECk_ProbeTrace_HitKind::World, f"the swing stopped at the wall (hit kind {_Result.Get_HitKind() :n})");
        Assert_True(_Result.Get_HitEntity() != _DummyHurtbox, "the swing did not reach the dummy");
        Assert_Equals_Float(_DummyHealth.Get_Current(), 90.0f, 0.001f, "the dummy took no second hit");
        Assert_Equals_Int(_Player.As_DamageDealer().Get_HitsDealt(), 1, "the dealer dealt nothing more");
    }
}

class AMars_AutoTest_PlayerCombat_PlayerStrikeSelfExclusion_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_PlayerStrikeSelfExclusion;
}
