// The feed moves its own hand node: nothing in the test touches it. The spec's hand geometry rests the hand at a turned pose
// off the node's built offset, puts the hand k_HandAboveCm above the reserved piece's middle at the grasp and above the
// release node at the release. Once sourced the node sits at the rest pose (the kernel wrote it); in the grasp its offset
// stands over the reserved piece's middle, raised by the hand geometry and no more than the clearance on top; while the
// release awaits its admission it stands over the release node, level; after a rejection the hand comes home to the rest
// pose again.
class UMars_AutoTest_CookingFeed_TheKernelMovesTheHandNode : UMars_AutoTestRig_CookingFeed
{
    default _TimeoutSeconds = 20.0f;

    private const float64 k_HandAboveCm = 10.0;
    private const float32 k_ClearanceCm = 6.0f;
    private const FRotator k_RestRotation = FRotator(0.0, 90.0, 180.0);
    private const FVector k_RestLift = FVector(0.0, 0.0, 5.0);
    // Polls in the grasp before its offset is read: the pose the kernel writes is applied after the phase edge.
    private const int32 k_GraspPolls = 2;
    private const float64 k_Tolerance = 0.5;

    private FMars_CookingFeed_HandGeometry _Hand;
    private int32 _GraspPollCount = 0;
    private FTransform _GraspOffset;
    private FVector _GraspPieceMiddle;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Timing = FMars_CookingFeed_TimingSpec(0.4f, 0.6f, 0.4f, 0.4f);
        _Hand = FMars_CookingFeed_HandGeometry();
        _Hand.RestLocal = FTransform(k_RestRotation, k_HandLocal + k_RestLift);
        _Hand.GraspLocal = FTransform(FVector(0.0, 0.0, k_HandAboveCm));
        _Hand.ReleaseLocal = FTransform(FVector(0.0, 0.0, k_HandAboveCm));
        _Hand.ClearanceCm = k_ClearanceCm;
        Spec.Hand = TOptional<FMars_CookingFeed_HandGeometry>(_Hand);
        BuildFeed(InHandle, Spec);

        Add_Steps_SourceTheFeed();
        Add_Step_WaitUntil("the pile is settled", n"Check_PileSettled", k_SlowPolls, 0);
        Add_Step_WaitUntil("the hand rests at the geometry's rest pose", n"Check_HandAtRest", 0, 0);
        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand is in the grasp", n"Check_GraspSampled", 0, 0);
        Add_Step("the hand stands over the reserved piece's middle", n"Step_AssertGrasp");
        Add_Step_WaitUntil("the release awaits its admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("the hand stands over the release node; reject", n"Step_AssertReleaseAndReject");
        Add_Step_WaitUntil("the feed is idle", n"Check_Idle", 0, 0);
        Add_Step_WaitUntil("the hand is home at the rest pose", n"Check_HandAtRest", 0, 0);
        Add_Step("the hand went through the return", n"Step_AssertReturned");
        Run_Steps(InHandle);
    }

    private FTransform Get_HandOffset() const
    {
        return utils_scene_node::Get_Offset(_HandNode);
    }

    UFUNCTION()
    private void Check_HandAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HandOffset().Equals(_Hand.RestLocal, 0.01));
    }

    // The offset and the piece's middle are read together on the k_GraspPolls-th poll in the grasp.
    UFUNCTION()
    private void Check_GraspSampled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Feed.Get_Phase() != EMars_CookingFeed_Phase::Grasp)
        {
            Res.Set(_Feed.Get_Phase() != EMars_CookingFeed_Phase::Reach && _Feed.Get_Phase() != EMars_CookingFeed_Phase::Idle);
            return;
        }

        _GraspPollCount += 1;
        if (_GraspPollCount < k_GraspPolls)
        {
            Res.Set(false);
            return;
        }

        const auto Piece = _Feed.TryGet_ActiveFoodPiece();
        FCk_Handle Entity = Piece;
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        _GraspPieceMiddle = FTransform(k_Origin).InverseTransformPosition(PieceWorld.TransformPosition(Get_BoundsCenter(Piece)));
        _GraspOffset = Get_HandOffset();
        Res.Set(true);
    }

    UFUNCTION()
    private void Step_AssertGrasp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_GraspPollCount >= k_GraspPolls, f"the grasp was seen (it lasted {_GraspPollCount} poll(s))");
        if (_GraspPollCount < k_GraspPolls)
        { return; }

        const auto Hand = _GraspOffset.GetLocation();
        Assert_Equals_Float(Hand.X, _GraspPieceMiddle.X, k_Tolerance, "the hand stands over the piece's middle in X");
        Assert_Equals_Float(Hand.Y, _GraspPieceMiddle.Y, k_Tolerance, "the hand stands over the piece's middle in Y");
        const auto Above = Hand.Z - _GraspPieceMiddle.Z;
        Assert_True(Above >= k_HandAboveCm - k_Tolerance && Above <= k_HandAboveCm + float64(k_ClearanceCm) + k_Tolerance,
            f"the hand is {k_HandAboveCm} above the middle plus at most the clearance (got {Above})");
        Assert_True(_GraspOffset.GetRotation().Equals(_Hand.GraspLocal.GetRotation(), 0.001), "the hand holds the grasp's rotation");
    }

    UFUNCTION()
    private void Step_AssertReleaseAndReject(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Expected = k_ReleaseLocal + FVector(0.0, 0.0, k_HandAboveCm);
        const auto Offset = Get_HandOffset();
        Assert_True(Offset.GetLocation().Equals(Expected, k_Tolerance), f"the hand stands over the release node (got {Offset.GetLocation()}, want {Expected})");
        Assert_True(Offset.GetRotation().Equals(_Hand.ReleaseLocal.GetRotation(), 0.001), "the hand holds the release's rotation");

        Step_RejectPending(InHandle, InPayload);
    }

    UFUNCTION()
    private void Step_AssertReturned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_PhaseCount(EMars_CookingFeed_Phase::Return), 1, "the hand went through one return");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Rejected), 1, "the transfer settled Rejected");
        Assert_True(Get_HandOffset().Equals(_Hand.RestLocal, 0.01), "the hand rests at the rest pose");
    }
}
