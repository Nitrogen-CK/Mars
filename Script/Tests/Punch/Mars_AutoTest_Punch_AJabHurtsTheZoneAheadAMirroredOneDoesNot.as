// A jab's blow is real damage, a mirrored jab's is not, and a wall stops a fist. A thrower with a DamageDealer and no
// PlayerViewpoint (its blows leave from its own transform, along +X) faces a hostile dummy 100 ahead, inside the blow's
// reach. A throw takes the blow's Damage off the dummy's Health, once, and OnBlow reports the dummy's hurtbox. A mirror of
// the other hand runs its jab and deals nothing (no OnBlow, the dummy untouched). With a static wall between them a
// second throw's blow reports the world and the dummy is untouched again. Isolated origin (-57000, 23000, 9000).
class UMars_AutoTest_Punch_AJabHurtsTheZoneAheadAMirroredOneDoesNot : UCk_AutoTest_Base
{
    // Probes join the physics world deferred, which can outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FVector _Origin = FVector(-57000.0, 23000.0, 9000.0);

    private FCk_Handle _Self;
    private FCk_Handle_Punch _Punch;
    private FCk_Handle_DamageDealer _Dealer;
    private FMars_Punch_Spec _Spec;
    private FCk_Handle_Health _DummyHealth;
    private FCk_Handle _DummyHurtbox;

    private TArray<EMars_Hand> _Blows;
    private TArray<FCk_ShapeCast_Result> _Hits;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Self = InHandle;

        // Slow enough that a jab spans several frames in a headless lane.
        _Spec.Rhythm.ImpactSeconds = 0.15f;
        _Spec.Rhythm.RecoverySeconds = 0.25f;
        _Spec.Rhythm.IntervalSeconds = 0.2f;
        _Spec.Rhythm.ComboSeconds = 5.0f;

        auto Thrower = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Thrower, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Thrower, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _Dealer = utils_damage_dealer::Add(Thrower, FMars_DamageDealer_Spec());
        _Punch = utils_punch::Add(Thrower, _Spec);
        _Punch.BindTo_OnBlow(FMars_Delegate_Punch_OnBlow(this, n"OnBlow"));

        auto Dummy = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto DummyRoot = utils_transform::Add(Dummy, FTransform(FRotator::ZeroRotator, _Origin + FVector(100.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Dummy, ECk_Team_ID::Two, ECk_Replication::DoesNotReplicate);
        _DummyHealth = utils_health::Add(Dummy, FMars_Health_Spec(100.0f));
        auto Zone = utils_hit_zone::Add(Dummy, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        _DummyHurtbox = utils_hit_zone::AddHurtbox_Box(Zone, DummyRoot, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 40.0), FTransform::Identity));

        Add_Step_WaitUntil("the dummy's hurtbox is in the physics world", n"Check_DummyTraceable", k_SlowPolls, 0);
        Add_Step("throw", n"Step_Throw");
        Add_Step_WaitUntil("the jab dealt its blow and came home", n"Check_OneBlowAndHome", k_SlowPolls, 0);
        Add_Step_WaitUntil("the dummy's Health took the blow", n"Check_DummyHurtOnce", k_SlowPolls, 0);
        Add_Step("one blow, on the dummy's hurtbox; mirror the other hand", n"Step_AssertHitAndMirror");
        Add_Step_WaitUntil("the mirrored jab ran and came home", n"Check_TwoThrownAndHome", k_SlowPolls, 0);
        // Deliberately a fixed window: a mirrored jab deals nothing, so there is no event to wait on.
        Add_Step_WaitSeconds("let any damage request drain", 0.3f);
        Add_Step("the mirrored jab dealt nothing; put a wall between", n"Step_AssertMirrorHarmlessAndWall");
        Add_Step_WaitUntil("the wall is in the physics world", n"Check_WallTraceable", k_SlowPolls, 0);
        Add_Step("throw again", n"Step_Throw");
        Add_Step_WaitUntil("the jab dealt its second blow and came home", n"Check_TwoBlowsAndHome", k_SlowPolls, 0);
        Add_Step_WaitSeconds("let any damage request drain", 0.3f);
        Add_Step("the wall stopped the fist", n"Step_AssertWallBlocked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnBlow(FCk_Handle_Punch InPunch, EMars_Hand InHand, FCk_ShapeCast_Result InHit)
    {
        _Blows.Add(InHand);
        _Hits.Add(InHit);
    }

    // The blow's own sweep, traced as the test entity: what it would meet first.
    private FCk_ShapeCast_Result TraceBlow()
    {
        const auto& Blow = _Spec.Blow;
        auto Settings = FCk_ShapeCast_Settings(_Origin, _Origin + FVector(Blow.Reach, 0.0, 0.0),
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(Blow.Radius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_WorldHitPolicy(ECk_ProbeTrace_WorldHitPolicy::Blocking);
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        return utils_probe_trace::Request_SingleShapeTrace(_Self, Settings);
    }

    private float32 Get_ExpectedHealth() const
    {
        return 100.0f - _Spec.Blow.Damage;
    }

    UFUNCTION()
    private void Check_DummyTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_DummyHurtbox) && TraceBlow().Get_HitEntity() == _DummyHurtbox);
    }

    UFUNCTION()
    private void Step_Throw(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    UFUNCTION()
    private void Check_OneBlowAndHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Blows.Num() >= 1 && _Punch.Get_IsPunching() == false);
    }

    UFUNCTION()
    private void Check_DummyHurtOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_DummyHealth.Get_Current(), Get_ExpectedHealth(), 0.001f));
    }

    UFUNCTION()
    private void Step_AssertHitAndMirror(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Blows.Num(), 1, "one throw dealt one blow");
        if (_Blows.Num() == 1)
        {
            Assert_True(_Blows[0] == EMars_Hand::Left, "the blow was the lead hand's, the left");
            Assert_True(_Hits[0].Get_HitEntity() == _DummyHurtbox, "the blow's sweep met the dummy's hurtbox");
        }

        Assert_Equals_Float(_DummyHealth.Get_Current(), Get_ExpectedHealth(), 0.001f, "the dummy lost the blow's Damage, once");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the dealer dealt one hit");
        Assert_Equals_Int(_Dealer.Get_HitsRejected(), 0, "nothing was rejected");

        _Punch.Request_Mirror(FMars_Request_Punch_Mirror(EMars_Hand::Right));
    }

    UFUNCTION()
    private void Check_TwoThrownAndHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 2 && _Punch.Get_IsPunching() == false);
    }

    UFUNCTION()
    private void Step_AssertMirrorHarmlessAndWall(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Punch.Get_JabsThrown(), 2, "the mirror was a jab");
        Assert_Equals_Int(_Blows.Num(), 1, "a mirrored jab deals no blow");
        Assert_Equals_Float(_DummyHealth.Get_Current(), Get_ExpectedHealth(), 0.001f, "the dummy took nothing from the mirrored jab");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the dealer dealt nothing more");
        Assert_True(_Punch.Get_NextHand() == EMars_Hand::Left, "after a mirrored right the next throw is the left");

        auto Wall = utils_entity_lifetime::Request_CreateEntity(_Self);
        utils_transform::Add(Wall, FTransform(FRotator::ZeroRotator, _Origin + FVector(50.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(5.0, 80.0, 120.0));
        auto WallSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        WallSpec.Set_ShapeDimensions(Shape);
        WallSpec.Set_MotionType(ECk_MotionType::Static);
        WallSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Wall, WallSpec);
    }

    UFUNCTION()
    private void Check_WallTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TraceBlow().Get_HitKind() == ECk_ProbeTrace_HitKind::World);
    }

    UFUNCTION()
    private void Check_TwoBlowsAndHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Blows.Num() >= 2 && _Punch.Get_IsPunching() == false);
    }

    UFUNCTION()
    private void Step_AssertWallBlocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Blows.Num(), 2, "the second throw dealt its blow");
        if (_Blows.Num() == 2)
        {
            Assert_True(_Hits[1].Get_HitKind() == ECk_ProbeTrace_HitKind::World, f"the blow stopped at the wall (hit kind {_Hits[1].Get_HitKind() :n})");
            Assert_True(_Hits[1].Get_HitEntity() != _DummyHurtbox, "the blow did not reach the dummy");
        }

        Assert_Equals_Float(_DummyHealth.Get_Current(), Get_ExpectedHealth(), 0.001f, "the dummy took no second hit");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the dealer dealt nothing more");
    }
}
