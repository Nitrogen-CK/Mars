// The fryer fries only what the batter station coated: a piece whose ledger is not battered is refused. A whole piece of
// the rig's batterable test food, its ledger unbattered, is released over the oil: the station's OnAdmission answers
// Rejected naming the batter, OnAdmissionRefused says NotBattered, nothing is in play, nothing holds the piece and the
// fryer did not batter it (its ledger is still 0).
class UMars_AutoTest_Fry_AdmissionRefusesAnUnbatteredPiece : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        _Pieces.Add(Build_Piece(Get_BoxMesh(), FTransform(k_Origin + k_ParkLocal), Make_FoodSpec(k_PieceMassKg, mars::Food_TestBatterableBox_Mars)));

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 0);
        Add_Step("release the unbattered piece over the oil", n"Step_Release");
        Add_Step_WaitUntil("the fryer answered the release", n"Check_Answered", 0, 0);
        Add_Step_WaitFrames("any write would drain into the ledger", 2);
        Add_Step("refused NotBattered, the piece untouched", n"Step_AssertRefused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_batter::Get_IsBatterable(_Pieces[0]), "the piece is a whole piece of a batterable food");
        Assert_False(utils_batter::Get_IsBattered(_Pieces[0].Get_CookState()), "its ledger is not battered");
        AddPiece(k_ReleaseLocal);
    }

    UFUNCTION()
    private void Check_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Rejected, "the fryer rejected the piece");
        Assert_True(_AdmissionReasons[0].Contains("batter"), f"the reason names the batter (got {_AdmissionReasons[0]})");
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_Fry_AdmissionRefusal::NotBattered, "refused NotBattered");
        Assert_Equals_Int(_Added.Num(), 0, "no OnPieceAdded");
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 0, "nothing is in play");
        Assert_False(ck::IsValid(_Pieces[0].TryGet_Holder()), "nothing holds the piece");
        Assert_Equals_Float(_Pieces[0].Get_CookState().Battered, 0.0, 0.0, "the fryer did not batter it");
    }
}
