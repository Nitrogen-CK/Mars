// Six fresh presses, each once the hand is back at rest, admit six pieces from six distinct slots of the same attempt; a
// seventh press finds the platter empty and is refused Empty (no refill, no seventh piece).
class UMars_AutoTest_CookingFeed_AFreshPressAfterReturnStartsTheNextAndSixAdmitSix : UMars_AutoTestRig_CookingFeed
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());

        for (int32 Round = 0; Round < k_Stock; ++Round)
        {
            Add_Step(f"press add food (piece {Round + 1})", n"Step_Begin");
            Add_Step_WaitUntil(f"piece {Round + 1} awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
            Add_Step(f"accept piece {Round + 1}", n"Step_AcceptPending");
            Add_Step_WaitUntil(f"the hand is back at rest after piece {Round + 1}", n"Check_Idle", 0, 2.0f);
            Add_Step(f"the ledger after piece {Round + 1}", n"Step_AssertLedger");
        }

        Add_Step("press a seventh time", n"Step_Begin");
        Add_Step_WaitFrames("the press drains", 2);
        Add_Step("six admitted from six slots of one attempt; the seventh refused Empty", n"Step_AssertSixAdmitted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertLedger(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Admitted = _Feed.Get_Admitted();
        Assert_Ledger(k_Stock - Admitted, Admitted, f"after {Admitted} admitted");
        Assert_Equals_Int(_Refusals.Num(), 0, "no press was refused");
    }

    UFUNCTION()
    private void Step_AssertSixAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(0, k_Stock, "after the seventh press");
        Assert_Equals_Int(_Refusals.Num(), 1, "the seventh press was refused");
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::Empty, "it was refused Empty");
        Assert_Equals_Int(_Releases.Num(), k_Stock, "six releases");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), k_Stock, "six admissions");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the hand stays at rest");

        auto Slots = TArray<int32>();
        for (const auto& Release : _Releases)
        {
            Assert_Equals_Int(Release.PieceId.Generation, 1, f"slot {Release.PieceId.StockIndex} belongs to the first attempt");
            Assert_False(Slots.Contains(Release.PieceId.StockIndex), f"slot {Release.PieceId.StockIndex} was used once");
            Slots.AddUnique(Release.PieceId.StockIndex);
            Assert_True(_Feed.Get_IsSlotTaken(Release.PieceId.StockIndex), f"slot {Release.PieceId.StockIndex} stays spent");
        }

        Assert_Equals_Int(Slots.Num(), k_Stock, "six distinct slots");
    }
}
