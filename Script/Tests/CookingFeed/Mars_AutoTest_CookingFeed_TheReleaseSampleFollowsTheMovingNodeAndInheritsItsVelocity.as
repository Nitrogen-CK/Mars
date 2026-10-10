// The release node slides along +Y at 500 uu/s through the whole transfer, and the feed carries its hand to it (the test
// spec's hand geometry puts the held piece's middle on the node at the release): the release carries the carried piece's
// pose of that frame, its middle on the node as the feed last read it (the hand follows the node it sampled the frame
// before, so it trails by at most two frames of the node's travel), and its velocity is the spec's local drop
// (0, 0, -20) plus half the node's measured velocity, (0, 250, 0), within 20 percent.
class UMars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity : UMars_AutoTestRig_CookingFeed
{
    private const float64 k_Speed = 500.0;
    private const float64 k_Tolerance = 0.2;

    private float32 _MoveStart = 0.0f;
    // The longest frame seen while the node moved: the hand's trail is bounded by two of them.
    private float32 _LongestFrameSeconds = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // A carry long enough that its easing has settled onto the node by its last frame.
        auto Spec = Make_TestSpec();
        Spec.Timing = FMars_CookingFeed_TimingSpec(0.1f, 0.05f, 0.5f, 0.1f);
        BuildFeed(InHandle, Spec);
        Add_Steps_SourceTheFeed();

        Add_Step("start moving the release node", n"Step_StartMoving");
        Add_Step_WaitUntil("the node has moved for 0.2 s", n"Check_MovedAWhile", k_SlowPolls, 0);
        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the release while the node moves", n"Check_ReleasedWhileMoving", 0, 0);
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
        const auto NodeLocal = k_ReleaseLocal + FVector(0.0, k_Speed * Elapsed, 0.0);
        utils_scene_node::Request_UpdateOffset(_ReleaseNode, FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(NodeLocal)));
        _LongestFrameSeconds = Math::Max(_LongestFrameSeconds, float32(Gameplay::GetWorldDeltaSeconds()));
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
        const auto Centre = Release.WorldTransform.TransformPosition(utils_searing::Get_BoundsCentre(utils_runtime_mesh::Get_Metrics(Release.Piece.Get_Geometry())));
        const auto Gap = Centre.Distance(NodeWorld.GetLocation());
        const auto Trail = 2.0 * k_Speed * float64(_LongestFrameSeconds) + 1.0;
        Assert_True(Gap <= Trail, f"the released piece's middle is on the node the hand followed (gap {Gap}, two frames' travel {Trail})");

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
