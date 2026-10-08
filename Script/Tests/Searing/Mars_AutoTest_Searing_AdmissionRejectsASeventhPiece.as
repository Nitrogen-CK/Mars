// With Supply.MaxPieces 1 the first release is Accepted and a second, different Id is Rejected with a reason naming the
// limit: one body, nothing made for the second.
class UMars_AutoTest_Searing_AdmissionRejectsASeventhPiece : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 8.0f;

    private const FVector k_FirstLocal = FVector(-8.0, 0.0, 8.0);
    private const FVector k_SecondLocal = FVector(8.0, 0.0, 8.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Supply.MaxPieces = 1;
        BuildStation(InHandle, Spec);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step("release two different pieces", n"Step_ReleaseTwo");
        Add_Step_WaitUntil("both releases were answered", n"Check_Answered2", 0, 1.0f);
        Add_Step_WaitFrames("anything made would show", 2);
        Add_Step("the first is accepted, the one past MaxPieces rejected", n"Step_AssertLimit");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ReleaseTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPieceAt(k_FirstLocal);
        AddPieceAt(k_SecondLocal);
    }

    UFUNCTION()
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertLimit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 2, "two answers");
        if (_Admissions.Num() < 2)
        { return; }

        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, "the first piece is accepted");
        Assert_True(_Admissions[1] == EMars_CookingFeed_Admission::Rejected, "the piece past MaxPieces is rejected");
        Assert_True(_AdmissionReasons[1].Contains("MaxPieces"), f"the rejection names the limit (got {_AdmissionReasons[1]})");
        Assert_False(_AdmissionIds[0].Get_IsSame(_AdmissionIds[1]), "the two releases carried different Ids");
        Assert_Equals_Int(_Added.Num(), 1, "one OnPieceAdded");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "one piece on the books");
    }
}

class AMars_AutoTest_Searing_AdmissionRejectsASeventhPiece_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 8.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AdmissionRejectsASeventhPiece;
}
