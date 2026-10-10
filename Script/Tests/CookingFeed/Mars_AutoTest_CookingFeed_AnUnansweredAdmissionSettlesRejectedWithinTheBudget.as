// The admission wait is bounded. Nobody answers the release: once Timing.AdmissionBudgetSeconds (the production default)
// have passed in AwaitAdmission, the feed settles the transfer Rejected under its id (no earlier than the budget, within
// half a second after it), puts the released piece back on the platter it came from, where it lands again, and the hand
// runs its Return to rest. Nothing is admitted and the stock is whole.
class UMars_AutoTest_CookingFeed_AnUnansweredAdmissionSettlesRejectedWithinTheBudget : UMars_AutoTestRig_CookingFeed
{
    // The settle comes in the first frame past the budget: half a second covers any frame.
    private const float32 k_SettleSlackSeconds = 0.5f;
    // A frame's worth below the budget: the budget is counted from the first tick after the release.
    private const float32 k_FrameSlackSeconds = 0.05f;

    private float32 _Budget = 0.0f;
    private FCk_Handle_FoodPiece _Piece;
    private FMars_CookingFeed_PieceId _Awaited;
    private float32 _AwaitStart = 0.0f;
    private float32 _SettledAt = -1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        _Budget = _Spec.Timing.AdmissionBudgetSeconds;
        _Feed.BindTo_OnTransferSettled(FMars_Delegate_CookingFeed_OnTransferSettled(this, n"OnSettledAt"));
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("nobody answers the release", n"Step_RecordAwait");
        Add_Step_WaitUntil(f"the transfer settles within AdmissionBudgetSeconds ({_Budget} s) + {k_SettleSlackSeconds} s",
            n"Check_Settled", 0, _Budget + k_SettleSlackSeconds);
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 0);
        Add_Step_WaitUntil("the piece landed back on the platter", n"Check_LandedBack", k_SlowPolls, 0);
        Add_Step("settled Rejected at the budget; the piece is back; nothing spent", n"Step_AssertExpired");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_RecordAwait(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Budget > 0.0f, f"the production feed bounds its admission wait (budget {_Budget} s)");
        _Piece = _Feed.TryGet_ActiveFoodPiece();
        if (_Feed.TryGet_ActivePiece().IsSet())
        { _Awaited = _Feed.TryGet_ActivePiece().GetValue(); }

        const auto AwaitIndex = _Phases.FindIndex(EMars_CookingFeed_Phase::AwaitAdmission);
        Assert_True(AwaitIndex >= 0, "the hand entered AwaitAdmission");
        if (AwaitIndex >= 0)
        { _AwaitStart = _PhaseTimes[AwaitIndex]; }
    }

    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Settles.Num() > 0);
    }

    UFUNCTION()
    private void Check_LandedBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_LandedCount(_Piece) == 2 && _Platter.Get_HeldCount() == k_Stock && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertExpired(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Rejected, "it settled Rejected");
        Assert_True(_SettledPieces.Num() == 1 && _SettledPieces[0].Get_IsSame(_Awaited), "under the awaited id");

        const auto Waited = _SettledAt - _AwaitStart;
        Assert_True(Waited >= _Budget - k_FrameSlackSeconds, f"not before the budget ({Waited} s waited, budget {_Budget} s)");
        Assert_True(Waited <= _Budget + k_SettleSlackSeconds, f"within half a second of it ({Waited} s waited)");

        Assert_True(_Piece.TryGet_Platter() == _Platter && _Platter.Get_Held().Contains(_Piece), "the piece is back in the pile");
        Assert_Ledger(k_Stock, 0, "after the expiry");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");

        const auto ReturnIndex = _Phases.FindIndex(EMars_CookingFeed_Phase::Return);
        Assert_True(ReturnIndex >= 0 && ReturnIndex == _Phases.Num() - 2, "the hand ran its Return");
        Assert_True(_Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle, "and ended at rest");
    }

    UFUNCTION()
    private void OnSettledAt(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle)
    {
        if (_SettledAt < 0.0f)
        { _SettledAt = float32(System::GetGameTimeInSeconds()); }
    }
}
