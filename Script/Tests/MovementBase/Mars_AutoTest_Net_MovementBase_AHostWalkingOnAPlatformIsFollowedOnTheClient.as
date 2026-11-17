// A host walking on a platform is followed on the client: the host's own controller climbs the pawn to the top of its
// engine-cube platform, which no other machine can address, waits a second and walks toward the platform's centre.
// On the client the copy, from its first sample on the platform, reads only MOVE_Walking, never leaves the platform's
// height, never jumps more than a walk's frame in the plane and ends along the walk, past the exit.
class UCk_AutoTest_Net_MovementBase_AHostWalkingOnAPlatformIsFollowedOnTheClient : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(805000.0, 0.0, 5000.0);
    private const float64 k_MinWalkCm = 50.0;
    // A walk frame is under 8 cm at the walk speed; past this the copy was put somewhere.
    private const float64 k_MaxStepCm = 25.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_HostOwnedRow("AHostWalkingOnAPlatformIsFollowedOnTheClient", k_Base,
            EMars_TESTONLY_MovementBaseNet_HostCourse::ClimbToTheTopAndWalk);
    }

    protected void Assert_ServerRow() override
    {
        const auto Climber = Get_CourseClimber();
        const auto IsTop = ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet()
            && Climber.Get_LastDismount().GetValue() == EMars_Climber_Dismount::Top;
        const auto Walked = _Pawn.GetActorLocation().X - _Base.X - _MbWalkStartX;
        Assert_True(IsTop, "the server's climb ended at the top");
        Assert_True(Walked >= k_MinWalkCm, f"the server's pawn walked along +X ({Walked :.1} cm)");
        Assert_True(Math::Abs(Get_FeetAboveFloor() - k_PlatformHeight) <= k_StandToleranceCm
            && _Pawn.CharacterMovement.MovementMode == EMovementMode::MOVE_Walking,
            f"the server's pawn walks on the platform (feet {Get_FeetAboveFloor() :.1})");
    }

    protected void Assert_ClientRow() override
    {
        Assert_True(_CourseFirstPlatformFrame >= 0, "the client's copy stood on the platform");
        if (_CourseFirstPlatformFrame < 0)
        { return; }

        const auto From = Get_IndexAtFrame(_CourseFirstPlatformFrame);
        auto NotWalking = 0;
        auto LargestOffHeight = 0.0;
        for (int32 Index = From; Index < _CourseSamples.Num(); ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            if (Sample.Mode != EMovementMode::MOVE_Walking)
            { NotWalking += 1; }

            LargestOffHeight = Math::Max(LargestOffHeight, Math::Abs(Sample.FeetZ - k_PlatformHeight));
        }

        const auto Step = Get_LargestPlanarStep(From);
        const auto Along = _Pawn.GetActorLocation().X - _Base.X - k_ExitX;
        Assert_Equals_Int(NotWalking, 0, "every sample of the copy on the platform reads MOVE_Walking");
        Assert_True(LargestOffHeight <= k_StandToleranceCm,
            f"the copy's feet stay at the platform's height (largest off {LargestOffHeight :.2})");
        Assert_True(Step <= k_MaxStepCm, f"the copy never jumps in the plane (largest step {Step :.2})");
        Assert_True(Along >= k_MinWalkCm, f"the copy ends along the walk past the exit ({Along :.1} cm)");
    }
}
