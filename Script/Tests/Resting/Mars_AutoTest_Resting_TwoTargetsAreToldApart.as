// A box with a Resting on two kinematic plates, A and B side by side: dropped on A it rests on A and not on B; teleported
// over B it lands there and rests on B and not on A. Get_IsResting (any target) holds on either plate. A spec naming one
// target twice is rejected.
class UMars_AutoTest_Resting_TwoTargetsAreToldApart : UMars_AutoTestRig_Resting
{
    default _TimeoutSeconds = 8.0f;

    // Clear of the single-plate rig at k_Origin; plate B sits 200 uu to plate A's +Y.
    private const FVector k_Offset = FVector(0.0, 1000.0, 0.0);
    private const FVector k_PlateBOffset = FVector(0.0, 200.0, 0.0);

    private FCk_Handle_JoltBody _PlateA;
    private FCk_Handle_JoltBody _PlateB;
    private FCk_Handle _TwoBox;
    private FCk_Handle_Resting _TwoResting;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_Offset), ECk_Replication::DoesNotReplicate);
        _PlateA = Build_Plate(utils_scene_node::Create(Root, FTransform(FVector(0.0, 0.0, k_PlateRestZ))));
        _PlateB = Build_Plate(utils_scene_node::Create(Root, FTransform(k_PlateBOffset + FVector(0.0, 0.0, k_PlateRestZ))));

        _TwoBox = Build_Box(InHandle, k_Origin + k_Offset + Get_BoxDropLocal());
        TArray<FCk_Handle> Targets;
        Targets.Add(_PlateA);
        Targets.Add(_PlateB);
        _TwoResting = utils_resting::Add(_TwoBox, FMars_Resting_Spec(Targets, 0.1f, 0.12f));

        Add_Step("the two-target Resting composed; a repeated target is rejected", n"Step_AssertComposed");
        Add_Step_WaitUntil("the box rests on plate A", n"Check_OnAOnly", 0, 2.0f);
        Add_Step("on A, not on B; teleport the box over B", n"Step_AssertOnAThenMoveToB");
        Add_Step_WaitUntil("the box rests on plate B", n"Check_OnBOnly", 0, 3.0f);
        Add_Step("on B, not on A", n"Step_AssertOnB");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_TwoResting), "the feature composed");
        Assert_Equals_Int(_TwoResting.Get_Targets().Num(), 2, "two targets");
        const FCk_Handle PlateA = _PlateA;
        Assert_True(_TwoResting.Get_Target() == PlateA, "the first target is plate A");

        TArray<FCk_Handle> Repeated;
        Repeated.Add(_PlateA);
        Repeated.Add(_PlateA);
        const auto Validation = FMars_Resting_Spec(Repeated, 0.1f, 0.12f).Validate();
        Assert_False(Validation.IsValid(), "a spec naming plate A twice is rejected");
        Assert_True(Validation.Get_Error().Len() > 0, f"the rejection names its rule (error: {Validation.Get_Error()})");
    }

    UFUNCTION()
    private void Check_OnAOnly(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TwoResting.Get_IsRestingOn(_PlateA) && _TwoResting.Get_IsRestingOn(_PlateB) == false);
    }

    UFUNCTION()
    private void Step_AssertOnAThenMoveToB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TwoResting.Get_IsResting(), "resting (on any target)");
        Assert_True(_TwoResting.Get_IsRestingOn(_PlateA), "resting on plate A");
        Assert_False(_TwoResting.Get_IsRestingOn(_PlateB), "not resting on plate B");

        const auto OverB = k_Origin + k_Offset + k_PlateBOffset + Get_BoxDropLocal();
        auto Body = _TwoBox.As_JoltBody();
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(OverB, FRotator::ZeroRotator));
    }

    UFUNCTION()
    private void Check_OnBOnly(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TwoResting.Get_IsRestingOn(_PlateB) && _TwoResting.Get_IsRestingOn(_PlateA) == false);
    }

    UFUNCTION()
    private void Step_AssertOnB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TwoResting.Get_IsResting(), "resting (on any target)");
        Assert_True(_TwoResting.Get_IsRestingOn(_PlateB), "resting on plate B");
        Assert_False(_TwoResting.Get_IsRestingOn(_PlateA), "not resting on plate A");
    }
}
