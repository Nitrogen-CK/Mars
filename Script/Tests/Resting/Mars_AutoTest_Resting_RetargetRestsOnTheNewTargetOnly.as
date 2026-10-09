// A box resting on plate A (its only target) is retargeted onto plate B while it still lies on A: it reads Apart at once
// (OnRestingChanged reports the edge), its only target is B, its hops are zeroed, and asking about A ensures as a target it
// no longer has. Teleported over B it lands there and rests on B. Clear of the other Resting tests at k_Offset.
class UMars_AutoTest_Resting_RetargetRestsOnTheNewTargetOnly : UMars_AutoTestRig_Resting
{
    default _TimeoutSeconds = 8.0f;

    private const FVector k_Offset = FVector(0.0, 2000.0, 0.0);
    private const FVector k_PlateBOffset = FVector(0.0, 200.0, 0.0);
    // The retarget drains in the next frame or two; a stray contact with A would show by then.
    private const int32 k_RetargetFrames = 3;

    private FCk_Handle_JoltBody _PlateA;
    private FCk_Handle_JoltBody _PlateB;
    private FCk_Handle _RetargetBox;
    private FCk_Handle_Resting _RetargetResting;
    private int32 _StatesBeforeRetarget = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_Offset), ECk_Replication::DoesNotReplicate);
        _PlateA = Build_Plate(utils_scene_node::Create(Root, FTransform(FVector(0.0, 0.0, k_PlateRestZ))));
        _PlateB = Build_Plate(utils_scene_node::Create(Root, FTransform(k_PlateBOffset + FVector(0.0, 0.0, k_PlateRestZ))));

        _RetargetBox = Build_Box(InHandle, k_Origin + k_Offset + Get_BoxDropLocal());
        _RetargetResting = utils_resting::Add(_RetargetBox, FMars_Resting_Spec(_PlateA));
        _RetargetResting.BindTo_OnRestingChanged(FMars_Delegate_Resting_OnRestingChanged(this, n"OnRestingChanged"));

        Add_Step_WaitUntil("the box rests on plate A", n"Check_OnA", 0, 2.0f);
        Add_Step("retarget the box onto plate B while it lies on A", n"Step_Retarget");
        Add_Step_WaitFrames("the retarget drains", k_RetargetFrames);
        Add_Step("apart, B its only target, A no target at all; teleport the box over B", n"Step_AssertRetargetedThenMoveToB");
        Add_Step_WaitUntil("the box rests on plate B", n"Check_OnB", 0, 3.0f);
        Add_Step("resting on B", n"Step_AssertOnB");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_OnA(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RetargetResting.Get_IsRestingOn(_PlateA));
    }

    UFUNCTION()
    private void Step_Retarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RetargetResting.Get_IsResting(), "resting on A before the retarget");
        _StatesBeforeRetarget = _States.Num();

        TArray<FCk_Handle> Targets;
        Targets.Add(_PlateB);
        _RetargetResting.Request_Retarget(FMars_Request_Resting_Retarget(Targets, 0.1f, 0.12f));
    }

    UFUNCTION()
    private void Step_AssertRetargetedThenMoveToB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const FCk_Handle PlateB = _PlateB;
        const auto Targets = _RetargetResting.Get_Targets();
        Assert_Equals_Int(Targets.Num(), 1, "one target after the retarget");
        Assert_True(Targets.Num() == 1 && Targets[0] == PlateB, "the target is plate B");

        Assert_False(_RetargetResting.Get_IsResting(), "lying on A, which is no longer a target, the box is not resting");
        Assert_False(_RetargetResting.Get_IsRestingOn(_PlateB), "not resting on B before it is there");
        Assert_Equals_Int(_RetargetResting.Get_Hops(), 0, "the retarget zeroed the hops");
        Assert_True(_States.Num() == _StatesBeforeRetarget + 1 && _States.Last() == EMars_Resting_State::Apart,
            "OnRestingChanged reported the Apart edge once");

        Assert_False(_RetargetResting.Get_IsRestingOn(_PlateA), "asking about A, no longer a target, answers false (and ensures)");

        const auto OverB = k_Origin + k_Offset + k_PlateBOffset + Get_BoxDropLocal();
        auto Body = _RetargetBox.As_JoltBody();
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(OverB, FRotator::ZeroRotator));
    }

    UFUNCTION()
    private void Check_OnB(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RetargetResting.Get_IsRestingOn(_PlateB));
    }

    UFUNCTION()
    private void Step_AssertOnB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_RetargetResting.Get_IsResting(), "resting (on its one target)");
        Assert_True(_RetargetResting.Get_IsRestingOn(_PlateB), "resting on plate B");
        Assert_True(_States.Last() == EMars_Resting_State::Resting, "OnRestingChanged reported the landing on B");
    }
}

// Hand-authored so the ensure the test provokes on purpose (asking about a target the Resting no longer has) is expected
// rather than a failure.
class AMars_AutoTest_Resting_RetargetRestsOnTheNewTargetOnly_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Resting_RetargetRestsOnTheNewTargetOnly;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("has no target [");
        return Out;
    }
}
