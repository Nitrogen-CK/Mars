// A host on a mesh-part platform walks on the client: as the engine-cube row, on a platform built the way entity
// scripts build their parts (a mesh part under an entity of each machine's own). The host's own controller climbs the
// pawn to the top; on the client the copy reaches the platform's place and, over the second after it settled, reads
// MOVE_Walking with no base reported by the host, standing on a base of its own.
class UCk_AutoTest_Net_MovementBase_AHostOnAMeshPartPlatformWalksOnTheClient : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(812000.0, 0.0, 5000.0);
    // A simulated copy follows its pawn's replicated place, which may lag a frame or two.
    private const float64 k_CopyStandToleranceCm = 25.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_HostOwnedRow("AHostOnAMeshPartPlatformWalksOnTheClient", k_Base,
            EMars_TESTONLY_MovementBaseNet_HostCourse::ClimbToTheTop);
    }

    protected EMars_TESTONLY_ClimberNet_Platform Get_PlatformKind() const override
    {
        return EMars_TESTONLY_ClimberNet_Platform::MeshPart;
    }

    protected void Assert_ServerRow() override
    {
        const auto Climber = Get_CourseClimber();
        const auto IsTop = ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet()
            && Climber.Get_LastDismount().GetValue() == EMars_Climber_Dismount::Top;
        Assert_True(IsTop, "the server's climb ended at the top");
        Assert_True(Get_IsOnPlatform(), "the server's pawn stands on the platform");
        Assert_True(_Pawn.Get_NetBase() == EMars_Character_NetBase::PerMachine,
            f"the server reads its mesh-part platform as a base it built for itself ({_Pawn.Get_NetBase() :n})");
    }

    protected void Assert_ClientRow() override
    {
        const auto Offset = _Pawn.GetActorLocation() - _Base;
        Assert_True(Math::Abs(Get_FeetAboveFloor() - k_PlatformHeight) <= k_CopyStandToleranceCm,
            f"the client's copy stands at the platform's height (feet {Get_FeetAboveFloor() :.1})");
        Assert_True(Math::Abs(Offset.X - k_ExitX) <= k_ExitToleranceCm && Math::Abs(Offset.Y) <= k_ExitToleranceCm,
            f"the client's copy stands by the exit ({Offset.X :.1}, {Offset.Y :.1})");
        Assert_True(Get_SettledSampleCount() > 0, "the client's copy has samples in its settled second");
        Assert_Equals_Int(Get_SettledSamplesNotReading(EMovementMode::MOVE_Walking, EMars_Character_NetBase::None), 0,
            "every sample of the settled second reads MOVE_Walking with no base reported");
        Assert_True(Get_HasSettledSampleWithABase(), "the client's copy stands on a base of its own");
    }
}
