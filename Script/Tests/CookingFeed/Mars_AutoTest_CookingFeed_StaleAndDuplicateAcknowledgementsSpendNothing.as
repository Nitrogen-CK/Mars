// Only an answer for exactly the awaited piece counts: a wrong slot and a newer generation are ignored while awaiting, the
// right answer spends once, the same answer again spends nothing. After a reset mid-admission, an Accepted answer for the
// old piece neither spends nor restores anything in the new attempt.
class UMars_AutoTest_CookingFeed_StaleAndDuplicateAcknowledgementsSpendNothing : UMars_AutoTestRig_CookingFeed
{
    default _TimeoutSeconds = 8.0f;

    private FMars_CookingFeed_PieceId _Awaited;
    private FMars_CookingFeed_PieceId _Stale;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
        Add_Step("answer for a wrong slot and for a newer generation", n"Step_AnswerWrongPieces");
        Add_Step_WaitFrames("the answers drain", 3);
        Add_Step("still awaiting; nothing spent", n"Step_AssertStillAwaiting");
        Add_Step("accept the awaited piece", n"Step_AcceptPending");
        Add_Step_WaitUntil("the piece is admitted", n"Check_OneAdmitted", 0, 1.0f);
        Add_Step("accept it again", n"Step_AcceptPending");
        Add_Step_WaitFrames("the duplicate drains", 3);
        Add_Step("admitted exactly once", n"Step_AssertAdmittedOnce");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 2.0f);
        Add_Step("press add food again", n"Step_Begin");
        Add_Step_WaitUntil("the second piece awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
        Add_Step("reset mid-admission", n"Step_ResetMidAdmission");
        Add_Step_WaitUntil("the reset applied", n"Check_ResetApplied", 0, 1.0f);
        Add_Step("accept the old piece", n"Step_AcceptStale");
        Add_Step_WaitFrames("the stale answer drains", 3);
        Add_Step("the new attempt is untouched", n"Step_AssertFreshAttempt");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AnswerWrongPieces(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = _Releases.Last().PieceId;
        Resolve(FMars_CookingFeed_PieceId(_Awaited.Generation, _Awaited.StockIndex + 1), EMars_CookingFeed_Admission::Accepted);
        Resolve(FMars_CookingFeed_PieceId(_Awaited.Generation + 1, _Awaited.StockIndex), EMars_CookingFeed_Admission::Accepted);
    }

    UFUNCTION()
    private void Step_AssertStillAwaiting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::AwaitAdmission, f"still awaiting admission (got {_Feed.Get_Phase() :n})");
        Assert_Ledger(k_Stock - 1, 0, "after the wrong answers");
        Assert_Equals_Int(_Settles.Num(), 0, "nothing settled");
    }

    UFUNCTION()
    private void Check_OneAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Admitted() == 1);
    }

    UFUNCTION()
    private void Step_AssertAdmittedOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock - 1, 1, "after the duplicate");
        Assert_Equals_Int(_Settles.Num(), 1, "one settle");
        Assert_True(_SettledPieces.Num() == 1 && _SettledPieces[0].Get_IsSame(_Awaited), "it is the awaited piece");
    }

    UFUNCTION()
    private void Step_ResetMidAdmission(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Stale = _Releases.Last().PieceId;
        Reset();
    }

    UFUNCTION()
    private void Check_ResetApplied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Generation() == _Stale.Generation + 1 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void Step_AcceptStale(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Resolve(_Stale, EMars_CookingFeed_Admission::Accepted);
    }

    UFUNCTION()
    private void Step_AssertFreshAttempt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock, 0, "after the stale answer");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the hand stays at rest");
        Assert_Equals_Int(_Settles.Num(), 2, "the reset settled the reservation; the stale answer settled nothing");
        Assert_True(_Settles.Num() == 2 && _Settles[1] == EMars_CookingFeed_Settle::Cancelled, "the reservation settled Cancelled");
        Assert_True(_SettledPieces.Num() == 2 && _SettledPieces[1].Get_IsSame(_Stale), "under its old id");

        for (int32 Slot = 0; Slot < k_Stock; ++Slot)
        { Assert_False(_Feed.Get_IsSlotTaken(Slot), f"slot {Slot} is free in the new attempt"); }
    }
}
