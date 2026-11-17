// A client standing on a mesh part is not corrected: the client's controller holds the pawn still on the top of a
// platform built as a mesh part, which each machine builds for itself. On the client the pawn stands on the top over
// the whole row and no correction arrives. On the host its copy stands there too, never drifting in the plane and
// never leaving the top's height, while the host checks the client's moves and corrects none.
class UCk_AutoTest_Net_MovementBase_AClientStandingOnAMeshPartIsNotCorrected : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(814000.0, 0.0, 5000.0);
    // A copy standing still moves less than this in the plane over its settled samples.
    private const float64 k_MaxDriftCm = 1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_ClientOwnedRow("AClientStandingOnAMeshPartIsNotCorrected", k_Base,
            EMars_TESTONLY_MovementBaseNet_ClientCourse::StandOnThePlatform);
    }

    protected void Assert_ServerRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        const auto Drift = Get_MbSettledPlanarDrift();
        const auto OffHeight = Get_MbLargestOffHeight(_MbSettleStartIndex, k_PlatformHeight);
        Assert_True(Get_IsOnPlatformTop(), f"the server's copy stands on the platform's top (feet {Get_FeetAboveFloor() :.1})");
        Assert_True(Drift >= 0.0 && Drift <= k_MaxDriftCm, f"the server's copy does not drift in the plane ({Drift :.2} cm)");
        Assert_True(OffHeight >= 0.0 && OffHeight <= k_StandToleranceCm,
            f"the server's copy stays at the top's height (largest off {OffHeight :.2})");
        Assert_True(Counts.ClientMovesReceived > 0, f"the server checked the client's moves ({Counts.ClientMovesReceived})");
        Assert_Equals_Int(Counts.CorrectionsMade, 0, "the server corrects none of the client's moves");
    }

    protected void Assert_ClientRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        Assert_Equals_Int(Get_MbWindowSamplesOffPlatformTop(), 0, "the client's pawn stands on the platform's top throughout");
        Assert_Equals_Int(Counts.CorrectionsReceived, 0, "no correction reaches the client");
    }
}
