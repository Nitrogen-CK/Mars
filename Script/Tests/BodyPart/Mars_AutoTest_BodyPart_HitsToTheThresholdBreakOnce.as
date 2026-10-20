// The Break policy: a part (Health 30, Sever x1 Damages, no spill) on a standalone monster takes 10 Sever (20 left,
// Pristine -> Damaged, still Attached), then a lethal 20 Sever depletes it: the part reads Broken, its zone is disabled,
// OnBroken fires once carrying the lethal hit, and OnSevered never fires. A further Sever request on the broken part is
// ignored: it is drained beside a Ruins hit (its ruin damage moves 0 -> 4, the proof the drain ran), and OnBroken stays
// at one.
class UMars_AutoTest_BodyPart_HitsToTheThresholdBreakOnce : UCk_AutoTest_Base
{
    private FCk_Handle_Monster _Monster;
    private FCk_Handle_BodyPart _Part;

    private int32 _BrokenCount = 0;
    private FMars_DamageEvent _BrokenCause;
    private int32 _SeveredCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Root = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Monster = utils_monster::Add(Root, FMars_Monster_Spec(GameplayTags::Monster_Mars_Crawler, FMars_Health_Spec(100.0f),
            utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f), 8.0f, ECk_Team_ID::Two));

        auto Zone = FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Limb);
        Zone.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Sever, 1.0f, EMars_HitZone_ConditionImpact::Damages));
        auto Spec = FMars_BodyPart_Spec(GameplayTags::BodyPart_Mars_Crawler_Leg, EMars_BodyPart_Function::Attack, FMars_Health_Spec(30.0f),
            Zone, FMars_BodyPart_Severance(EMars_BodyPart_DepletionPolicy::Break, 0.0f, 0.5f, FMars_BodyPart_Debris()));
        Spec.Monster = _Monster;

        auto PartEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Part = utils_body_part::Add(PartEntity, Spec);

        _Part.BindTo_OnBroken(FMars_Delegate_BodyPart_OnBroken(this, n"OnBroken"));
        _Part.BindTo_OnSevered(FMars_Delegate_BodyPart_OnSevered(this, n"OnSevered"));

        Add_Step_WaitUntil("the part is registered on its monster", n"Check_Registered", 0, 0);
        Add_Step("hit the part's zone with 10 Sever", n"Step_HitTen");
        Add_Step_WaitUntil("the part's Health reads 20", n"Check_At20", 0, 0);
        Add_Step("the part is Damaged and Attached; hit it with a lethal 20 Sever", n"Step_AssertDamagedAndHitLethal");
        Add_Step_WaitUntil("the part reads Broken", n"Check_Broken", 0, 0);
        Add_Step("broken once; request another sever beside a Ruins hit", n"Step_AssertBrokenAndSeverAgain");
        Add_Step_WaitUntil("the Ruins hit is in the ledger", n"Check_RuinRecorded", 0, 0);
        Add_Step("the second sever changed nothing", n"Step_AssertBrokenOnce");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnBroken(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause)
    {
        ++_BrokenCount;
        _BrokenCause = InCause;
    }

    UFUNCTION()
    private void OnSevered(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased)
    {
        ++_SeveredCount;
    }

    private void Hit(float32 InAmount)
    {
        auto Zone = _Part.Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever)));
    }

    UFUNCTION()
    private void Check_Registered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Monster) && _Monster.Get_Parts().Num() == 1);
    }

    UFUNCTION()
    private void Step_HitTen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Part, "utils_body_part::Add composed the part");
        Hit(10.0f);
    }

    UFUNCTION()
    private void Check_At20(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Part.Get_Health().Get_Current(), 20.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertDamagedAndHitLethal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Part.Get_Condition() == EMars_BodyPart_Condition::Damaged, f"a Damages hit moves the part to Damaged (got {_Part.Get_Condition() :n})");
        Assert_True(_Part.Get_State() == EMars_BodyPart_State::Attached, f"a non-lethal hit leaves the part Attached (got {_Part.Get_State() :n})");
        Assert_Equals_Int(_BrokenCount, 0, "no OnBroken before depletion");
        Hit(20.0f);
    }

    UFUNCTION()
    private void Check_Broken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Part.Get_State() == EMars_BodyPart_State::Broken);
    }

    UFUNCTION()
    private void Step_AssertBrokenAndSeverAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Part.Get_Health().Get_IsDepleted(), "the lethal hit depleted the part's Health");
        Assert_Equals_Int(_BrokenCount, 1, "OnBroken fired once");
        Assert_Equals_Float(_BrokenCause.Amount, 20.0f, 0.001f, "OnBroken carries the lethal hit's amount");
        Assert_True(_BrokenCause.DamageType == GameplayTags::DamageType_Mars_Sever, "OnBroken carries the lethal hit's damage type");
        Assert_Equals_Int(_SeveredCount, 0, "a broken part does not sever");
        Assert_False(_Part.Get_Zone().Get_IsEnabled(), "breaking disables the part's zone");
        Assert_Equals_Float(_Part.Get_RuinDamageTaken(), 0.0f, 0.001f, "no ruin damage yet");

        _Part.Request_Sever(FMars_Request_BodyPart_Sever(FMars_DamageEvent(5.0f, GameplayTags::DamageType_Mars_Crush)));
        _Part.Request_RecordHit(FMars_Request_BodyPart_RecordHit(FMars_DamageEvent(4.0f, GameplayTags::DamageType_Mars_Crush),
            FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Crush, 1.0f, EMars_HitZone_ConditionImpact::Ruins)));
    }

    UFUNCTION()
    private void Check_RuinRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Part.Get_RuinDamageTaken() > 0.0f);
    }

    UFUNCTION()
    private void Step_AssertBrokenOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Part.Get_RuinDamageTaken(), 4.0f, 0.001f, "the drain recorded the Ruins hit");
        Assert_Equals_Int(_BrokenCount, 1, "OnBroken still fired once");
        Assert_Equals_Int(_SeveredCount, 0, "OnSevered never fired");
        Assert_True(_Part.Get_State() == EMars_BodyPart_State::Broken, f"the part stays Broken (got {_Part.Get_State() :n})");
        Assert_Equals_Int(_Monster.Get_AttachedPartCount(), 0, "the monster counts no attached part");
    }
}
