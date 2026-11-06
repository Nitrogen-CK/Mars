// The bat is killed the moment it commits a swoop: the swoop ends Died and deals nothing, the body zone is disabled, the
// crowd agent leaves the crowd, it falls (Falling) and comes to rest on the floor (Landed), its roost is released exactly
// once, and the corpse despawns after CorpseSeconds without a second release.
class UMars_AutoTest_Bat_DeathDuringSwoopCancelsAttack : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -168000.0, 2000.0);

    private FCk_Handle_Monster _Monster;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        _Spec.Monster.CorpseSeconds = 1.5f;
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("it commits a swoop", n"Check_Committed", 0, k_FlightSeconds);
        Add_Step("a lethal blow lands on it", n"Step_Kill");
        Add_Step_WaitUntil("it is dead and has landed", n"Check_Landed", 0, 10.0f);
        Add_Step("the attack died with it", n"Step_AssertDead");
        Add_Step_WaitUntil("the corpse despawns", n"Check_Despawned", 0, 6.0f);
        Add_Step("the roost was released once", n"Step_AssertReleasedOnce");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Committed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Bat) && _Bat.Get_IsSwoopCommitted());
    }

    UFUNCTION()
    private void Step_Kill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Monster = _Bat.Get_Monster();
        auto Health = _Monster.Get_BodyHealth();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(100000.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_IsDead() && _Bat.Get_Phase() == EMars_Bat_Phase::Landed);
    }

    UFUNCTION()
    private void Step_AssertDead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Cancels.Contains(EMars_Bat_SwoopCancel::Died), "the committed swoop ended Died");
        Assert_Equals_Int(_TargetDamaged, 0, "the swoop dealt nothing");
        Assert_Equals_Int(_Landed.Num(), 0, "no swoop landed");
        Assert_True(_Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::None, "no swoop runs");
        Assert_False(_Monster.Get_BodyZone().Get_IsEnabled(), "the body zone is disabled");
        Assert_False(utils_crowd_agent::Get_IsEnabled(_Bat.Get_Agent()), "the crowd agent left the crowd");
        Assert_True(Get_SawInOrder(Get_FallOrder()), f"it fell, then landed (saw {Get_PhaseTrail()})");
        const auto Height = _Bat.Get_Location().Z - _Origin.Z;
        Assert_True(Math::Abs(Height) <= 30.0, f"it rests on the floor ({Height} uu over it)");
        Assert_True(_Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Released, "its claim reads Released");
        const auto Roost = utils_bat::Get_RoostState(_Roost);
        Assert_Equals_Int(Roost.ReleaseCount, 1, "the roost was released once");
        Assert_True(Roost.Occupancy == EMars_BatRoost_Occupancy::Free, "the roost is free");
    }

    private TArray<EMars_Bat_Phase> Get_FallOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Swooping);
        Order.Add(EMars_Bat_Phase::Falling);
        Order.Add(EMars_Bat_Phase::Landed);
        return Order;
    }

    UFUNCTION()
    private void Check_Despawned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        FCk_Handle Entity = _Bat;
        Res.Set(ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    UFUNCTION()
    private void Step_AssertReleasedOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Roost = utils_bat::Get_RoostState(_Roost);
        Assert_Equals_Int(Roost.ReleaseCount, 1, "the despawn did not release the roost a second time");
        Assert_Equals_Int(Roost.ClaimCount, 1, "it was claimed once");
        Assert_Equals_Int(_TargetDamaged, 0, "nothing was dealt after death");
    }
}
