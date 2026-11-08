// F4-4 (Phase 7). The court's pack is boxed off by four static walls (baked into the field), so no eligible slot's work point
// has a provider route from the den's OutsideStand. Once the raid is ready and the pack armed, 10 s of raid clock pass with NO
// emergence request (Get_EmergencesRequested 0, no rat) and the "has no provider route" line logged exactly once
// (Get_UnreachableTargetLogs 1). Then the walls are removed and the field rebuilt: the next emergence happens.
class UMars_AutoTest_PantryRaid_UnreachablePackSpawnsNothing : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 90.0f;

    private const float64 k_BoxHalf = 110.0;
    private TArray<FCk_Handle> _WallEntities;
    private TArray<FCk_Handle_JoltBody> _Walls;
    private float32 _ArmedAt = -1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(740000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 0);

        const auto Pack = _Origin + k_PackOffset;
        Add_Wall(InHandle, Pack + FVector(k_BoxHalf, 0.0, 60.0), FVector(10.0, k_BoxHalf + 10.0, 60.0));
        Add_Wall(InHandle, Pack - FVector(k_BoxHalf, 0.0, -60.0), FVector(10.0, k_BoxHalf + 10.0, 60.0));
        Add_Wall(InHandle, Pack + FVector(0.0, k_BoxHalf, 60.0), FVector(k_BoxHalf + 10.0, 10.0, 60.0));
        Add_Wall(InHandle, Pack - FVector(0.0, k_BoxHalf, -60.0), FVector(k_BoxHalf + 10.0, 10.0, 60.0));

        Add_Step_WaitUntil("the four walls joined Jolt", n"Check_WallsReady", k_SlowPolls, 0);
        Add_CourtSteps();
        Add_Step_WaitUntil("the raid is ready and the boxed pack armed", n"Check_Armed", k_LongPolls, 0);
        Add_Step_WaitUntil("10 s of raid clock with the pack armed", n"Check_TenSeconds", k_LongPolls, 0);
        Add_Step("no emergence; the unreachable line logged once", n"Step_AssertNothing");
        Add_Step("remove the walls", n"Step_OpenTheBox");
        Add_Step_WaitUntil("the walls left Jolt", n"Check_WallsGone", k_SlowPolls, 0);
        Add_Step_WaitFrames("the static world settled", 3);
        Add_Step("rebuild the field without the walls", n"Step_Rebuild");
        Add_Step_WaitUntil("the field rebuilt", n"Check_Rebuilt", k_SlowPolls, 0);
        Add_Step_WaitUntil("the next emergence happens", n"Check_Emerged", k_LongPolls, 0);
        Run_Steps(InHandle);
    }

    private void Add_Wall(FCk_Handle InHandle, FVector InCentre, FVector InHalfExtents)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Track_ForCleanup(Entity);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InCentre), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto Spec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        Spec.Set_ShapeDimensions(Shape).Set_MotionType(ECk_MotionType::Static);
        _Walls.Add(utils_jolt_body::Add(Entity, Spec));
        _WallEntities.Add(Entity);
    }

    UFUNCTION()
    private void Check_WallsReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Ready = _Walls.Num() == 4;
        for (const auto& Wall : _Walls)
        { Ready = Ready && ck::IsValid(Wall) && utils_jolt_body::Get_IsBodyAdded(Wall); }

        auto Result = OutResult;
        Result.Set(Ready);
    }

    UFUNCTION()
    private void Check_Armed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Armed = false;
        if (ck::IsValid(_Raid) && _Raid.Get_IsReady())
        {
            const auto Record = _Raid.TryGet_PackRecord(_Pack);
            Armed = Record.IsSet() && Record.GetValue().ScentArmed && Record.GetValue().EligibleSlots.Num() > 0;
        }

        if (Armed && _ArmedAt < 0.0f)
        { _ArmedAt = _Raid.Get_Clock(); }

        auto Result = OutResult;
        Result.Set(Armed);
    }

    UFUNCTION()
    private void Check_TenSeconds(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Raid.Get_Clock() - _ArmedAt >= 10.0f || _Raid.Get_EmergencesRequested() > 0);
    }

    UFUNCTION()
    private void Step_AssertNothing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Raid.Get_EmergencesRequested(), 0, "no emergence toward the boxed-off pack in 10 s of raid clock");
        Assert_Equals_Int(_Raid.Get_RatCount(), 0, "no rat spawned");
        Assert_Equals_Int(_Raid.Get_UnreachableTargetLogs(), 1, "the unreachable line was logged exactly once");
    }

    UFUNCTION()
    private void Step_OpenTheBox(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (auto Entity : _WallEntities)
        {
            if (ck::IsValid(Entity))
            { utils_entity_lifetime::Request_DestroyEntity(Entity); }
        }
    }

    UFUNCTION()
    private void Check_WallsGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Gone = true;
        for (const auto& Wall : _Walls)
        { Gone = Gone && (ck::Is_NOT_Valid(Wall) || utils_jolt_body::Get_IsBodyAdded(Wall) == false); }

        auto Result = OutResult;
        Result.Set(Gone);
    }

    // A build requested while the walls were still leaving failed as [Stale Geometry] (phase7-run01): rebuild only after.
    UFUNCTION()
    private void Step_Rebuild(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        RequestBuild(2, true);
    }

    UFUNCTION()
    private void Check_Rebuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(CountOutcome(2) == 1);
        if (CountOutcome(2) == 1)
        {
            const auto Outcome = FindOutcome(2);
            Assert_True(Outcome.Get_HasBakeStatus() && Outcome.Get_BakeStatus() == ECk_GroundNav_BakeStatus::Completed,
                "the rebuild without the walls completed");
        }
    }

    UFUNCTION()
    private void Check_Emerged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Raid.Get_EmergencesRequested() >= 1);
    }
}
