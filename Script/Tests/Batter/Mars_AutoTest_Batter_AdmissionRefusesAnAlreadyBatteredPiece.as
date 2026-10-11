// A piece is battered once: a whole piece of the batterable test food whose ledger is already battered is refused
// AlreadyBattered, the bowl stays empty and the ledger is untouched.
class UMars_AutoTest_Batter_AdmissionRefusesAnAlreadyBatteredPiece : UMars_AutoTestRig_Batter
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_BatteredPieces(1, mars::Food_TestBatterableBox_Mars);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release the battered piece", n"Step_Admit");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered1", 0, 0);
        Add_Step("refused AlreadyBattered", n"Step_AssertRefused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_batter::Get_IsBattered(_Pieces[0].Get_CookState()), "the piece arrives battered");
        Admit(0);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Rejected, "rejected");
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_Batter_AdmissionRefusal::AlreadyBattered,
            f"refused AlreadyBattered (reason: {_AdmissionReasons[0]})");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, "the bowl is empty");
        Assert_Equals_Float(_Pieces[0].Get_CookState().Battered, 1.0, 0.0, "the ledger is untouched");
    }
}
