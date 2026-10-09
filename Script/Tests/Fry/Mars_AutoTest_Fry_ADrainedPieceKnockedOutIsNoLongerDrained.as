// A piece released over the basket lands on its floor and drains (Drained after Receiver.DrainSeconds, OnPieceDrained once,
// the summary counts it). Teleported out over the oil it leaves the basket: its drain resets to NotDraining with no
// progress and the summary drains nothing. Put back in the basket it drains again from scratch (a second OnPieceDrained).
class UMars_AutoTest_Fry_ADrainedPieceKnockedOutIsNoLongerDrained : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_DrainSeconds = 0.5f;

    private FMars_CookingFeed_PieceId _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Receiver.DrainSeconds = k_DrainSeconds;
        BuildStation(InHandle, Spec);
        Build_Pieces(1);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("release a piece over the basket", n"Step_Release");
        Add_Step_WaitUntil("the piece drained", n"Check_FirstDrained", 0, 4.0f);
        Add_Step("drained once; knock it out over the oil", n"Step_AssertDrainedThenKnockOut");
        Add_Step_WaitUntil("the piece is in the oil", n"Check_InOil", 0, 3.0f);
        Add_Step("no longer drained; put it back in the basket", n"Step_AssertResetThenPutBack");
        Add_Step_WaitUntil("the piece drained again", n"Check_FirstDrained", 0, 4.0f);
        Add_Step("drained a second time from scratch", n"Step_AssertDrainedAgain");
        Run_Steps(InHandle);
    }

    private FVector Get_OverBasket() const
    {
        return k_BasketLocal + FVector(0.0, 0.0, Get_BoxHalfExtents().Z + 3.0);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Piece = AddPiece(Get_OverBasket());
    }

    UFUNCTION()
    private void Step_AssertDrainedThenKnockOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::DrainBasket, "the piece is in the basket");
        Assert_Equals_Int(Count_Ids(_DrainedIds, _Piece), 1, "OnPieceDrained fired once");
        Assert_Equals_Int(_Fry.Get_Summary().Drained, 1, "the summary drains one");

        Teleport(_Piece, FVector(-20.0, 0.0, float64(_Spec.Oil.SurfaceZ) + Get_BoxHalfExtents().Z + 1.0), FVector::ZeroVector);
    }

    UFUNCTION()
    private void Check_InOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::Oil);
    }

    UFUNCTION()
    private void Step_AssertResetThenPutBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_PieceDrain(_Piece) == EMars_Fry_Drain::NotDraining, f"out of the basket it is NotDraining (got {_Fry.Get_PieceDrain(_Piece) :n})");
        Assert_Equals_Float(_Fry.Get_PieceDrainProgress(_Piece), 0.0, 0.0001, "with no drain progress");
        Assert_Equals_Int(_Fry.Get_Summary().Drained, 0, "the summary drains none");
        Assert_Equals_Int(_Fry.Get_Summary().InBasket, 0, "and has none in the basket");

        Teleport(_Piece, Get_OverBasket(), FVector::ZeroVector);
    }

    UFUNCTION()
    private void Step_AssertDrainedAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Count_Ids(_DrainedIds, _Piece), 2, "OnPieceDrained fired a second time");
        Assert_Equals_Int(_Fry.Get_Summary().Drained, 1, "the summary drains one again");
    }
}
