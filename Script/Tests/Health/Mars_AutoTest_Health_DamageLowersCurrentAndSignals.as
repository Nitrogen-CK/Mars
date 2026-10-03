// The basic contract: the spec rejects a non-positive Max and a Start above Max; a fresh Health reads full; one hit of 30
// lowers it to 70, fires OnDamaged once with Applied 30 / Remaining 70, records the hit as LastHit and does not deplete.
class UMars_AutoTest_Health_DamageLowersCurrentAndSignals : UCk_AutoTest_Base
{
    private FCk_Handle_Health _Health;

    private TArray<FMars_DamageEvent> _DamagedEvents;
    private TArray<float32> _DamagedApplied;
    private TArray<float32> _DamagedRemaining;
    private int32 _DepletedCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Entity, FMars_Health_Spec(100.0f));

        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDamaged"));
        _Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));

        Add_Step("the spec rules hold and a fresh Health reads full; hit it for 30", n"Step_ValidateAndHit");
        Add_Step_WaitUntil("Health reads 70", n"Check_At70", 0, 2.0f);
        Add_Step("one OnDamaged (30 applied, 70 left), LastHit recorded, not depleted", n"Step_AssertDamaged");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _DamagedEvents.Add(InEvent);
        _DamagedApplied.Add(InApplied);
        _DamagedRemaining.Add(InRemaining);
    }

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        ++_DepletedCount;
    }

    UFUNCTION()
    private void Step_ValidateAndHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(FMars_Health_Spec(0.0f).Validate().IsValid, "a Max of 0 is rejected");
        Assert_False(FMars_Health_Spec(100.0f, 150.0f).Validate().IsValid, "a Start above Max is rejected");
        Assert_True(FMars_Health_Spec(100.0f).Validate().IsValid, "a Max of 100 is accepted");

        Assert_True(ck::IsValid(_Health), "the Health composed");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.001f, "a fresh Health starts at Max");
        Assert_Equals_Float(_Health.Get_Max(), 100.0f, 0.001f, "Max is the spec's");
        Assert_False(_Health.Get_LastHit().IsSet(), "no LastHit before any hit");

        auto Event = FMars_DamageEvent(30.0f, GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Sever"));
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Event));
    }

    UFUNCTION()
    private void Check_At70(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 70.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertDamaged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DamagedEvents.Num(), 1, "OnDamaged fired once");
        Assert_Equals_Float(_DamagedApplied[0], 30.0f, 0.001f, "OnDamaged reports 30 applied");
        Assert_Equals_Float(_DamagedRemaining[0], 70.0f, 0.001f, "OnDamaged reports 70 remaining");
        Assert_True(_DamagedEvents[0].DamageType == GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Sever"), "OnDamaged carries the event's damage type");

        const auto LastHit = _Health.Get_LastHit();
        Assert_True(LastHit.IsSet(), "LastHit is recorded");
        Assert_Equals_Float(LastHit.GetValue().Amount, 30.0f, 0.001f, "LastHit is the 30 hit");

        Assert_False(_Health.Get_IsDepleted(), "70 of 100 is not depleted");
        Assert_Equals_Int(_DepletedCount, 0, "OnDepleted did not fire");
    }
}
