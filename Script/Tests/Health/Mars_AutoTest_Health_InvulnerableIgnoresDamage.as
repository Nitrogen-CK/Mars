// Invulnerability: SetInvulnerable(true) drains before the same frame's hit of 50, so the hit is ignored (no OnDamaged,
// still 100). After SetInvulnerable(false) the next hit of 50 lands (50 left).
class UMars_AutoTest_Health_InvulnerableIgnoresDamage : UCk_AutoTest_Base
{
    private FCk_Handle_Health _Health;

    private TArray<float32> _DamagedApplied;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Entity, FMars_Health_Spec(100.0f));
        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDamaged"));

        Add_Step("make the Health invulnerable and hit it for 50 in the same frame", n"Step_InvulnerableHit");
        // Deliberately a fixed window: an ignored hit has no signal to wait on.
        Add_Step_WaitSeconds("let the drain run", 0.2f);
        Add_Step("the hit was ignored; make it vulnerable and hit it for 50 again", n"Step_AssertIgnoredAndHitAgain");
        Add_Step_WaitUntil("Health reads 50", n"Check_At50", 0, 2.0f);
        Add_Step("the second hit landed", n"Step_AssertLanded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _DamagedApplied.Add(InApplied);
    }

    private FMars_Request_Health_ApplyDamage Make_Hit(float32 InAmount)
    {
        return FMars_Request_Health_ApplyDamage(FMars_DamageEvent(InAmount, GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Blunt")));
    }

    UFUNCTION()
    private void Step_InvulnerableHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Health), "the Health composed");
        _Health.Request_SetInvulnerable(FMars_Request_Health_SetInvulnerable(true));
        _Health.Request_ApplyDamage(Make_Hit(50.0f));
    }

    UFUNCTION()
    private void Step_AssertIgnoredAndHitAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Health.Get_IsInvulnerable(), "the Health is invulnerable");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.001f, "the invulnerable Health still reads 100");
        Assert_Equals_Int(_DamagedApplied.Num(), 0, "no OnDamaged while invulnerable");
        Assert_False(_Health.Get_LastHit().IsSet(), "an ignored hit is not recorded");

        _Health.Request_SetInvulnerable(FMars_Request_Health_SetInvulnerable(false));
        _Health.Request_ApplyDamage(Make_Hit(50.0f));
    }

    UFUNCTION()
    private void Check_At50(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 50.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Health.Get_IsInvulnerable(), "the Health is vulnerable again");
        Assert_Equals_Int(_DamagedApplied.Num(), 1, "OnDamaged fired once, for the vulnerable hit");
        Assert_Equals_Float(_DamagedApplied[0], 50.0f, 0.001f, "the vulnerable hit applied 50");
    }
}
