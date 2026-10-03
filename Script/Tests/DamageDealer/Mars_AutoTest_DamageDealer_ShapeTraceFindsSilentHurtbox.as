// The strike's sweep finds a hurtbox: a sphere ProbeTrace filtered on Probe.Mars.HitZone (Blocking world policy, Silent
// overlap notify - the strike's settings) reports the Silent, Kinematic hurtbox probe as a Probe hit whose entity resolves
// to the zone, and feeding that hit entity to a dealer lands the damage (90 left). The design's E2 risk probe: a sweep
// that skips Silent probes never reports the hit and the wait below times out.
//
// Runs in its own band (Y -41000, Z 300) so no other test's hurtbox is in the sweep.
class UMars_AutoTest_DamageDealer_ShapeTraceFindsSilentHurtbox : UCk_AutoTest_Base
{
    private FCk_Handle _Self;
    private FCk_Handle_Health _Health;
    private FCk_Handle_HitZone _Zone;
    private FCk_Handle _Hurtbox;
    private FCk_Handle_DamageDealer _Dealer;

    private FCk_ShapeCast_Result _Result;

    private FVector _Origin = FVector(0.0, -41000.0, 300.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Self = InHandle;

        auto Target = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Target, FMars_Health_Spec(100.0f));
        _Zone = utils_hit_zone::Add(Target, FMars_HitZone_Spec(GameplayTags::ResolveGameplayTag(n"HitZone.Mars.Body")));
        auto Root = utils_transform::Add(Target, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        _Hurtbox = utils_hit_zone::AddHurtbox_Box(_Zone, Root, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 20.0), FTransform::Identity));

        auto Attacker = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Attacker, FTransform(FRotator::ZeroRotator, _Origin + FVector(-200.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        _Dealer = utils_damage_dealer::Add(Attacker, FMars_DamageDealer_Spec());

        // Probes join the physics world deferred (and Get_IsEnabledDisabled reads Enable from Add on), so the wait sweeps
        // until the hurtbox is traceable.
        Add_Step_WaitUntil("a sweep through the hurtbox reports it", n"Check_SweepHits", 0, 3.0f);
        Add_Step("the hit is the Silent hurtbox and resolves to the zone; deal through it", n"Step_AssertHitAndDeal");
        Add_Step_WaitUntil("Health reads 90", n"Check_At90", 0, 2.0f);
        Add_Step("the swept hit was dealt", n"Step_AssertDealt");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SweepHits(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Settings = FCk_ShapeCast_Settings(
            _Origin + FVector(-200.0, 0.0, 0.0),
            _Origin + FVector(200.0, 0.0, 0.0),
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(25.0f)),
            GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Probe.Mars.HitZone")));
        Settings.Set_WorldHitPolicy(ECk_ProbeTrace_WorldHitPolicy::Blocking);
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);

        _Result = utils_probe_trace::Request_SingleShapeTrace(_Self, Settings);

        // A miss returns a default result: HitKind reads Probe, so the hit entity is what tells a hit apart.
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Result.Get_HitEntity()));
    }

    UFUNCTION()
    private void Step_AssertHitAndDeal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Result.Get_HitKind() == ECk_ProbeTrace_HitKind::Probe, "the sweep reports a Probe hit");
        Assert_True(_Result.Get_HitEntity() == _Hurtbox, "the hit entity is the hurtbox node");
        Assert_True(FCk_Handle(utils_hit_zone::TryGet_Zone(_Result.Get_HitEntity())) == FCk_Handle(_Zone),
            "the hit entity resolves to the zone");

        _Dealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(_Result.Get_HitEntity(),
            utils_damage_dealer::Make_Event(_Dealer, 10.0f, GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Blunt"))));
    }

    UFUNCTION()
    private void Check_At90(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 90.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertDealt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the dealer dealt the swept hit");
        Assert_Equals_Int(_Dealer.Get_HitsRejected(), 0, "nothing was rejected");
    }
}
