// A battered whole piece is admitted and fries golden, its dip flowing through untouched. A whole piece of the rig's
// batterable test food with a battered ledger is released over the oil and admitted: the kernel's look of it is battered.
// It floats, and its down face reaches Golden (GoldenSeconds 1 s here); its ledger stays battered (exactly 1), and the
// kernel's look of it is still battered with the face's heat in its batter.
class UMars_AutoTest_Fry_ABatteredWholePieceFriesGolden : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 20.0f;

    private const float32 k_GoldenSeconds = 1.0f;

    private FMars_CookingFeed_PieceId _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Heat.GoldenSeconds = k_GoldenSeconds;
        BuildStation(InHandle, Spec);
        Build_FoodPieces(1, mars::Food_TestBatterableBox_Mars);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 0);
        Add_Step("release the battered piece over the oil", n"Step_Release");
        Add_Step_WaitUntil("the fryer admitted it", n"Check_Added1", 0, 0);
        Add_Step("the kernel's look of it is battered", n"Step_AssertBattered");
        Add_Step_WaitUntil("a face went golden", n"Check_Golden", k_SlowPolls, 0);
        Add_Step("battered and golden", n"Step_AssertGolden");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Pieces[0].Get_IsWhole(), "the piece is whole");
        Assert_True(utils_batter::Get_IsBattered(_Pieces[0].Get_CookState()), "the piece arrives battered");
        _Piece = AddPiece(k_ReleaseLocal);
    }

    UFUNCTION()
    private void Step_AssertBattered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions.Num() == 1 && _Admissions[0] == EMars_CookingFeed_Admission::Accepted, "the fryer accepted it");
        Assert_Equals_Int(_Refusals.Num(), 0, "no refusal");
        Assert_Equals_Float(_Fry.Get_PieceCookState(_Piece).Battered, 1.0, 0.0, "the kernel's look of it is battered");
    }

    UFUNCTION()
    private void Check_Golden(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Stages.Contains(EMars_Fry_HeatStage::Golden));
    }

    UFUNCTION()
    private void Step_AssertGolden(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_HasPiece(_Piece), "the fryer still holds the piece");
        if (_Fry.Get_HasPiece(_Piece) == false)
        { return; }

        const auto CookState = _Fry.Get_PieceCookState(_Piece);
        Assert_Equals_Float(CookState.Battered, 1.0, 0.0, "the kernel's look of it is still battered");
        auto Hottest = 0.0f;
        for (const auto Heat : CookState.Batter)
        { Hottest = Math::Max(Hottest, Heat); }

        Assert_True(Hottest >= 1.0f, f"a face's heat reached golden in its batter ({Hottest :.3})");
        Assert_Equals_Float(_Pieces[0].Get_CookState().Battered, 1.0, 0.0, "its ledger is exactly battered");
    }
}
