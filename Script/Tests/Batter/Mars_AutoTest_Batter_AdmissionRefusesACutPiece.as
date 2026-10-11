// The bowl takes full ingredients only: a cut piece is refused NotWhole. A whole piece of the rig's batterable test food is
// cut in half and the positive half (a piece of the same food, no longer whole) is released over the bowl: the station's
// OnAdmission answers Rejected, OnAdmissionRefused says NotWhole, the bowl is empty and nothing holds the half.
class UMars_AutoTest_Batter_AdmissionRefusesACutPiece : UMars_AutoTestRig_Batter
{
    private FCk_Handle_FoodPiece _Half;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_FoodPieces(1, mars::Food_TestBatterableBox_Mars);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("cut the whole piece in half", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved", n"Check_CutResolved", 0, 0);
        Add_Step("release the positive half", n"Step_ReleaseHalf");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered1", 0, 0);
        Add_Step("refused NotWhole", n"Step_AssertRefused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Whole = _Pieces[0];
        Cut(Whole, Get_BoundsCenter(Whole), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_CutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() >= 1);
    }

    // A failed cut still releases (nothing), so the answer arrives and the assertions report it.
    UFUNCTION()
    private void Step_ReleaseHalf(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = Get_FirstCut(EMars_FoodPiece_CutOutcome::Cut);
        Assert_True(ck::IsValid(Result.Positive), "the whole piece was cut");
        if (ck::Is_NOT_Valid(Result.Positive))
        {
            Admit_Piece(0, FCk_Handle_FoodPiece());
            return;
        }

        _Half = Result.Positive;
        Assert_False(_Half.Get_IsWhole(), "the half is not whole");
        Assert_False(utils_batter::Get_IsBatterable(_Half), "the half is not batterable");
        Admit_Piece(0, _Half);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Rejected, "the half is rejected");
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_Batter_AdmissionRefusal::NotWhole,
            f"refused NotWhole ({_Refusals.Num()} refusal(s), reason: {_AdmissionReasons[0]})");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, "the bowl is empty");
        Assert_Equals_Int(_AddedIds.Num(), 0, "no OnPieceAdded");
        if (ck::IsValid(_Half))
        { Assert_False(ck::IsValid(_Half.TryGet_Holder()), "nothing holds the half"); }
    }
}
