// A rejected release spends nothing: the piece the release carried off the platter drops back onto the pile and freezes on
// top again, the place it was reserved from; the stock is back to six, and the hand still runs its Return to rest.
class UMars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns : UMars_AutoTestRig_CookingFeed
{
    private int32 _Slot = -1;
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
        Add_Step_WaitUntil("the released piece is off the platter", n"Check_PieceOff", 0, 1.0f);
        Add_Step("one piece is reserved and off the platter; reject the release", n"Step_AssertReservedAndReject");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 2.0f);
        Add_Step_WaitUntil("the piece is back on the platter", n"Check_PieceBack", 0, 2.0f);
        Add_Step("the slot is restored and nothing was spent", n"Step_AssertRestored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PieceOff(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Releases.Num() > 0 && ck::Is_NOT_Valid(_Releases.Last().Piece.TryGet_Platter()));
    }

    UFUNCTION()
    private void Step_AssertReservedAndReject(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock - 1, 0, "awaiting admission");
        const auto Active = _Feed.TryGet_ActivePiece();
        Assert_True(Active.IsSet(), "a piece is reserved");
        if (Active.IsSet())
        { _Slot = Active.GetValue().StockIndex; }

        _Piece = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(ck::IsValid(_Piece) && _Piece == _Releases.Last().Piece, "the release carries the reserved piece");
        Assert_Equals_Int(_Platter.Get_Occupancy(), k_Stock - 1, "the piece is off the platter");

        Step_RejectPending(InHandle, InPayload);
    }

    UFUNCTION()
    private void Check_PieceBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == k_Stock);
    }

    UFUNCTION()
    private void Step_AssertRestored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock, 0, "after the rejection");
        Assert_True(_Piece.TryGet_Platter() == _Platter, "the piece is back on the platter");
        const auto Place = _Platter.Get_Held().FindIndex(_Piece);
        Assert_True(Place == _Slot, f"on top again, the place it was reserved from ({Place} vs {_Slot})");
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Rejected, "it settled Rejected");

        const auto ReturnIndex = _Phases.FindIndex(EMars_CookingFeed_Phase::Return);
        Assert_True(ReturnIndex >= 0, "the hand ran its Return");
        Assert_True(_Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle, "and ended at rest");
        Assert_True(ReturnIndex >= 0 && ReturnIndex == _Phases.Num() - 2, "Return led straight to Idle");
    }
}
