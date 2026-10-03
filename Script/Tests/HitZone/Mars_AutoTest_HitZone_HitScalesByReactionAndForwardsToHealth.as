// The zone contract: the spec rejects a missing ZoneTag and a negative multiplier; a Sever hit of 10 on a zone whose Sever
// row is x2 lands 20 on the Health (80 left) and fires OnHit once with the scaled event, the Damages row and the zone
// stamped on it; a Crush hit of 10 (no row) takes the default x1 (70 left); the zone counts both hits.
class UMars_AutoTest_HitZone_HitScalesByReactionAndForwardsToHealth : UCk_AutoTest_Base
{
    private FCk_Handle_Health _Health;
    private FCk_Handle_HitZone _Zone;

    private TArray<FMars_DamageEvent> _HitEvents;
    private TArray<FMars_HitZone_Reaction> _HitReactions;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Target = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Target, FMars_Health_Spec(100.0f));

        auto Spec = FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Limb);
        Spec.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Sever, 2.0f, EMars_HitZone_ConditionImpact::Damages));
        Spec.DefaultMultiplier = 1.0f;
        _Zone = utils_hit_zone::Add(Target, Spec);

        _Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnHit"));

        Add_Step("the spec rules hold; hit the zone with Sever 10", n"Step_ValidateAndHitSever");
        Add_Step_WaitUntil("Health reads 80 (Sever x2)", n"Check_At80", 0, 2.0f);
        Add_Step("one OnHit carrying the scaled event; hit the zone with Crush 10", n"Step_AssertSeverAndHitCrush");
        Add_Step_WaitUntil("Health reads 70 (Crush has no row: x1)", n"Check_At70", 0, 2.0f);
        Add_Step("the default row applied and the zone counted two hits", n"Step_AssertCrush");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        _HitEvents.Add(InScaledEvent);
        _HitReactions.Add(InReaction);
    }

    UFUNCTION()
    private void Step_ValidateAndHitSever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(FMars_HitZone_Spec().Validate().IsValid(), "a spec with no ZoneTag is rejected");

        auto Negative = FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Limb);
        Negative.DefaultMultiplier = -1.0f;
        Assert_False(Negative.Validate().IsValid(), "a negative DefaultMultiplier is rejected");

        auto NegativeRow = FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Limb);
        NegativeRow.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Sever, -2.0f, EMars_HitZone_ConditionImpact::Damages));
        Assert_False(NegativeRow.Validate().IsValid(), "a negative reaction multiplier is rejected");

        Assert_Valid(_Health, "utils_health::Add composed the Health");
        Assert_Valid(_Zone, "utils_hit_zone::Add composed the zone");
        Assert_True(_Zone.Get_Health() == _Health, "the zone feeds its entity's own Health");
        Assert_True(_Zone.Get_IsEnabled(), "a fresh zone is enabled");

        _Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(10.0f, GameplayTags::DamageType_Mars_Sever)));
    }

    UFUNCTION()
    private void Check_At80(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 80.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertSeverAndHitCrush(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HitEvents.Num(), 1, "OnHit fired once");
        if (_HitEvents.Num() == 1)
        {
            Assert_Equals_Float(_HitEvents[0].Amount, 20.0f, 0.001f, "the scaled event carries 10 x 2");
            Assert_True(_HitReactions[0].Impact == EMars_HitZone_ConditionImpact::Damages,
                f"the Sever row's impact is Damages (got [{_HitReactions[0].Impact :n}])");
            Assert_True(_Zone == _HitEvents[0].HitZone, "the zone stamped itself on the event");
            Assert_True(_HitEvents[0].DamageType == GameplayTags::DamageType_Mars_Sever,
                f"the damage type is kept (got [{_HitEvents[0].DamageType.ToString()}])");
        }

        _Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(10.0f, GameplayTags::DamageType_Mars_Crush)));
    }

    UFUNCTION()
    private void Check_At70(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 70.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertCrush(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HitEvents.Num(), 2, "OnHit fired for the Crush hit");
        if (_HitEvents.Num() == 2)
        {
            Assert_Equals_Float(_HitEvents[1].Amount, 10.0f, 0.001f, "Crush takes the default x1");
            Assert_True(_HitReactions[1].Impact == EMars_HitZone_ConditionImpact::None,
                f"the default row has no condition impact (got [{_HitReactions[1].Impact :n}])");
        }

        Assert_Equals_Int(_Zone.Get_HitCount(), 2, "the zone counted two hits");
    }
}
