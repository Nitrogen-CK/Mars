// A client walking on a mesh part is followed on the host: the client's controller walks the pawn along +X on the top
// of a platform built as a mesh part, which each machine builds for itself. On the client the pawn walks at least
// 50 cm and ends on the top with no correction. On the host its copy reads only MOVE_Walking at the top's height,
// never jumps more than a walk's frame in the plane and ends along the walk, and the host corrects none of the moves.
class UCk_AutoTest_Net_MovementBase_AClientWalkingOnAMeshPartIsFollowedOnTheHost : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(815000.0, 0.0, 5000.0);
    private const float64 k_MinWalkCm = 50.0;
    // A walk frame is under 8 cm at the walk speed; past this the copy was put somewhere.
    private const float64 k_MaxStepCm = 25.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_ClientOwnedRow("AClientWalkingOnAMeshPartIsFollowedOnTheHost", k_Base,
            EMars_TESTONLY_MovementBaseNet_ClientCourse::WalkOnThePlatform);
    }

    protected void Assert_ServerRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        const auto NotWalking = Get_MbSamplesNotWalking(_MbWindowStartIndex);
        const auto OffHeight = Get_MbLargestOffHeight(_MbWindowStartIndex, k_PlatformHeight);
        const auto Step = Get_LargestPlanarStep(_MbWindowStartIndex);
        const auto Along = _Pawn.GetActorLocation().X - _Base.X - k_MbPlatformCentre.X;
        Assert_Equals_Int(NotWalking, 0, "every sample of the server's copy in the window reads MOVE_Walking");
        Assert_True(OffHeight >= 0.0 && OffHeight <= k_StandToleranceCm,
            f"the server's copy stays at the top's height (largest off {OffHeight :.2})");
        Assert_True(Step <= k_MaxStepCm, f"the server's copy never jumps in the plane (largest step {Step :.2})");
        Assert_True(Along >= k_MinWalkCm, f"the server's copy ends along the walk ({Along :.1} cm)");
        Assert_True(Counts.ClientMovesReceived > 0, f"the server checked the client's moves ({Counts.ClientMovesReceived})");
        Assert_Equals_Int(Counts.CorrectionsMade, 0, "the server corrects none of the client's moves");
    }

    protected void Assert_ClientRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        const auto Along = ck::IsValid(_Pawn) ? _Pawn.GetActorLocation().X - _Base.X - k_MbPlatformCentre.X : 0.0;
        Assert_True(Along >= k_MinWalkCm, f"the client's pawn walked along +X ({Along :.1} cm)");
        Assert_True(Get_IsOnPlatformTop(), f"the client's pawn ends on the platform's top (feet {Get_FeetAboveFloor() :.1})");
        Assert_Equals_Int(Counts.CorrectionsReceived, 0, "no correction reaches the client");
    }
}
