// The crawler composition, spawned through the real entity script onto a runtime static Jolt floor: once the gait is
// Ready the crawler has 4 legs and 4 leg parts, each part IS its leg entity (Movement, Attached, 30 health, a zone with 3
// hurtboxes: 2 segments + the foot); the monster root has the 4 parts on its roster, 120 body health, a body zone with one
// hurtbox and team Two. The spec rejects a leg count with no rig (5) and MinLegsToWalk below 2.
//
// Isolated origin (130000, 80000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_Crawler_ComposesWalkerPartsAndMonster : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    private FVector _Origin = FVector(130000.0, 80000.0, 600.0);
    private FCk_Handle_Crawler _Crawler;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", 0, 10.0f);
        Add_Step("the walker, the parts on the leg entities and the monster are composed", n"Step_AssertComposition");
        Add_Step("the spec rules hold", n"Step_AssertValidation");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared rig (one scenario per file: copied, not shared)
    //----------------------------------------------------------------------------------------------------------------------

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
        _Crawler = FCk_Handle(InEntityScriptHandle).As_Crawler(ECk_SanityCheck::UnChecked);
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
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_AssertComposition(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Legs = _Crawler.Get_Legs();
        const auto Parts = _Crawler.Get_LegParts();
        Assert_Equals_Int(Legs.Num(), 4, "the walker created 4 legs");
        Assert_Equals_Int(Parts.Num(), 4, "one part per leg");
        Assert_Equals_Int(utils_procedural_leg::Get_Legs(FCk_Handle(_Crawler), ECk_ProceduralLeg_Filter::OnlyAttached).Num(), 4,
            "the body's record holds 4 attached legs");

        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            const auto Part = Parts[Index];
            Assert_True(FCk_Handle(Part) == FCk_Handle(Legs[Index]), f"part {Index} is its leg entity");
            Assert_True(FCk_Handle(Part.Get_Leg()) == FCk_Handle(Legs[Index]), f"part {Index} names its leg");
            Assert_True(Part.Get_Function() == EMars_BodyPart_Function::Movement, f"part {Index} is a Movement part");
            Assert_True(Part.Get_State() == EMars_BodyPart_State::Attached, f"part {Index} is Attached");
            Assert_True(Part.Get_Condition() == EMars_BodyPart_Condition::Pristine, f"part {Index} is Pristine");
            Assert_Equals_Float(Part.Get_Health().Get_Current(), 30.0f, 0.001f, f"part {Index} has 30 health");
            Assert_Equals_Int(Part.Get_Zone().Get_Hurtboxes().Num(), 3, f"part {Index}'s zone has 3 hurtboxes (2 segments + foot)");
            Assert_True(Part.Get_Zone().Get_ZoneTag() == GameplayTags::ResolveGameplayTag(n"HitZone.Mars.Limb"), f"part {Index}'s zone is a Limb");
            Assert_True(FCk_Handle(Part.Get_Monster()) == FCk_Handle(_Crawler), f"part {Index} belongs to the crawler's monster");
        }

        const auto Monster = _Crawler.Get_Monster();
        Assert_True(ck::IsValid(Monster), "the crawler root is the monster");
        Assert_Equals_Int(Monster.Get_Parts().Num(), 4, "the monster's roster holds the 4 parts");
        Assert_Equals_Int(Monster.Get_AttachedPartCount(), 4, "all 4 parts are attached");
        Assert_Equals_Float(Monster.Get_BodyHealth().Get_Current(), 120.0f, 0.001f, "the body has 120 health");
        Assert_Equals_Int(Monster.Get_BodyZone().Get_Hurtboxes().Num(), 1, "the body zone has one hurtbox");
        Assert_False(Monster.Get_IsDead(), "the monster is alive");
        Assert_True(utils_team::Get_ID(utils_team::TryGet_Entity_Team_InOwnershipChain(FCk_Handle(_Crawler))) == ECk_Team_ID::Two,
            "the crawler is on team Two");
        Assert_True(ck::IsValid(_Crawler.Get_BodyPose()), "the body pose composed");
        Assert_True(utils_surface_motion::Get_Status(_Crawler.Get_Motion()) != ECk_ProceduralAnimation_Status::Failed, "surface motion did not fail");
    }

    UFUNCTION()
    private void Step_AssertValidation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // The composed crawler's own spec carries a real rig, so each rejection below is the field under test.
        const auto Composed = _Crawler.Get_Spec();
        Assert_True(Composed.Validate().IsValid, "the composed 4-leg spec (rig included) is valid");

        auto FiveLegs = Composed;
        FiveLegs.LegCount = 5;
        Assert_False(FiveLegs.Validate().IsValid, "a 5-leg spec is rejected (no rig asset)");

        auto OneLeg = Composed;
        OneLeg.MinLegsToWalk = 1;
        Assert_False(OneLeg.Validate().IsValid, "MinLegsToWalk 1 is rejected");

        auto NoBounds = Composed;
        NoBounds.RoamBounds = FBox(_Origin, _Origin);
        Assert_False(NoBounds.Validate().IsValid, "empty RoamBounds are rejected");

        auto NoRig = Composed;
        NoRig.Rig = FMars_Crawler_Rig();
        Assert_False(NoRig.Validate().IsValid, "a spec without a rig is rejected");
    }
}
