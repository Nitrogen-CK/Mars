// A client's jump on a mesh part lands on the host: the client's controller jumps the pawn on the top of a platform
// built as a mesh part, which each machine builds for itself. On each machine the pawn is seen falling with its feet
// at least 20 cm over the top and then stands on the top again; the client receives no correction and the host makes
// none, after the landing as before it.
class UCk_AutoTest_Net_MovementBase_AClientsJumpOnAMeshPartLandsOnTheHost : UMars_AutoTestRig_NetMovementBase
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Base = FVector(816000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_ClientOwnedRow("AClientsJumpOnAMeshPartLandsOnTheHost", k_Base,
            EMars_TESTONLY_MovementBaseNet_ClientCourse::JumpOnThePlatform);
    }

    protected void Assert_ServerRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        auto OffTop = 0;
        for (int32 Index = Math::Max(_MbSettleStartIndex, 0); Index < _CourseSamples.Num(); ++Index)
        {
            if (Get_IsSampleOnPlatformTop(_CourseSamples[Index]) == false)
            { OffTop += 1; }
        }

        Assert_True(Get_HasMbJumpSample(), "the server's copy is seen falling with its feet over the top");
        Assert_Equals_Int(OffTop, 0, "every settled sample of the server's copy stands on the platform's top");
        Assert_Equals_Int(Counts.CorrectionsMade, 0, "the server corrects none of the client's moves");
    }

    protected void Assert_ClientRow() override
    {
        const auto Counts = Get_MbWindowCounts();
        Assert_True(Get_HasMbJumpSample(), "the client's pawn is seen falling with its feet over the top");
        Assert_True(Get_IsOnPlatformTop(), f"the client's pawn ends on the platform's top (feet {Get_FeetAboveFloor() :.1})");
        Assert_Equals_Int(Counts.CorrectionsReceived, 0, "no correction reaches the client");
    }
}
