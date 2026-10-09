// A Reset and an AddPiece issued in one frame share a drain: the piece is Rejected with the reason "reset in the same drain"
// and left as it was (a release broadcast the frame the operator leaves must not land in the fresh attempt). A release in
// a later drain is admitted as usual.
class UMars_AutoTest_Searing_AResetRejectsAnAddPieceInTheSameDrain : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 8.0f;

    private const FVector k_Local = FVector(0.0, 0.0, 8.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(2);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("reset and release one piece in the same frame", n"Step_ResetAndRelease");
        Add_Step_WaitUntil("the release was answered", n"Check_Answered1", 0, 1.0f);
        Add_Step_WaitFrames("anything made would show", 2);
        Add_Step("rejected for the reset, nothing made; release another", n"Step_AssertRejectedThenRelease");
        Add_Step_WaitUntil("the second release was answered", n"Check_Answered2", 0, 1.0f);
        Add_Step("a release in its own drain is admitted", n"Step_AssertAdmitted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ResetAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Searing.Request_Reset(FMars_Request_Searing_Reset());
        AddPieceAt(k_Local);
    }

    UFUNCTION()
    private void Check_Answered1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1);
    }

    UFUNCTION()
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertRejectedThenRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 1, "one answer");
        if (_Admissions.Num() < 1)
        { return; }

        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Rejected, "the release sharing the reset's drain is rejected");
        Assert_True(_AdmissionReasons[0] == "reset in the same drain", f"the reason names the reset (got {_AdmissionReasons[0]})");
        Assert_Equals_Int(_Added.Num(), 0, "no OnPieceAdded");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, "no piece on the books");
        Assert_Equals_Int(_Searing.Get_Summary().Admitted, 0, "the summary admits none");

        AddPieceAt(k_Local);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions.Num() >= 2 && _Admissions[1] == EMars_CookingFeed_Admission::Accepted, "a release in a later drain is accepted");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "one piece on the books");
    }
}

class AMars_AutoTest_Searing_AResetRejectsAnAddPieceInTheSameDrain_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 8.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AResetRejectsAnAddPieceInTheSameDrain;
}
