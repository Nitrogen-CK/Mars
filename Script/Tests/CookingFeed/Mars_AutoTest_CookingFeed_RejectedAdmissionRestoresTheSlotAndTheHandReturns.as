// A rejected release spends nothing: the piece the release carried off the platter drops back onto the pile and freezes on
// top again, the place it was reserved from; the stock is back to six, and the hand still runs its Return to rest. The
// rejection waits for the rest of the pile to re-settle after the piece left it (the pile's order is the order its pieces
// froze in), under an admission budget long enough for that wait.
class UMars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns : UMars_AutoTestRig_CookingFeed
{
    // Past the pile's own settle bound (its Settle.MaxSeconds), so the feed does not answer for the test while it waits.
    private const float32 k_LongAdmissionBudgetSeconds = 10.0f;

    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Timing.AdmissionBudgetSeconds = k_LongAdmissionBudgetSeconds;
        BuildFeed(InHandle, Spec);
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step_WaitUntil("the released piece is off the platter", n"Check_PieceOff", 0, 0);
        Add_Step_WaitUntil("the rest of the pile has re-settled", n"Check_PileSettled", k_SlowPolls, 0);
        Add_Step("one piece is reserved and off the platter; reject the release", n"Step_AssertReservedAndReject");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 0);
        Add_Step_WaitUntil("the piece is back on the platter", n"Check_PieceBack", k_SlowPolls, 0);
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
        Assert_True(_Feed.TryGet_ActivePiece().IsSet(), "a piece is reserved");

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
        // The press reserved the top of the full pile.
        const auto Top = k_Stock - 1;
        Assert_True(Place == Top, f"on top again, the place it was reserved from ({Place} vs {Top})");
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Rejected, "it settled Rejected");

        const auto ReturnIndex = _Phases.FindIndex(EMars_CookingFeed_Phase::Return);
        Assert_True(ReturnIndex >= 0, "the hand ran its Return");
        Assert_True(_Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle, "and ended at rest");
        Assert_True(ReturnIndex >= 0 && ReturnIndex == _Phases.Num() - 2, "Return led straight to Idle");
    }
}
