// Six fresh presses, each once the hand is back at rest and the pile has re-settled, admit the platter's six pieces from six
// distinct places in the pile (each the top in turn) of the same attempt and empty the platter; a seventh press finds it
// empty and is refused Empty (no refill, no seventh piece).
class UMars_AutoTest_CookingFeed_AFreshPressAfterReturnStartsTheNextAndSixAdmitSix : UMars_AutoTestRig_CookingFeed
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        Add_Steps_SourceTheFeed();

        for (int32 Round = 0; Round < k_Stock; ++Round)
        {
            Add_Step_WaitUntil(f"the pile has settled (piece {Round + 1})", n"Check_PileSettled", 0, 2.0f);
            Add_Step(f"press add food (piece {Round + 1})", n"Step_Begin");
            Add_Step_WaitUntil(f"piece {Round + 1} awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
            Add_Step(f"accept piece {Round + 1}", n"Step_AcceptPending");
            Add_Step_WaitUntil(f"the hand is back at rest after piece {Round + 1}", n"Check_Idle", 0, 2.0f);
            Add_Step(f"the ledger after piece {Round + 1}", n"Step_AssertLedger");
        }

        Add_Step("press a seventh time", n"Step_Begin");
        Add_Step_WaitFrames("the press drains", 2);
        Add_Step("six admitted from six places of one attempt; the seventh refused Empty", n"Step_AssertSixAdmitted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertLedger(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Admitted = _Feed.Get_Admitted();
        Assert_Ledger(k_Stock - Admitted, Admitted, f"after {Admitted} admitted");
        Assert_Equals_Int(_Platter.Get_Occupancy(), k_Stock - Admitted, f"the platter holds the {k_Stock - Admitted} not yet admitted");
        Assert_Equals_Int(_Refusals.Num(), 0, "no press was refused");
    }

    UFUNCTION()
    private void Step_AssertSixAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(0, k_Stock, "after the seventh press");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "the platter is empty");
        Assert_Equals_Int(_Refusals.Num(), 1, "the seventh press was refused");
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::Empty, "it was refused Empty");
        Assert_Equals_Int(_Releases.Num(), k_Stock, "six releases");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), k_Stock, "six admissions");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the hand stays at rest");

        auto Slots = TArray<int32>();
        auto Pieces = TArray<FCk_Handle_FoodPiece>();
        for (const auto& Release : _Releases)
        {
            const auto Slot = Release.PieceId.StockIndex;
            Assert_Equals_Int(Release.PieceId.Generation, _Feed.Get_Generation(), f"slot {Slot} belongs to the one attempt");
            Assert_True(Slot >= 0 && Slot < k_Stock, f"slot {Slot} is a place in the six-piece pile");
            Assert_False(Slots.Contains(Slot), f"slot {Slot} was used once");
            Assert_True(_Stock.Contains(Release.Piece) && Pieces.Contains(Release.Piece) == false, f"slot {Slot} released a stock piece once");
            Assert_False(ck::IsValid(Release.Piece.TryGet_Platter()), f"slot {Slot}'s piece is off the platter");
            Slots.AddUnique(Slot);
            Pieces.AddUnique(Release.Piece);
        }

        Assert_Equals_Int(Slots.Num(), k_Stock, "six distinct places");
    }
}
