// Healing: a hit of 60 leaves 40; a heal of 25 raises it to 65 (OnHealed 25 / 65); a heal of 1000 stops at Max and
// reports only the 35 it actually added (OnHealed 35 / 100).
class UMars_AutoTest_Health_HealRaisesCurrentAndClampsAtMax : UCk_AutoTest_Base
{
    private FCk_Handle_Health _Health;

    private TArray<float32> _HealedApplied;
    private TArray<float32> _HealedRemaining;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Entity, FMars_Health_Spec(100.0f));
        _Health.BindTo_OnHealed(FMars_Delegate_Health_OnHealed(this, n"OnHealed"));

        Add_Step("hit the Health for 60", n"Step_Hit");
        Add_Step_WaitUntil("Health reads 40", n"Check_At40", 0, 2.0f);
        Add_Step("heal 25", n"Step_HealSmall");
        Add_Step_WaitUntil("Health reads 65", n"Check_At65", 0, 2.0f);
        Add_Step("OnHealed reported 25 / 65; heal 1000", n"Step_AssertSmallAndHealHuge");
        Add_Step_WaitUntil("Health reads 100", n"Check_At100", 0, 2.0f);
        Add_Step("the huge heal stopped at Max and reported 35 / 100", n"Step_AssertClamped");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnHealed(FCk_Handle_Health InHealth, float32 InApplied, float32 InRemaining)
    {
        _HealedApplied.Add(InApplied);
        _HealedRemaining.Add(InRemaining);
    }

    UFUNCTION()
    private void Step_Hit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Health), "the Health composed");
        auto Event = FMars_DamageEvent(60.0f, GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Crush"));
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Event));
    }

    UFUNCTION()
    private void Check_At40(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 40.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_HealSmall(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HealedApplied.Num(), 0, "no OnHealed before any heal");
        _Health.Request_Heal(FMars_Request_Health_Heal(25.0f));
    }

    UFUNCTION()
    private void Check_At65(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 65.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertSmallAndHealHuge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HealedApplied.Num(), 1, "OnHealed fired once");
        Assert_Equals_Float(_HealedApplied[0], 25.0f, 0.001f, "the heal applied 25");
        Assert_Equals_Float(_HealedRemaining[0], 65.0f, 0.001f, "the heal left 65");

        _Health.Request_Heal(FMars_Request_Health_Heal(1000.0f));
    }

    UFUNCTION()
    private void Check_At100(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 100.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertClamped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HealedApplied.Num(), 2, "OnHealed fired once per heal");
        Assert_Equals_Float(_HealedApplied[1], 35.0f, 0.001f, "the huge heal reports only the 35 it added");
        Assert_Equals_Float(_HealedRemaining[1], 100.0f, 0.001f, "the huge heal left Max");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.001f, "Health reads Max");
    }
}
