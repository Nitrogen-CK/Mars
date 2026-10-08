// The release node slides along +Y at 500 uu/s through the whole transfer: the release carries the node's pose of that
// frame, and its velocity is the spec's local drop (0, 0, -20) plus half the node's measured velocity, (0, 250, 0), within
// 20 percent.
class UMars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity : UMars_AutoTestRig_CookingFeed
{
    private const float64 k_Speed = 500.0;
    private const float64 k_Tolerance = 0.2;

    private float32 _MoveStart = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());

        Add_Step("start moving the release node", n"Step_StartMoving");
        Add_Step_WaitUntil("the node has moved for 0.2 s", n"Check_MovedAWhile", 0, 1.0f);
        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the release while the node moves", n"Check_ReleasedWhileMoving", 0, 2.0f);
        Add_Step("the release follows the node and inherits its velocity", n"Step_AssertRelease");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_StartMoving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _MoveStart = float32(System::GetGameTimeInSeconds());
    }

    // The node's offset this frame: k_Speed along +Y since the start.
    private void Move_ReleaseNode()
    {
        const auto Elapsed = float64(System::GetGameTimeInSeconds()) - float64(_MoveStart);
        utils_scene_node::Request_UpdateOffset(_ReleaseNode,
            FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(k_ReleaseLocal + FVector(0.0, k_Speed * Elapsed, 0.0))));
    }

    UFUNCTION()
    private void Check_MovedAWhile(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Move_ReleaseNode();
        auto Res = OutResult;
        Res.Set(float32(System::GetGameTimeInSeconds()) - _MoveStart >= 0.2f);
    }

    UFUNCTION()
    private void Check_ReleasedWhileMoving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Move_ReleaseNode();
        auto Res = OutResult;
        Res.Set(_Releases.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 1, "one release");
        if (_Releases.Num() != 1)
        { return; }

        const auto Release = _Releases[0];
        const auto NodeWorld = _ReleaseNodeAtRelease[0];
        const auto Gap = Release.WorldTransform.GetLocation().Distance(NodeWorld.GetLocation());
        Assert_True(Gap <= 0.5, f"the release is at the node's pose that frame (gap {Gap})");

        const auto RootWorld = FTransform(FRotator::ZeroRotator, k_Origin);
        const auto Travelled = RootWorld.InverseTransformPosition(Release.WorldTransform.GetLocation()).Y;
        Assert_True(Travelled > 50.0, f"the node had moved when it was sampled ({Travelled} uu along Y)");

        const auto Expected = FVector(0.0, 0.5 * k_Speed, -20.0);
        const auto Velocity = Release.LinearVelocity;
        Log(f"[Mars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity] release velocity {Velocity}, expected about {Expected}");
        Assert_True(Math::Abs(Velocity.Y - Expected.Y) <= Expected.Y * k_Tolerance, f"inherited half the node's speed along Y (got {Velocity.Y})");
        Assert_True(Math::Abs(Velocity.Z - Expected.Z) <= 20.0 * k_Tolerance, f"the local drop along -Z (got {Velocity.Z})");
        Assert_True(Math::Abs(Velocity.X) <= 0.5 * k_Speed * k_Tolerance, f"nothing along X (got {Velocity.X})");
        Assert_True(Release.AngularVelocity.IsNearlyZero(0.001), "no spin");
    }
}
