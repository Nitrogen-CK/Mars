// A refused admission says why, as an enum and in the kernel's words. A pan that takes one piece (Supply.MaxPieces 1)
// admits the first release. In one later drain a second piece under a new id is refused Full, and a third piece released
// under the first piece's id is refused Unavailable: OnAdmissionRefused names each id with its refusal, in inbox order,
// and the station's OnAdmission carries the kernel's words for each. Only the first piece is on the pan.
class UMars_AutoTest_Searing_AdmissionRefusedCarriesAReason : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_SecondLocal = FVector(-15.0, 0.0, 8.0);
    private const FVector k_ThirdLocal = FVector(15.0, 0.0, 8.0);

    private FMars_CookingFeed_PieceId _FirstId;
    private FMars_CookingFeed_PieceId _SecondId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Supply.MaxPieces = 1;
        BuildStation(InHandle, Spec);
        Build_Pieces(3);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", k_SlowPolls, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release the first piece", n"Step_AddFirst");
        Add_Step_WaitUntil("the first piece was admitted", n"Check_Added1", 0, 0);
        Add_Step("release a second piece and a third under the first's id", n"Step_AddTwoMore");
        Add_Step_WaitUntil("both were answered", n"Check_ThreeAnswers", 0, 0);
        Add_Step("refused Full, then Unavailable, each with the kernel's words", n"Step_AssertRefusals");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstId = AddPiece();
    }

    UFUNCTION()
    private void Step_AddTwoMore(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SecondId = AddPieceAt(k_SecondLocal);
        Release_Piece(_FirstId, k_ThirdLocal);
    }

    UFUNCTION()
    private void Check_ThreeAnswers(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 3);
    }

    UFUNCTION()
    private void Step_AssertRefusals(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 3, "three answers");
        Assert_Equals_Int(Get_AdmissionCount(EMars_CookingFeed_Admission::Accepted), 1, "only the first was admitted");

        Assert_Equals_Int(_Refusals.Num(), 2, "two OnAdmissionRefused");
        if (_Refusals.Num() == 2)
        {
            Assert_True(_RefusedIds[0].Get_IsSame(_SecondId) && _Refusals[0] == EMars_Searing_AdmissionRefusal::Full,
                f"the second piece is refused Full (got {_Refusals[0] :n})");
            Assert_True(_RefusedIds[1].Get_IsSame(_FirstId) && _Refusals[1] == EMars_Searing_AdmissionRefusal::Unavailable,
                f"the piece under the first's id is refused Unavailable (got {_Refusals[1] :n})");
        }

        if (_AdmissionReasons.Num() == 3)
        {
            Assert_True(_AdmissionReasons[0].Len() == 0, f"the admission carries no reason (got '{_AdmissionReasons[0]}')");
            Assert_True(_AdmissionReasons[1] == "the pan already holds Supply.MaxPieces [1] pieces",
                f"the Full refusal's words (got '{_AdmissionReasons[1]}')");
            Assert_True(_AdmissionReasons[2] == f"piece {utils_cooking_feed::Get_PieceName(_FirstId)} is already on the pan",
                f"the Unavailable refusal's words (got '{_AdmissionReasons[2]}')");
        }

        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "one piece on the pan");
        Assert_True(_Searing.Get_HasPiece(_FirstId) && _Searing.Get_PieceHandle(_FirstId) == _Pieces[0], "the first piece, under its id");
    }
}

class AMars_AutoTest_Searing_AdmissionRefusedCarriesAReason_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AdmissionRefusedCarriesAReason;
}
