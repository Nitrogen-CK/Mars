// A client standing on an engine cube is not corrected: the client's controller holds the pawn still on the rig's
// floor, a spawned engine cube each machine builds for itself. On the client the pawn stands on the floor over the
// whole row and no correction arrives; on the host its copy stands there, never drifting, and the host corrects none
// of the client's moves. How many of them named a base is logged.
class UCk_AutoTest_Net_MovementBase_AClientStandingOnAnEngineCubeIsNotCorrected : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(818000.0, 0.0, 5000.0);
    // A copy standing still moves less than this in the plane over its settled samples.
    private const float64 k_MaxDriftCm = 1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_ClientOwnedRow("AClientStandingOnAnEngineCubeIsNotCorrected", k_Base,
            EMars_TESTONLY_MovementBaseNet_ClientCourse::StandOnTheFloor);
    }

    protected void Assert_ServerRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        const auto Drift = Get_MbSettledPlanarDrift();
        const auto OffHeight = Get_MbLargestOffHeight(_MbSettleStartIndex, 0.0);
        Assert_True(Get_IsOnFloor(), f"the server's copy stands on the floor (feet {Get_FeetAboveFloor() :.1})");
        Assert_True(Drift >= 0.0 && Drift <= k_MaxDriftCm, f"the server's copy does not drift in the plane ({Drift :.2} cm)");
        Assert_True(OffHeight >= 0.0 && OffHeight <= k_StandToleranceCm,
            f"the server's copy stays at the floor's height (largest off {OffHeight :.2})");
        Assert_Equals_Int(Counts.CorrectionsMade, 0, "the server corrects none of the client's moves");
    }

    protected void Assert_ClientRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        auto OffFloor = 0;
        for (int32 Index = Math::Max(_MbWindowStartIndex, 0); Index < _CourseSamples.Num(); ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            if (Math::Abs(Sample.FeetZ) > k_StandToleranceCm || Sample.Mode != EMovementMode::MOVE_Walking)
            { OffFloor += 1; }
        }

        Assert_True(_MbWindowStartIndex >= 0, "the client's window opened");
        Assert_Equals_Int(OffFloor, 0, "the client's pawn stands on the floor throughout");
        Assert_Equals_Int(Counts.CorrectionsReceived, 0, "no correction reaches the client");
    }
}
