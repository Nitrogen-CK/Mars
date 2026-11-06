// A hovering bat (its roost gone, nowhere to go) set down inside a solid block: its own spot is not goal-free, so the
// kernel's climb-out moves it toward the nearest clear point on its own, out through the block's nearest face. This is
// the deterministic half of the PIE stranding (the agent overshot into a wall's clearance band and every route failed):
// a route failure from inside blocked space cannot be forced headless, the voxel planner snaps such a start to a
// neighbour, so the test exercises the Hovering trigger instead of the route-failure one.
class UMars_AutoTest_Bat_ClimbsOutOfBlockedSpaceWhileHovering : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(320000.0, -216000.0, 2000.0);

    // A 400 cube off the bat's way to the target; the bat is set down 120 cm inside its west face.
    private const FVector k_BlockCentre = FVector(400.0, 400.0, 300.0);
    private const float64 k_BlockHalf = 200.0;
    private const float64 k_StuckInset = 120.0;
    private FVector _StuckAt;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, _Origin + k_BlockCentre), FVector(k_BlockHalf, k_BlockHalf, k_BlockHalf));
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("its first swoop lands", n"Check_Landed", 0, k_FlightSeconds);
        Add_Step("the target and the roost are gone", n"Step_DestroyTargetAndRoost");
        Add_Step_WaitUntil("it hovers with nowhere to go", n"Check_Hovering", 0, 10.0f);
        Add_Step("it is set down inside the block", n"Step_Strand");
        Add_Step_WaitUntil("it climbs clear of the block", n"Check_Clear", 0, 10.0f);
        Add_Step("it came out on its own", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Landed.Num() >= 1);
    }

    UFUNCTION()
    private void Step_DestroyTargetAndRoost(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        DestroyTarget();
        utils_entity_lifetime::Request_DestroyEntity(_Roost);
    }

    UFUNCTION()
    private void Check_Hovering(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Hovering && _Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::None);
    }

    // The root is moved under the stopped agent, as a collision push or an overshoot would.
    UFUNCTION()
    private void Step_Strand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _StuckAt = _Origin + k_BlockCentre - FVector(k_BlockHalf - k_StuckInset, 0.0, 0.0);
        auto Root = _Bat.As_Transform();
        utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(_StuckAt));
        Assert_False(utils_voxel_nav_volume::Get_IsPointFree(_Volume, _StuckAt), "inside the block is not free space");
    }

    UFUNCTION()
    private void Check_Clear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_IsGoalFree(_Bat.Get_Location()));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Here = _Bat.Get_Location();
        const auto BlockMin = _Origin + k_BlockCentre - FVector(k_BlockHalf, k_BlockHalf, k_BlockHalf);
        const auto BlockMax = _Origin + k_BlockCentre + FVector(k_BlockHalf, k_BlockHalf, k_BlockHalf);
        const auto Inside = Here.X > BlockMin.X && Here.X < BlockMax.X && Here.Y > BlockMin.Y && Here.Y < BlockMax.Y && Here.Z > BlockMin.Z && Here.Z < BlockMax.Z;
        Log(f"[BatTest] stranded at {_StuckAt.ToString()}, now at {Here.ToString()}; phases {Get_PhaseTrail()}");
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Hovering, "it still hovers (no route moved it)");
        Assert_False(Inside, f"it is out of the block (at {Here.ToString()})");
        Assert_True((Here - _StuckAt).Size() <= 400.0, "it took the short way out");
        Assert_True(Here.X < _StuckAt.X, "it left through the nearest (west) face");
    }
}
