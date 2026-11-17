// A host's jump off a ladder lands on the client: the host's own controller climbs the pawn until its feet are 150
// above the floor, jumps off and lands on the floor, which no other machine can address. On the client the copy reads
// MOVE_Falling in the air with no base (the control: a copy applies the host's mode while nothing is reported), then,
// over the second after it settled on the floor, MOVE_Walking with no base reported by the host.
class UCk_AutoTest_Net_MovementBase_AHostsJumpOffALadderLandsOnTheClient : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(804000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_HostOwnedRow("AHostsJumpOffALadderLandsOnTheClient", k_Base, EMars_TESTONLY_MovementBaseNet_HostCourse::JumpOffAtHeight);
    }

    protected void Assert_ServerRow() override
    {
        const auto Climber = Get_CourseClimber();
        const auto IsJump = ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet()
            && Climber.Get_LastDismount().GetValue() == EMars_Climber_Dismount::Jump;
        Assert_True(IsJump, "the server's climb ended Jump");
        Assert_True(Get_IsOnFloor(), "the server's pawn stands on the floor");
    }

    // A sample after the copy's feet passed the jump's height and before they came near the floor read MOVE_Falling
    // with no base.
    private bool Get_HasFallingSampleInTheAir()
    {
        if (_MbPassedJumpFeetFrame < 0)
        { return false; }

        for (int32 Index = Get_IndexAtFrame(_MbPassedJumpFeetFrame); Index < _CourseSamples.Num(); ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            if (Math::Abs(Sample.FeetZ) <= k_StandToleranceCm)
            { return false; }

            if (Sample.Mode == EMovementMode::MOVE_Falling && Sample.NetBase == EMars_Character_NetBase::None)
            { return true; }
        }

        return false;
    }

    protected void Assert_ClientRow() override
    {
        Assert_True(_MbPassedJumpFeetFrame >= 0, "the client's copy's feet passed the jump's height");
        Assert_True(Get_HasFallingSampleInTheAir(), "the client's copy read MOVE_Falling with no base in the air");
        Assert_True(Math::Abs(Get_FeetAboveFloor()) <= k_StandToleranceCm,
            f"the client's copy stands on the floor (feet {Get_FeetAboveFloor() :.1})");
        Assert_True(Get_SettledSampleCount() > 0, "the client's copy has samples in its settled second");
        Assert_Equals_Int(Get_SettledSamplesNotReading(EMovementMode::MOVE_Walking, EMars_Character_NetBase::None), 0,
            "every sample of the settled second on the floor reads MOVE_Walking with no base reported");
    }
}
