// Only an answer for exactly the awaited piece counts: a transfer the reservation does not name and a newer generation are
// ignored while awaiting, the right answer spends once, the same answer again spends nothing. After the source changes
// mid-admission (unsourced and sourced again in one drain: the feed puts the released piece back on the platter it came
// from), a fresh press awaits its own piece, and an Accepted answer for the old piece arriving then spends nothing and
// settles nothing (the id filter, not the phase, refuses it); the fresh piece's own answer still admits it.
class UMars_AutoTest_CookingFeed_StaleAndDuplicateAcknowledgementsSpendNothing : UMars_AutoTestRig_CookingFeed
{
    private FMars_CookingFeed_PieceId _Awaited;
    private FMars_CookingFeed_PieceId _Stale;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("answer for a wrong transfer and for a newer generation", n"Step_AnswerWrongPieces");
        Add_Step_WaitFrames("the answers drain", 3);
        Add_Step("still awaiting; nothing spent", n"Step_AssertStillAwaiting");
        Add_Step("accept the awaited piece", n"Step_AcceptPending");
        Add_Step_WaitUntil("the piece is admitted", n"Check_OneAdmitted", 0, 0);
        Add_Step("accept it again", n"Step_AcceptPending");
        Add_Step_WaitFrames("the duplicate drains", 3);
        Add_Step("admitted exactly once", n"Step_AssertAdmittedOnce");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 0);
        Add_Step_WaitUntil("the pile has re-settled", n"Check_PileSettled", k_SlowPolls, 0);
        Add_Step("press add food again", n"Step_Begin");
        Add_Step_WaitUntil("the second piece awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("change the source mid-admission", n"Step_ResourceMidAdmission");
        Add_Step_WaitUntil("the source change applied", n"Check_ResourceApplied", 0, 0);
        Add_Step_WaitUntil("the released piece is back on the platter", n"Check_StaleBack", k_SlowPolls, 0);
        Add_Step("the source change settled the old reservation; press add food again", n"Step_AssertResourcedAndBegin");
        Add_Step_WaitUntil("the fresh piece awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("accept the old piece while the fresh one is awaited", n"Step_AcceptStale");
        Add_Step_WaitFrames("the stale answer drains", 3);
        Add_Step("the fresh attempt is untouched; accept the fresh piece", n"Step_AssertFreshAttempt");
        Add_Step_WaitUntil("the fresh piece is admitted", n"Check_OneAdmitted", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AnswerWrongPieces(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = _Releases.Last().PieceId;
        Resolve(FMars_CookingFeed_PieceId(_Awaited.Generation, _Awaited.TransferIndex + 1), EMars_CookingFeed_Admission::Accepted);
        Resolve(FMars_CookingFeed_PieceId(_Awaited.Generation + 1, _Awaited.TransferIndex), EMars_CookingFeed_Admission::Accepted);
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
    private void Step_ResourceMidAdmission(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Stale = _Releases.Last().PieceId;
        SetSource(FCk_Handle_Platter());
        SetSource(_Platter);
    }

    UFUNCTION()
    private void Check_ResourceApplied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Generation() == _Stale.Generation + 2 && _Feed.Get_Source() == _Platter
            && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void Check_StaleBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == k_Stock - 1 && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertResourcedAndBegin(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Settles.Num(), 2, "the source change settled the reservation");
        Assert_True(_Settles.Num() == 2 && _Settles[1] == EMars_CookingFeed_Settle::Cancelled, "the reservation settled Cancelled");
        Assert_True(_SettledPieces.Num() == 2 && _SettledPieces[1].Get_IsSame(_Stale), "under its old id");
        Begin();
    }

    UFUNCTION()
    private void Step_AcceptStale(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Resolve(_Stale, EMars_CookingFeed_Admission::Accepted);
    }

    UFUNCTION()
    private void Step_AssertFreshAttempt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Releases.Last().PieceId.Get_IsSame(_Stale), "the fresh attempt released a piece of its own");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::AwaitAdmission, f"the fresh attempt still awaits admission (got {_Feed.Get_Phase() :n})");
        Assert_Ledger(k_Stock - 2, 0, "after the stale answer (the first piece stays spent, the fresh one reserved)");
        Assert_Equals_Int(_Settles.Num(), 2, "the stale answer settled nothing");

        Resolve(_Releases.Last().PieceId, EMars_CookingFeed_Admission::Accepted);
    }
}
