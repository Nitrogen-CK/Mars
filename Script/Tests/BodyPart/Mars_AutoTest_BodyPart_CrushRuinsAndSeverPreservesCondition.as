// The condition ledger is data: on a crawler leg, Sever rows damage and Crush rows ruin. Leg 0: 10 Sever moves it
// Pristine -> Damaged, a second 10 Sever leaves it Damaged (no signal). Leg 1: Crush 6 lands as 9 (Crush x1.5 on a limb),
// below the ruin threshold (0.5 x 30 = 15), so Pristine -> Damaged; a second Crush 6 brings the ruin damage to 18 >= 15,
// so Damaged -> Ruined. OnConditionChanged fires exactly for the three changes and Get_Condition agrees. Each hit also
// spills half its scaled amount to the body; the body's value proves each hit's ledger entry drained.
//
// Isolated origin (130000, 92000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_BodyPart_CrushRuinsAndSeverPreservesCondition : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FVector _Origin = FVector(130000.0, 92000.0, 600.0);
    private FCk_Handle_Crawler _Crawler;

    private FCk_Handle_BodyPart _Part0;
    private FCk_Handle_BodyPart _Part1;
    private TArray<FCk_Handle_BodyPart> _ChangedParts;
    private TArray<EMars_BodyPart_Condition> _ChangedOld;
    private TArray<EMars_BodyPart_Condition> _ChangedNew;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", 0, 10.0f);
        Add_Step("bind OnConditionChanged on legs 0 and 1; Sever 10 on leg 0", n"Step_BindAndSeverLeg0");
        Add_Step_WaitUntil("the body reads 115", n"Check_BodyAt115", 0, 2.0f);
        Add_Step("leg 0 is Damaged; Sever 10 on leg 0 again", n"Step_AssertDamagedAndSeverAgain");
        Add_Step_WaitUntil("the body reads 110", n"Check_BodyAt110", 0, 2.0f);
        Add_Step("leg 0 stays Damaged with no new signal; Crush 6 on leg 1", n"Step_AssertStillDamagedAndCrushLeg1");
        Add_Step_WaitUntil("the body reads 105.5", n"Check_BodyAt105", 0, 2.0f);
        Add_Step("leg 1 is Damaged with 9 ruin damage; Crush 6 on leg 1 again", n"Step_AssertCrushDamagedAndCrushAgain");
        Add_Step_WaitUntil("the body reads 101", n"Check_BodyAt101", 0, 2.0f);
        Add_Step("leg 1 is Ruined; leg 0 is still Damaged", n"Step_AssertRuined");
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        const auto Half = FVector(400.0, 400.0, 200.0);
        return FMars_Crawler_Spec(4, FBox(_Origin - Half, _Origin + Half));
    }

    private void SpawnFloorAndCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(1500.0, 1500.0, 10.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        auto SpawnParams = UMars_Crawler_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        SpawnParams.Spec = InSpec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Crawler_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnCrawlerConstructed"));
    }

    UFUNCTION()
    private void OnCrawlerConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Crawler = InEntityScriptHandle.As_Crawler();
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Crawler))
        {
            Res.Set(false);
            return;
        }

        const auto Gait = _Crawler.Get_Gait();
        if (utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Failed)
        {
            FinishFailure(f"the crawler's gait failed: {utils_procedural_gait::Get_Failure(Gait) :n}");
            return;
        }

        Res.Set(utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Ready &&
            _Crawler.Get_Monster().Get_Parts().Num() == 4);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Helpers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnConditionChanged(FCk_Handle_BodyPart InPart, EMars_BodyPart_Condition InOld, EMars_BodyPart_Condition InNew)
    {
        _ChangedParts.Add(InPart);
        _ChangedOld.Add(InOld);
        _ChangedNew.Add(InNew);
    }

    private void Hit(FCk_Handle_BodyPart InPart, float32 InAmount, FGameplayTag InDamageType)
    {
        auto Zone = InPart.Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, InDamageType)));
    }

    private bool Get_BodyIs(float32 InExpected)
    {
        return Math::IsNearlyEqual(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), InExpected, 0.001f);
    }

    private void AssertChange(int32 InIndex, EMars_BodyPart_Condition InOld, EMars_BodyPart_Condition InNew)
    {
        if (_ChangedParts.Num() <= InIndex)
        {
            Assert_True(false, f"change {InIndex} was signalled ({_ChangedParts.Num()} changes)");
            return;
        }

        Assert_True(_ChangedOld[InIndex] == InOld, f"change {InIndex} starts at {InOld :n} (got {_ChangedOld[InIndex] :n})");
        Assert_True(_ChangedNew[InIndex] == InNew, f"change {InIndex} ends at {InNew :n} (got {_ChangedNew[InIndex] :n})");
    }

    private void AssertCondition(FCk_Handle_BodyPart InPart, EMars_BodyPart_Condition InExpected, const FString& InWhat)
    {
        const auto Condition = InPart.Get_Condition();
        Assert_True(Condition == InExpected, f"{InWhat} (got {Condition :n})");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_BindAndSeverLeg0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Part0 = _Crawler.Get_LegParts()[0];
        _Part1 = _Crawler.Get_LegParts()[1];
        _Part0.BindTo_OnConditionChanged(FMars_Delegate_BodyPart_OnConditionChanged(this, n"OnConditionChanged"));
        _Part1.BindTo_OnConditionChanged(FMars_Delegate_BodyPart_OnConditionChanged(this, n"OnConditionChanged"));

        Hit(_Part0, 10.0f, GameplayTags::DamageType_Mars_Sever);
    }

    UFUNCTION()
    private void Check_BodyAt115(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_BodyIs(115.0f));
    }

    UFUNCTION()
    private void Step_AssertDamagedAndSeverAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertCondition(_Part0, EMars_BodyPart_Condition::Damaged, "Sever moved leg 0 to Damaged");
        Assert_Equals_Int(_ChangedParts.Num(), 1, "one condition change");
        Assert_True(_ChangedParts.Num() > 0 && _ChangedParts[0] == _Part0, "change 0 is leg 0's");
        AssertChange(0, EMars_BodyPart_Condition::Pristine, EMars_BodyPart_Condition::Damaged);
        Assert_Equals_Float(_Part0.Get_RuinDamageTaken(), 0.0f, 0.001f, "Sever adds no ruin damage");

        Hit(_Part0, 10.0f, GameplayTags::DamageType_Mars_Sever);
    }

    UFUNCTION()
    private void Check_BodyAt110(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_BodyIs(110.0f));
    }

    UFUNCTION()
    private void Step_AssertStillDamagedAndCrushLeg1(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertCondition(_Part0, EMars_BodyPart_Condition::Damaged, "a second Sever leaves leg 0 Damaged");
        Assert_Equals_Int(_ChangedParts.Num(), 1, "no signal for an unchanged condition");
        Assert_Equals_Float(_Part0.Get_Health().Get_Current(), 10.0f, 0.001f, "leg 0 took both Sever hits");

        Hit(_Part1, 6.0f, GameplayTags::DamageType_Mars_Crush);
    }

    UFUNCTION()
    private void Check_BodyAt105(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_BodyIs(105.5f));
    }

    UFUNCTION()
    private void Step_AssertCrushDamagedAndCrushAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertCondition(_Part1, EMars_BodyPart_Condition::Damaged, "Crush below the ruin threshold moves leg 1 to Damaged");
        Assert_Equals_Float(_Part1.Get_RuinDamageTaken(), 9.0f, 0.001f, "leg 1 took 6 x 1.5 = 9 ruin damage");
        Assert_Equals_Int(_ChangedParts.Num(), 2, "two condition changes");
        Assert_True(_ChangedParts.Num() > 1 && _ChangedParts[1] == _Part1, "change 1 is leg 1's");
        AssertChange(1, EMars_BodyPart_Condition::Pristine, EMars_BodyPart_Condition::Damaged);

        Hit(_Part1, 6.0f, GameplayTags::DamageType_Mars_Crush);
    }

    UFUNCTION()
    private void Check_BodyAt101(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_BodyIs(101.0f));
    }

    UFUNCTION()
    private void Step_AssertRuined(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertCondition(_Part1, EMars_BodyPart_Condition::Ruined, "18 ruin damage >= 15 ruins leg 1");
        Assert_Equals_Float(_Part1.Get_RuinDamageTaken(), 18.0f, 0.001f, "leg 1 took 18 ruin damage");
        Assert_Equals_Int(_ChangedParts.Num(), 3, "three condition changes");
        Assert_True(_ChangedParts.Num() > 2 && _ChangedParts[2] == _Part1, "change 2 is leg 1's");
        AssertChange(2, EMars_BodyPart_Condition::Damaged, EMars_BodyPart_Condition::Ruined);

        AssertCondition(_Part0, EMars_BodyPart_Condition::Damaged, "leg 0 is still Damaged");
        Assert_True(_Part1.Get_State() == EMars_BodyPart_State::Attached,
            f"a ruined leg with health left stays attached (got {_Part1.Get_State() :n})");
        Assert_Equals_Float(_Part1.Get_Health().Get_Current(), 12.0f, 0.001f, "leg 1 has 12 left");
    }
}
