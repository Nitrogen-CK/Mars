// Unsourcing the feed while the hand reaches cancels the transfer the way a Cancel does: it settles Cancelled once, the
// hand is at rest, nothing is available and a press is refused Empty; the reserved piece never left the platter. Sourcing
// the platter again moves the generation on: a press works, and a late Accepted answer under the cancelled reservation's
// id spends nothing while the new piece awaits its own.
class UMars_AutoTest_CookingFeed_ChangingTheSourceCancelsAndUnsourcedIsEmpty : UMars_AutoTestRig_CookingFeed
{
    private FMars_CookingFeed_PieceId _Cancelled;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // A Reach long enough that the unsourcing lands inside it.
        auto Spec = Make_TestSpec();
        Spec.Timing = FMars_CookingFeed_TimingSpec(0.5f, 0.05f, 0.1f, 0.1f);
        BuildFeed(InHandle, Spec);
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand reaches", n"Check_Reaching", 0, 1.0f);
        Add_Step("unsource the feed", n"Step_Unsource");
        Add_Step_WaitUntil("the transfer settles", n"Check_OneSettle", 0, 0.5f);
        Add_Step_WaitUntil("the hand is at rest", n"Check_Idle", 0, 1.0f);
        Add_Step("cancelled once; nothing available", n"Step_AssertCancelledAndEmpty");
        Add_Step("press add food unsourced", n"Step_Begin");
        Add_Step_WaitFrames("the press drains", 2);
        Add_Step("the press is refused Empty", n"Step_AssertRefusedEmpty");
        Add_Step("source the platter again", n"Step_SetSource");
        Add_Step_WaitUntil("the feed draws from the platter again", n"Check_Sourced", 0, 1.0f);
        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the new piece awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
        Add_Step("a new generation; answer Accepted under the cancelled id", n"Step_AnswerCancelledId");
        Add_Step_WaitFrames("the late answer drains", 3);
        Add_Step("the late answer spent nothing", n"Step_AssertLateAnswerIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Unsource(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Feed.TryGet_ActivePiece().IsSet(), "a piece is reserved while the hand reaches");
        if (_Feed.TryGet_ActivePiece().IsSet())
        { _Cancelled = _Feed.TryGet_ActivePiece().GetValue(); }

        SetSource(FCk_Handle_Platter());
    }

    UFUNCTION()
    private void Check_OneSettle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Settles.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertCancelledAndEmpty(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Cancelled, "it settled Cancelled");
        Assert_True(_SettledPieces.Num() == 1 && _SettledPieces[0].Get_IsSame(_Cancelled), "under the reservation's id");
        Assert_Equals_Int(Get_PhaseCount(EMars_CookingFeed_Phase::Grasp), 0, "the hand never grasped");
        Assert_Equals_Int(_Releases.Num(), 0, "nothing was released");
        Assert_False(_Feed.Get_IsSourced(), "the feed is unsourced");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");
        Assert_Ledger(0, 0, "unsourced");
        Assert_Equals_Int(_Platter.Get_HeldCount(), k_Stock, "the reserved piece never left the platter");
    }

    UFUNCTION()
    private void Step_AssertRefusedEmpty(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Refusals.Num(), 1, "the press was refused");
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::Empty, "it was refused Empty");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the hand stays at rest");
    }

    UFUNCTION()
    private void Step_AnswerCancelledId(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 1, "one release");
        if (_Releases.Num() != 1)
        { return; }

        const auto Awaited = _Releases[0].PieceId;
        Assert_True(Awaited.Generation > _Cancelled.Generation, f"the generation moved on ({_Cancelled.Generation} -> {Awaited.Generation})");
        Assert_False(Awaited.Get_IsSame(_Cancelled), "the new piece is not the cancelled one's id");
        Resolve(_Cancelled, EMars_CookingFeed_Admission::Accepted);
    }

    UFUNCTION()
    private void Step_AssertLateAnswerIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::AwaitAdmission, f"still awaiting the new piece (got {_Feed.Get_Phase() :n})");
        Assert_Equals_Int(_Settles.Num(), 1, "the late answer settled nothing");
        Assert_Ledger(k_Stock - 1, 0, "after the late answer");
    }
}
