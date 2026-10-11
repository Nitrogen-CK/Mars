// Try_StrikeSweep skips the dealer's own hurtboxes and the sweep's IgnoredEntities: a dealer that is itself a zone swings
// through its own hurtbox (a child entity, which the trace's own-entity skip does not cover) and then through a decoy
// hurtbox listed in IgnoredEntities, and lands on the target's hurtbox behind both (10 Blunt, 90 left; the dealer's own
// Health and the decoy's untouched; nothing rejected). The three-argument Sweep constructor leaves IgnoredEntities empty.
// Runs in its own band (Y -43000, Z 300) so no other test's hurtbox is in the sweep.
class UMars_AutoTest_DamageDealer_SweepIgnoresOwnHurtboxes : UCk_AutoTest_Base
{
    // Probes join the physics world deferred, which can outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle _Self;
    private FCk_Handle_DamageDealer _Dealer;
    private FCk_Handle_Health _DealerHealth;
    private FCk_Handle _OwnHurtbox;
    private FCk_Handle_Health _DecoyHealth;
    private FCk_Handle _DecoyHurtbox;
    private FCk_Handle_Health _TargetHealth;
    private FCk_Handle _TargetHurtbox;
    private FCk_ShapeCast_Result _Result;

    private FVector _Origin = FVector(0.0, -43000.0, 300.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Self = InHandle;

        auto Attacker = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto AttackerRoot = utils_transform::Add(Attacker, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Attacker, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _DealerHealth = utils_health::Add(Attacker, FMars_Health_Spec(100.0f));
        auto OwnZone = utils_hit_zone::Add(Attacker, FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body));
        _OwnHurtbox = utils_hit_zone::AddHurtbox_Box(OwnZone, AttackerRoot, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 20.0), FTransform::Identity));
        _Dealer = utils_damage_dealer::Add(Attacker, FMars_DamageDealer_Spec());

        SpawnVictim(InHandle, _Origin + FVector(100.0, 0.0, 0.0), true);
        SpawnVictim(InHandle, _Origin + FVector(200.0, 0.0, 0.0), false);

        Add_Step("the three-argument Sweep constructor ignores nothing", n"Step_AssertConstructor");
        Add_Step_WaitUntil("all three hurtboxes are in the physics world", n"Check_AllTraceable", k_SlowPolls, 0);
        Add_Step("swing through the own hurtbox and the decoy", n"Step_Swing");
        Add_Step_WaitUntil("the target's Health reads 90", n"Check_TargetAt90", k_SlowPolls, 0);
        Add_Step("only the target was hit", n"Step_AssertOnlyTarget");
        Run_Steps(InHandle);
    }

    private void SpawnVictim(FCk_Handle InHandle, FVector InLocation, bool InIsDecoy)
    {
        auto Victim = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Victim, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Victim, ECk_Team_ID::Two, ECk_Replication::DoesNotReplicate);
        auto Health = utils_health::Add(Victim, FMars_Health_Spec(100.0f));
        auto Zone = utils_hit_zone::Add(Victim, FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body));
        auto Hurtbox = utils_hit_zone::AddHurtbox_Box(Zone, Root, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 20.0), FTransform::Identity));
        if (InIsDecoy)
        {
            _DecoyHealth = Health;
            _DecoyHurtbox = Hurtbox;
            return;
        }

        _TargetHealth = Health;
        _TargetHurtbox = Hurtbox;
    }

    private FMars_DamageDealer_Sweep Make_Swing()
    {
        auto Sweep = FMars_DamageDealer_Sweep(_Origin + FVector(-100.0, 0.0, 0.0), _Origin + FVector(300.0, 0.0, 0.0), 10.0f);
        Sweep.IgnoredEntities.Add(_DecoyHurtbox);
        return Sweep;
    }

    // The first hurtbox a plain sweep (nothing ignored) from InStartX along the swing's line reports.
    private FCk_Handle FirstHurtboxFrom(float64 InStartX)
    {
        auto Settings = FCk_ShapeCast_Settings(_Origin + FVector(InStartX, 0.0, 0.0), _Origin + FVector(300.0, 0.0, 0.0),
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(10.0f)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        return utils_probe_trace::Request_SingleShapeTrace(_Self, Settings).Get_HitEntity();
    }

    UFUNCTION()
    private void Step_AssertConstructor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Sweep = FMars_DamageDealer_Sweep(FVector::ZeroVector, FVector(100.0, 0.0, 0.0), 25.0f);
        Assert_Equals_Int(Sweep.IgnoredEntities.Num(), 0, "IgnoredEntities defaults to empty");
        Assert_Equals_Float(Sweep.Radius, 25.0f, 0.001f, "the constructor still sets the radius");
    }

    UFUNCTION()
    private void Check_AllTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(FirstHurtboxFrom(-100.0) == _OwnHurtbox && FirstHurtboxFrom(50.0) == _DecoyHurtbox
            && FirstHurtboxFrom(150.0) == _TargetHurtbox);
    }

    UFUNCTION()
    private void Step_Swing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Template = utils_damage_dealer::Make_Event(_Dealer, 10.0f, GameplayTags::DamageType_Mars_Blunt);
        _Result = utils_damage_dealer::Try_StrikeSweep(_Dealer, Make_Swing(), Template);
    }

    UFUNCTION()
    private void Check_TargetAt90(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_TargetHealth.Get_Current(), 90.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertOnlyTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Result.Get_HitEntity() == _TargetHurtbox, "the swing hit the target's hurtbox");
        Assert_Equals_Float(_DealerHealth.Get_Current(), 100.0f, 0.001f, "the dealer's own Health is untouched");
        Assert_Equals_Float(_DecoyHealth.Get_Current(), 100.0f, 0.001f, "the ignored decoy is untouched");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the dealer dealt one hit");
        Assert_Equals_Int(_Dealer.Get_HitsRejected(), 0, "nothing was rejected");
    }
}
