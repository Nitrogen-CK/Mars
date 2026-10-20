// A disabled zone rejects the dealer's hit: with the target's zone disabled, a Blunt 10 dealt at its hurtbox is rejected
// ZoneDisabled (Health stays 100, nothing is dealt). Re-enabled, the same hit lands (90) and is not rejected again.
// The attacker is on team One and the target on Two, so only the zone gate can reject.
class UMars_AutoTest_DamageDealer_ADisabledZoneRejects : UCk_AutoTest_Base
{
    private FCk_Handle_Health _Health;
    private FCk_Handle_HitZone _Zone;
    private FCk_Handle _Hurtbox;
    private FCk_Handle_DamageDealer _Dealer;

    private TArray<EMars_DamageDealer_RejectReason> _RejectedReasons;
    private TArray<FCk_Handle> _RejectedEntities;
    private int32 _DealtCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Target = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Target, FMars_Health_Spec(100.0f));
        _Zone = utils_hit_zone::Add(Target, FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body));
        auto Root = utils_transform::Add(Target, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Hurtbox = utils_hit_zone::AddHurtbox_Box(_Zone, Root, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 20.0), FTransform::Identity));
        utils_team::Add(Target, ECk_Team_ID::Two, ECk_Replication::DoesNotReplicate);

        auto Attacker = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Attacker, FTransform(FRotator::ZeroRotator, FVector(-200.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Attacker, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _Dealer = utils_damage_dealer::Add(Attacker, FMars_DamageDealer_Spec());

        _Dealer.BindTo_OnDamageRejected(FMars_Delegate_DamageDealer_OnDamageRejected(this, n"OnDamageRejected"));
        _Dealer.BindTo_OnDamageDealt(FMars_Delegate_DamageDealer_OnDamageDealt(this, n"OnDamageDealt"));

        Add_Step("disable the target's zone", n"Step_Disable");
        Add_Step_WaitUntil("the zone reads disabled", n"Check_Disabled", 0, 0);
        Add_Step("deal Blunt 10 at its hurtbox", n"Step_Deal");
        Add_Step_WaitUntil("the hit is rejected", n"Check_Rejected", 0, 0);
        Add_Step("rejected ZoneDisabled; re-enable the zone", n"Step_AssertRejectedAndEnable");
        Add_Step_WaitUntil("the zone reads enabled", n"Check_Enabled", 0, 0);
        Add_Step("deal Blunt 10 again", n"Step_Deal");
        Add_Step_WaitUntil("Health reads 90", n"Check_At90", 0, 0);
        Add_Step("the second hit was dealt, not rejected", n"Step_AssertDealt");
        Run_Steps(InHandle);
    }

    private FMars_Request_DamageDealer_DealDamage Make_Deal()
    {
        return FMars_Request_DamageDealer_DealDamage(_Hurtbox,
            utils_damage_dealer::Make_Event(_Dealer, 10.0f, GameplayTags::DamageType_Mars_Blunt));
    }

    UFUNCTION()
    private void OnDamageRejected(FCk_Handle_DamageDealer InDealer, FCk_Handle InHitEntity, EMars_DamageDealer_RejectReason InReason)
    {
        _RejectedReasons.Add(InReason);
        _RejectedEntities.Add(InHitEntity);
    }

    UFUNCTION()
    private void OnDamageDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent)
    {
        ++_DealtCount;
    }

    UFUNCTION()
    private void Step_Disable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Dealer, "the dealer composed");
        Assert_Valid(_Hurtbox, "the target has a hurtbox");
        Assert_True(_Zone.Get_IsEnabled(), "the zone starts enabled");

        _Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));
    }

    UFUNCTION()
    private void Check_Disabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Zone.Get_IsEnabled() == false);
    }

    UFUNCTION()
    private void Step_Deal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dealer.Request_DealDamage(Make_Deal());
    }

    UFUNCTION()
    private void Check_Rejected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RejectedReasons.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRejectedAndEnable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_RejectedReasons.Num(), 1, "OnDamageRejected fired once");
        Assert_True(_RejectedReasons[0] == EMars_DamageDealer_RejectReason::ZoneDisabled,
            f"the hit was rejected ZoneDisabled (got {_RejectedReasons[0] :n})");
        Assert_True(_RejectedEntities[0] == _Hurtbox, "the rejection names the hurtbox the hit landed on");
        Assert_Equals_Int(_Dealer.Get_HitsRejected(), 1, "the dealer counted one rejection");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 0, "the dealer dealt nothing");
        Assert_Equals_Int(_DealtCount, 0, "no OnDamageDealt");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.001f, "the Health still reads 100");

        _Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Enable));
    }

    UFUNCTION()
    private void Check_Enabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Zone.Get_IsEnabled());
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
        Assert_Equals_Int(_RejectedReasons.Num(), 1, "the enabled hit was not rejected");
        Assert_Equals_Int(_DealtCount, 1, "OnDamageDealt fired once");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the dealer dealt one hit");
        Assert_Equals_Int(_Dealer.Get_HitsRejected(), 1, "the dealer's rejection count is unchanged");
    }
}
