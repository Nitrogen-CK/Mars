// The dealer resolves what a sweep hits to the zone: a Sever 10 dealt to the zone's hurtbox node lands 20 on the
// target's Health (the zone's Sever row is x2), fires OnDamageDealt once naming the zone, and the event Make_Event built
// names the attacker as Instigator. A bare entity with no hurtbox link is rejected NoHitZone and counted.
class UMars_AutoTest_DamageDealer_ResolvesHurtboxToZone : UCk_AutoTest_Base
{
    private FCk_Handle _Attacker;
    private FCk_Handle_Health _Health;
    private FCk_Handle_HitZone _Zone;
    private FCk_Handle _Hurtbox;
    private FCk_Handle _Bare;
    private FCk_Handle_DamageDealer _Dealer;

    private TArray<FCk_Handle> _DealtZones;
    private TArray<FMars_DamageEvent> _DealtEvents;
    private TArray<FCk_Handle> _RejectedEntities;
    private TArray<EMars_DamageDealer_RejectReason> _RejectedReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Target = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Target, FMars_Health_Spec(100.0f));

        auto Spec = FMars_HitZone_Spec(GameplayTags::ResolveGameplayTag(n"HitZone.Mars.Limb"));
        Spec.Reactions.Add(FMars_HitZone_Reaction(Sever(), 2.0f, EMars_HitZone_ConditionImpact::Damages));
        _Zone = utils_hit_zone::Add(Target, Spec);

        auto Root = utils_transform::Add(Target, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Hurtbox = utils_hit_zone::AddHurtbox_Box(_Zone, Root, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 20.0), FTransform::Identity));

        _Attacker = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(_Attacker, FTransform(FRotator::ZeroRotator, FVector(-200.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        _Dealer = utils_damage_dealer::Add(_Attacker, FMars_DamageDealer_Spec());

        _Bare = utils_entity_lifetime::Request_CreateEntity(InHandle);

        _Dealer.BindTo_OnDamageDealt(FMars_Delegate_DamageDealer_OnDamageDealt(this, n"OnDamageDealt"));
        _Dealer.BindTo_OnDamageRejected(FMars_Delegate_DamageDealer_OnDamageRejected(this, n"OnDamageRejected"));

        Add_Step("deal Sever 10 to the hurtbox node", n"Step_DealToHurtbox");
        Add_Step_WaitUntil("Health reads 80", n"Check_At80", 0, 2.0f);
        Add_Step("dealt once to the zone, instigated by the attacker; deal to a bare entity", n"Step_AssertDealtAndDealToBare");
        Add_Step_WaitUntil("the bare entity is rejected", n"Check_Rejected", 0, 2.0f);
        Add_Step("rejected NoHitZone and counted", n"Step_AssertRejected");
        Run_Steps(InHandle);
    }

    private FGameplayTag Sever()
    {
        return GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Sever");
    }

    UFUNCTION()
    private void OnDamageDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent)
    {
        _DealtZones.Add(FCk_Handle(InZone));
        _DealtEvents.Add(InEvent);
    }

    UFUNCTION()
    private void OnDamageRejected(FCk_Handle_DamageDealer InDealer, FCk_Handle InHitEntity, EMars_DamageDealer_RejectReason InReason)
    {
        _RejectedEntities.Add(InHitEntity);
        _RejectedReasons.Add(InReason);
    }

    UFUNCTION()
    private void Step_DealToHurtbox(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Zone), "the zone composed");
        Assert_True(ck::IsValid(_Hurtbox), "the hurtbox node exists");
        Assert_True(ck::IsValid(_Dealer), "the dealer composed");
        Assert_True(FCk_Handle(utils_hit_zone::TryGet_Zone(_Hurtbox)) == FCk_Handle(_Zone), "the hurtbox links to the zone");
        Assert_Equals_Int(_Zone.Get_Hurtboxes().Num(), 1, "the zone lists its hurtbox");

        const auto Event = utils_damage_dealer::Make_Event(_Dealer, 10.0f, Sever());
        Assert_True(Event.Instigator == _Attacker, "Make_Event names the dealer's entity as Instigator");

        _Dealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(_Hurtbox, Event));
    }

    UFUNCTION()
    private void Check_At80(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 80.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertDealtAndDealToBare(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DealtZones.Num(), 1, "OnDamageDealt fired once");
        Assert_True(_DealtZones[0] == FCk_Handle(_Zone), "OnDamageDealt names the zone, not the hurtbox");
        Assert_True(_DealtEvents[0].Instigator == _Attacker, "the dealt event's Instigator is the attacker");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the dealer counted the hit");
        Assert_Equals_Int(_RejectedReasons.Num(), 0, "nothing was rejected");

        _Dealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(_Bare,
            utils_damage_dealer::Make_Event(_Dealer, 10.0f, Sever())));
    }

    UFUNCTION()
    private void Check_Rejected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RejectedReasons.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_RejectedReasons.Num(), 1, "OnDamageRejected fired once");
        Assert_True(_RejectedReasons[0] == EMars_DamageDealer_RejectReason::NoHitZone, "the bare entity is rejected NoHitZone");
        Assert_True(_RejectedEntities[0] == _Bare, "the rejection names the bare entity");
        Assert_Equals_Int(_Dealer.Get_HitsRejected(), 1, "the dealer counted the rejection");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the rejected hit was not dealt");
        Assert_Equals_Float(_Health.Get_Current(), 80.0f, 0.001f, "the Health is untouched by the rejected hit");
    }
}
