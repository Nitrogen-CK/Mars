// A readopt the bowl has no slot for is a defect made loud, and the piece is left free. A one-slot bowl admits a piece; a
// second whole piece (on no ledger, attached nowhere) is then sent back to the bowl as a refused take-out would send it,
// in the same frame as a dip. The drain ran (the bowl went Dipped), the kernel ensured that it has no free slot to
// readopt the piece, and the piece is not in the bowl: no holder, no OnPieceAdded for it, the bowl still holding only the
// first piece.
class UMars_AutoTest_Batter_AReadoptWithNoFreeSlotEnsures : UMars_AutoTestRig_Batter
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Bowl.Capacity = 1;
        BuildStation(InHandle, Spec);
        Build_FoodPieces(2, mars::Food_TestBatterableBox_Mars);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release the first piece", n"Step_AdmitFirst");
        Add_Step_WaitUntil("it fills the one slot", n"Check_FirstAdmitted", 0, 0);
        Add_Step("readopt the second piece, and dip in the same frame", n"Step_ReadoptAndDip");
        Add_Step_WaitUntil("the drain ran: the bowl is Dipped", n"Check_Dipped", 0, 0);
        Add_Step("the second piece is not in the bowl and nothing holds it", n"Step_AssertNotReadopted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AdmitFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit(0);
    }

    UFUNCTION()
    private void Check_FirstAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_AddedIds.Num() >= 1 && _Batter.Get_PieceCount() == 1);
    }

    UFUNCTION()
    private void Step_ReadoptAndDip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Batter.Request_Readopt(FMars_Request_Batter_Readopt(Make_Id(1), _Pieces[1]));
        Dip();
    }

    UFUNCTION()
    private void Check_Dipped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bowls.Num() > 0 && _Bowls.Last() == EMars_Batter_Bowl::Dipped);
    }

    UFUNCTION()
    private void Step_AssertNotReadopted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Second = _Pieces[1];
        Assert_False(_Batter.Get_HasPiece(Make_Id(1)), "the second piece is not in the bowl");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 1, "the bowl holds only the first piece");
        Assert_True(_Batter.Get_HasPiece(Make_Id(0)), "the first piece keeps its slot");
        Assert_False(ck::IsValid(Second.TryGet_Holder()), "nothing holds the second piece");
        Assert_Equals_Int(_AddedIds.Num(), 1, "OnPieceAdded fired for the first piece only");
    }
}

// Hand-authored so the ensure the test provokes on purpose is required, not a failure: the readopt with no free slot.
class AMars_AutoTest_Batter_AReadoptWithNoFreeSlotEnsures_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Batter_AReadoptWithNoFreeSlotEnsures;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Errors;
        Errors.Add("has no free slot to readopt piece g1#1");
        return Errors;
    }
}
