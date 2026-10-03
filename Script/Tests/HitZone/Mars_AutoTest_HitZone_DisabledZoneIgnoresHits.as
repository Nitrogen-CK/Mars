// A disabled zone ignores hits: SetEnabled(false) drains before the same frame's hit of 10, so the Health stays at 100,
// OnHit does not fire and the zone counts nothing. Re-enabled, the next hit of 10 lands (90 left).
class UMars_AutoTest_HitZone_DisabledZoneIgnoresHits : UCk_AutoTest_Base
{
    private FCk_Handle_Health _Health;
    private FCk_Handle_HitZone _Zone;

    private int32 _HitCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Target = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Target, FMars_Health_Spec(100.0f));

        auto Spec = FMars_HitZone_Spec(GameplayTags::ResolveGameplayTag(n"HitZone.Mars.Limb"));
        Spec.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Sever"), 2.0f,
            EMars_HitZone_ConditionImpact::Damages));
        _Zone = utils_hit_zone::Add(Target, Spec);

        _Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnHit"));

        Add_Step("disable the zone and hit it for 10 in the same frame", n"Step_DisableAndHit");
        // Deliberately a fixed window: an ignored hit has no signal to wait on.
        Add_Step_WaitSeconds("let the drains run", 0.2f);
        Add_Step("the hit was ignored; re-enable the zone and hit it for 10 again", n"Step_AssertIgnoredAndHitAgain");
        Add_Step_WaitUntil("Health reads 90", n"Check_At90", 0, 2.0f);
        Add_Step("the second hit landed", n"Step_AssertLanded");
        Run_Steps(InHandle);
    }

    private FMars_Request_HitZone_Hit Make_Hit()
    {
        return FMars_Request_HitZone_Hit(FMars_DamageEvent(10.0f, GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Blunt")));
    }

    UFUNCTION()
    private void OnHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        ++_HitCount;
    }

    UFUNCTION()
    private void Step_DisableAndHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Zone), "the zone composed");
        _Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(false));
        _Zone.Request_Hit(Make_Hit());
    }

    UFUNCTION()
    private void Step_AssertIgnoredAndHitAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Zone.Get_IsEnabled(), "the zone is disabled");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.001f, "the Health still reads 100");
        Assert_Equals_Int(_HitCount, 0, "no OnHit while disabled");
        Assert_Equals_Int(_Zone.Get_HitCount(), 0, "the disabled zone counted nothing");

        _Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(true));
        _Zone.Request_Hit(Make_Hit());
    }

    UFUNCTION()
    private void Check_At90(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 90.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Zone.Get_IsEnabled(), "the zone is enabled again");
        Assert_Equals_Int(_HitCount, 1, "OnHit fired once, for the enabled hit");
        Assert_Equals_Int(_Zone.Get_HitCount(), 1, "the zone counted the enabled hit");
    }
}
