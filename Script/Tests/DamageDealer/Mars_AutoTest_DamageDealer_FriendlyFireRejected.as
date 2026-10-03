// The team gate: an attacker on team One hitting a team One target is rejected Friendly (Health stays 100). With the
// target retagged Two the same hit lands (90). Back on One, a second attacker on One that allows friendly fire lands too
// (80).
class UMars_AutoTest_DamageDealer_FriendlyFireRejected : UCk_AutoTest_Base
{
    private FCk_Handle _Self;
    private FCk_Handle_Health _Health;
    private FCk_Handle_HitZone _Zone;
    private FCk_Handle _Hurtbox;
    private FCk_Handle_Team _TargetTeam;
    private FCk_Handle_DamageDealer _Dealer;
    private FCk_Handle_DamageDealer _FriendlyFireDealer;

    private TArray<EMars_DamageDealer_RejectReason> _RejectedReasons;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Self = InHandle;

        auto Target = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Target, FMars_Health_Spec(100.0f));
        _Zone = utils_hit_zone::Add(Target, FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body));
        auto Root = utils_transform::Add(Target, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Hurtbox = utils_hit_zone::AddHurtbox_Box(_Zone, Root, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 20.0), FTransform::Identity));
        _TargetTeam = utils_team::Add(Target, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);

        auto Attacker = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Attacker, FTransform(FRotator::ZeroRotator, FVector(-200.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Attacker, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _Dealer = utils_damage_dealer::Add(Attacker, FMars_DamageDealer_Spec());

        _Dealer.BindTo_OnDamageRejected(FMars_Delegate_DamageDealer_OnDamageRejected(this, n"OnDamageRejected"));

        Add_Step("both on team One: deal Blunt 10", n"Step_DealSameTeam");
        Add_Step_WaitUntil("the hit is rejected", n"Check_Rejected", 0, 2.0f);
        Add_Step("rejected Friendly; retag the target Two and deal again", n"Step_AssertFriendlyAndRetag");
        Add_Step_WaitUntil("Health reads 90", n"Check_At90", 0, 2.0f);
        Add_Step("retag the target One; a friendly-fire attacker on One deals", n"Step_FriendlyFireDeal");
        Add_Step_WaitUntil("Health reads 80", n"Check_At80", 0, 2.0f);
        Add_Step("only the first hit was rejected", n"Step_AssertFinal");
        Run_Steps(InHandle);
    }

    private FMars_Request_DamageDealer_DealDamage Make_Deal(FCk_Handle_DamageDealer InDealer)
    {
        return FMars_Request_DamageDealer_DealDamage(_Hurtbox,
            utils_damage_dealer::Make_Event(InDealer, 10.0f, GameplayTags::DamageType_Mars_Blunt));
    }

    UFUNCTION()
    private void OnDamageRejected(FCk_Handle_DamageDealer InDealer, FCk_Handle InHitEntity, EMars_DamageDealer_RejectReason InReason)
    {
        _RejectedReasons.Add(InReason);
    }

    UFUNCTION()
    private void Step_DealSameTeam(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_TargetTeam), "the target has a team");
        Assert_True(ck::IsValid(_Dealer), "the dealer composed");
        _Dealer.Request_DealDamage(Make_Deal(_Dealer));
    }

    UFUNCTION()
    private void Check_Rejected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RejectedReasons.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertFriendlyAndRetag(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_RejectedReasons.Num(), 1, "OnDamageRejected fired once");
        Assert_True(_RejectedReasons[0] == EMars_DamageDealer_RejectReason::Friendly,
            f"a same-team hit is rejected Friendly (got {_RejectedReasons[0] :n})");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.001f, "the Health still reads 100");
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 0, "nothing was dealt");

        _TargetTeam = utils_team::Assign(_TargetTeam, ECk_Team_ID::Two);
        _Dealer.Request_DealDamage(Make_Deal(_Dealer));
    }

    UFUNCTION()
    private void Check_At90(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 90.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_FriendlyFireDeal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the cross-team hit was dealt");

        _TargetTeam = utils_team::Assign(_TargetTeam, ECk_Team_ID::One);

        auto FriendlyFireAttacker = utils_entity_lifetime::Request_CreateEntity(_Self);
        utils_team::Add(FriendlyFireAttacker, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _FriendlyFireDealer = utils_damage_dealer::Add(FriendlyFireAttacker, FMars_DamageDealer_Spec(1.0f, EMars_DamageDealer_FriendlyFire::Allow));
        _FriendlyFireDealer.BindTo_OnDamageRejected(FMars_Delegate_DamageDealer_OnDamageRejected(this, n"OnDamageRejected"));

        _FriendlyFireDealer.Request_DealDamage(Make_Deal(_FriendlyFireDealer));
    }

    UFUNCTION()
    private void Check_At80(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 80.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertFinal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_team::Get_IsAssignedTo(_TargetTeam, ECk_Team_ID::One), "the target is back on team One");
        Assert_Equals_Int(_FriendlyFireDealer.Get_HitsDealt(), 1, "the friendly-fire dealer dealt the same-team hit");
        Assert_Equals_Int(_RejectedReasons.Num(), 1, "only the first hit was rejected");
    }
}
