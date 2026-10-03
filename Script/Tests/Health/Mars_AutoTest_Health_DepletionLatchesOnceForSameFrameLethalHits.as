// Same-frame lethal hits: two hits of 80 queued in one step land in one drain against 100. The first applies 80, the
// second is clamped to the remaining 20 and crosses zero, so OnDamaged fires twice (80 then 20), OnDepleted fires exactly
// once, and LastHit is the second hit. A further hit on the depleted Health is ignored (no signal at all).
//
// The ignored hit has no observable of its own, so a sentinel Health takes a hit in the same step: both entities drain in
// the same processor pass, so the sentinel's OnDamaged proves the depleted Health's drain has run.
class UMars_AutoTest_Health_DepletionLatchesOnceForSameFrameLethalHits : UCk_AutoTest_Base
{
    private FCk_Handle_Health _Health;
    private FCk_Handle_Health _Sentinel;

    private TArray<FMars_DamageEvent> _DamagedEvents;
    private TArray<float32> _DamagedApplied;
    private TArray<FMars_DamageEvent> _DepletedCauses;
    private int32 _SentinelDamagedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Entity, FMars_Health_Spec(100.0f));
        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDamaged"));
        _Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));

        auto SentinelEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Sentinel = utils_health::Add(SentinelEntity, FMars_Health_Spec(100.0f));
        _Sentinel.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnSentinelDamaged"));

        Add_Step("queue two hits of 80 in one frame", n"Step_TwoLethalHits");
        Add_Step_WaitUntil("Health is depleted and reads 0", n"Check_Depleted", 0, 2.0f);
        Add_Step("one depletion, two OnDamaged (80, 20), LastHit is the second; hit the depleted Health again", n"Step_AssertAndHitAgain");
        Add_Step_WaitUntil("the sentinel's hit drained", n"Check_SentinelDrained", 0, 2.0f);
        Add_Step("the hit on the depleted Health was ignored", n"Step_AssertIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _DamagedEvents.Add(InEvent);
        _DamagedApplied.Add(InApplied);
    }

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        _DepletedCauses.Add(InCause);
    }

    UFUNCTION()
    private void OnSentinelDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        ++_SentinelDamagedCount;
    }

    private FMars_DamageEvent Make_Hit(float32 InAmount, float32 InMarkerX)
    {
        auto Event = FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever);
        Event.Hit.Location = FVector(InMarkerX, 0.0f, 0.0f);
        return Event;
    }

    UFUNCTION()
    private void Step_TwoLethalHits(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Health, "utils_health::Add composed the Health");
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Make_Hit(80.0f, 1.0f)));
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Make_Hit(80.0f, 2.0f)));
    }

    UFUNCTION()
    private void Check_Depleted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Health.Get_IsDepleted() && Math::IsNearlyEqual(_Health.Get_Current(), 0.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertAndHitAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DepletedCauses.Num(), 1, "OnDepleted fired exactly once for two same-frame lethal hits");
        if (_DepletedCauses.Num() == 1)
        { Assert_Equals_Float(_DepletedCauses[0].Hit.Location.X, 2.0f, 0.001f, "OnDepleted carries the hit that crossed zero (the second)"); }

        Assert_Equals_Int(_DamagedEvents.Num(), 2, "OnDamaged fired once per hit");
        if (_DamagedEvents.Num() == 2)
        {
            Assert_Equals_Float(_DamagedApplied[0], 80.0f, 0.001f, "the first hit applied 80");
            Assert_Equals_Float(_DamagedApplied[1], 20.0f, 0.001f, "the second hit was clamped to the remaining 20");
        }

        const auto LastHit = _Health.Get_LastHit();
        Assert_True(LastHit.IsSet(), "LastHit is recorded");
        if (LastHit.IsSet())
        { Assert_Equals_Float(LastHit.GetValue().Hit.Location.X, 2.0f, 0.001f, "LastHit is the second hit"); }

        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Make_Hit(10.0f, 3.0f)));
        _Sentinel.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Make_Hit(10.0f, 4.0f)));
    }

    UFUNCTION()
    private void Check_SentinelDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SentinelDamagedCount > 0);
    }

    UFUNCTION()
    private void Step_AssertIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DepletedCauses.Num(), 1, "no further OnDepleted");
        Assert_Equals_Int(_DamagedEvents.Num(), 2, "no OnDamaged for a hit on a depleted Health");
        Assert_True(_Health.Get_IsDepleted(), "the Health stays depleted");

        const auto LastHit = _Health.Get_LastHit();
        Assert_True(LastHit.IsSet(), "LastHit is still recorded");
        if (LastHit.IsSet())
        { Assert_Equals_Float(LastHit.GetValue().Hit.Location.X, 2.0f, 0.001f, "LastHit still names the lethal hit"); }
    }
}
