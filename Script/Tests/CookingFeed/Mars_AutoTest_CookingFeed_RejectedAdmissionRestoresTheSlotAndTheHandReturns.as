// A rejected release spends nothing: the reserved slot is free again, the stock is back to six, and the hand still runs its
// Return to rest.
class UMars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns : UMars_AutoTestRig_CookingFeed
{
    private int32 _Slot = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
        Add_Step("one slot is reserved; reject the release", n"Step_AssertReservedAndReject");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 2.0f);
        Add_Step("the slot is restored and nothing was spent", n"Step_AssertRestored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertReservedAndReject(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock - 1, 0, "awaiting admission");
        const auto Active = _Feed.TryGet_ActivePiece();
        Assert_True(Active.IsSet(), "a piece is reserved");
        if (Active.IsSet())
        {
            _Slot = Active.GetValue().StockIndex;
            Assert_True(_Feed.Get_IsSlotTaken(_Slot), "its slot is taken");
        }

        Step_RejectPending(InHandle, InPayload);
    }

    UFUNCTION()
    private void Step_AssertRestored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock, 0, "after the rejection");
        Assert_False(_Feed.Get_IsSlotTaken(_Slot), "the slot is free again");
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Rejected, "it settled Rejected");

        const auto ReturnIndex = _Phases.FindIndex(EMars_CookingFeed_Phase::Return);
        Assert_True(ReturnIndex >= 0, "the hand ran its Return");
        Assert_True(_Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle, "and ended at rest");
        Assert_True(ReturnIndex >= 0 && ReturnIndex == _Phases.Num() - 2, "Return led straight to Idle");
    }
}
