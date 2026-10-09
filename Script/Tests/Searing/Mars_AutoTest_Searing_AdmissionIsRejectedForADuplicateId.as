// AddPiece answers every release through OnPieceAdmission: a fresh Id is Accepted (one body), the same Id released again
// with another piece, in the same drain or a later one, is Rejected with a reason and adopts nothing, and a different Id is
// still Accepted.
// (The before-the-pan-exists rejection is not driven here: the pan body cannot be held back from the simulation
// deterministically, so its rule is covered by reading Apply_AddPiece, not by this test.)
class UMars_AutoTest_Searing_AdmissionIsRejectedForADuplicateId : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 8.0f;

    private const FVector k_FirstLocal = FVector(-8.0, 0.0, 8.0);
    private const FVector k_ThirdLocal = FVector(8.0, 0.0, 8.0);

    private FMars_CookingFeed_PieceId _FirstId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        // Every release takes its own piece, so the repeats are refused for their Id alone.
        Build_Pieces(4);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("release one Id twice in one drain", n"Step_ReleaseTwice");
        Add_Step_WaitUntil("both releases were answered", n"Check_Answered2", 0, 1.0f);
        Add_Step("the first is accepted, the duplicate rejected with a reason", n"Step_AssertFirstDrain");
        Add_Step("release the same Id again, and a new one", n"Step_ReleaseAgainAndNew");
        Add_Step_WaitUntil("both releases were answered", n"Check_Answered4", 0, 1.0f);
        Add_Step_WaitFrames("the bodies settle into the books", 2);
        Add_Step("the repeat is rejected, the new one accepted: two bodies", n"Step_AssertSecondDrain");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ReleaseTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstId = AddPieceAt(k_FirstLocal);
        Release_Piece(_FirstId, k_FirstLocal);
    }

    UFUNCTION()
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Check_Answered4(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 4);
    }

    UFUNCTION()
    private void Step_AssertFirstDrain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 2, "two answers");
        if (_Admissions.Num() < 2)
        { return; }

        Assert_True(_AdmissionIds[0].Get_IsSame(_FirstId) && _AdmissionIds[1].Get_IsSame(_FirstId), "both answers name the Id");
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, "the first release is accepted");
        Assert_True(_Admissions[1] == EMars_CookingFeed_Admission::Rejected, "the duplicate is rejected");
        Assert_True(_AdmissionReasons[0].Len() == 0, f"an acceptance carries no reason (got {_AdmissionReasons[0]})");
        Assert_True(_AdmissionReasons[1].Len() > 0, f"the rejection names its reason (got {_AdmissionReasons[1]})");
        Log(f"[Mars_AutoTest_Searing_AdmissionIsRejectedForADuplicateId] duplicate rejected: {_AdmissionReasons[1]}");

        Assert_Equals_Int(_Added.Num(), 1, "one OnPieceAdded");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "one piece on the books");
    }

    UFUNCTION()
    private void Step_ReleaseAgainAndNew(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Piece(_FirstId, k_ThirdLocal);
        AddPieceAt(k_ThirdLocal);
    }

    UFUNCTION()
    private void Step_AssertSecondDrain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 4, "four answers in all");
        if (_Admissions.Num() < 4)
        { return; }

        Assert_True(_Admissions[2] == EMars_CookingFeed_Admission::Rejected, "the repeated Id is rejected in a later drain");
        Assert_True(_AdmissionReasons[2].Len() > 0, "that rejection names its reason");
        Assert_True(_Admissions[3] == EMars_CookingFeed_Admission::Accepted, "a new Id is accepted");
        Assert_False(_AdmissionIds[3].Get_IsSame(_FirstId), "the accepted one is the new Id");

        Assert_Equals_Int(_Added.Num(), 2, "two OnPieceAdded");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 2, "two pieces on the books");
        Assert_True(_Added[0] != _Added[1], "two entities");
        Assert_True(_Searing.Get_PieceBody(_AddedIds[0]) != _Searing.Get_PieceBody(_AddedIds[1]), "two bodies");
        Assert_Equals_Int(_Searing.Get_Summary().Admitted, 2, "the summary admits two");
    }
}

class AMars_AutoTest_Searing_AdmissionIsRejectedForADuplicateId_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 8.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AdmissionIsRejectedForADuplicateId;
}
