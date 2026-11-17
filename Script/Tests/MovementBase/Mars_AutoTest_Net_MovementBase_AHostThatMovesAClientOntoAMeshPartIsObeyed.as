// A host that moves a client onto a mesh part is obeyed: the client's controller holds the pawn still on the top of a
// platform built as a mesh part; a while later the host teleports the pawn onto the top of a second mesh part, the
// pad, 12 m away. Both parts are built by each machine for itself. The client's pawn stands on the pad within three
// seconds of the host's move (the host logs the move's frame, the client the frame it arrived), having taken at least
// one correction and dropped none; the host's copy ends on the pad in MOVE_Walking.
class UCk_AutoTest_Net_MovementBase_AHostThatMovesAClientOntoAMeshPartIsObeyed : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(817000.0, 0.0, 5000.0);
    // The client stands on the pad at most this long after the host's move, in course seconds.
    private const float32 k_PadReachSeconds = 3.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_ClientOwnedRow("AHostThatMovesAClientOntoAMeshPartIsObeyed", k_Base,
            EMars_TESTONLY_MovementBaseNet_ClientCourse::MovedOntoThePad);
    }

    protected void Assert_ServerRow() override
    {
        Assert_True(_MbPadMoveFrame >= 0, "the server moved the pawn onto the pad");
        Assert_True(Get_IsOnPad(), f"the server's copy ends on the pad in MOVE_Walking (feet {Get_FeetAboveFloor() :.1})");
    }

    // The host moves the pawn k_ComposeSeconds of its course clock after it handed the pawn over, and the client's
    // course clock starts when it takes the pawn, a few frames later.
    protected void Assert_ClientRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        Assert_True(_MbOnPadFrame >= 0 && _MbOnPadSeconds <= k_ComposeSeconds + k_PadReachSeconds,
            f"the client's pawn stands on the pad within {k_PadReachSeconds} s of the host's move (at {_MbOnPadSeconds :.2} s)");
        Assert_True(Get_IsOnPad(), f"the client's pawn ends on the pad (feet {Get_FeetAboveFloor() :.1})");
        Assert_True(Counts.CorrectionsReceived >= 1, f"a correction reached the client ({Counts.CorrectionsReceived})");
        Assert_Equals_Int(Counts.CorrectionsDropped, 0, "the client drops no correction");
    }
}
