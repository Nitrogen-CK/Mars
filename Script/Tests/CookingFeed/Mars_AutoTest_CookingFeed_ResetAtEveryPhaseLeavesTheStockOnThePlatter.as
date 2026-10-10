// A reset in each busy phase (Reach, Grasp, Carry, AwaitAdmission, and Return after an admission) leaves the stock on the
// platter; nothing refills it. While the hand reaches or grasps the reset is a new attempt: the generation moves on, the
// hand is idle, the reservation settles Cancelled under its old id and nothing is admitted; a piece the grasp already took
// goes back (the feed's own put-back), so all six are there again. A transfer past its grasp is committed: in Carry and in
// AwaitAdmission the reset changes nothing (same generation, same phase, nothing settled), the release still comes, and
// once it is rejected the feed itself puts its piece back on the platter it came from, so six are there again. The Return
// round's piece already settled Admitted: the reset starts a new attempt (the generation moves on, nothing admitted) and
// leaves the hand to finish its return; five are left.
class UMars_AutoTest_CookingFeed_ResetAtEveryPhaseLeavesTheStockOnThePlatter : UMars_AutoTestRig_CookingFeed
{
    private TArray<EMars_CookingFeed_Phase> _Targets;
    private int32 _Round = 0;
    private int32 _GenerationBefore = 0;
    private int32 _SettlesBefore = 0;
    private TOptional<FMars_CookingFeed_PieceId> _ActiveBefore;
    private FCk_Handle_FoodPiece _ActivePieceBefore;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // Long enough phases that a wait polled every frame sees each one.
        auto Spec = Make_TestSpec();
        Spec.Timing = FMars_CookingFeed_TimingSpec(0.25f, 0.25f, 0.25f, 0.25f);
        BuildFeed(InHandle, Spec);
        Add_Steps_SourceTheFeed();

        _Targets.Add(EMars_CookingFeed_Phase::Reach);
        _Targets.Add(EMars_CookingFeed_Phase::Grasp);
        _Targets.Add(EMars_CookingFeed_Phase::Carry);
        _Targets.Add(EMars_CookingFeed_Phase::AwaitAdmission);
        _Targets.Add(EMars_CookingFeed_Phase::Return);

        for (const auto Target : _Targets)
        {
            Add_Step_WaitUntil(f"the pile has settled (reset in {Target :n})", n"Check_PileSettled", 0, 0);
            Add_Step(f"press add food (reset in {Target :n})", n"Step_Begin");
            if (Target == EMars_CookingFeed_Phase::Return)
            {
                Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 0);
                Add_Step("accept the release", n"Step_AcceptPending");
            }

            Add_Step_WaitUntil(f"the hand is in {Target :n}", n"Check_AtTarget", 0, 0);
            Add_Step(f"reset in {Target :n}", n"Step_Reset");
            Add_Step_WaitFrames("the reset drains", 2);
            Add_Step(f"what the reset in {Target :n} did", n"Step_AssertReset");

            if (Target == EMars_CookingFeed_Phase::Carry || Target == EMars_CookingFeed_Phase::AwaitAdmission)
            {
                Add_Step_WaitUntil("the committed transfer still releases", n"Check_AwaitingAdmission", 0, 0);
                Add_Step("reject the release", n"Step_RejectPending");
            }

            Add_Step_WaitUntil("the hand is at rest", n"Check_Idle", 0, 0);
            Add_Step_WaitUntil("the stock is back on the platter", n"Check_StockSettled", k_SlowPolls, 0);
            Add_Step(f"the ledger after the round of {Target :n}", n"Step_AssertRound");
        }

        Run_Steps(InHandle);
    }

    // Only the Return round has spent a piece.
    private int32 Get_ExpectedStock() const
    {
        return _Targets[_Round] == EMars_CookingFeed_Phase::Return ? k_Stock - 1 : k_Stock;
    }

    private bool Get_IsCommittedRound() const
    {
        const auto Target = _Targets[_Round];
        return Target == EMars_CookingFeed_Phase::Carry || Target == EMars_CookingFeed_Phase::AwaitAdmission;
    }

    UFUNCTION()
    private void Check_AtTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == _Targets[_Round]);
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _GenerationBefore = _Feed.Get_Generation();
        _SettlesBefore = _Settles.Num();
        _ActiveBefore = _Feed.TryGet_ActivePiece();
        _ActivePieceBefore = _Feed.TryGet_ActiveFoodPiece();
        Reset();
    }

    UFUNCTION()
    private void Step_AssertReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Targets[_Round];
        const auto NewSettles = _Settles.Num() - _SettlesBefore;

        if (Get_IsCommittedRound())
        {
            Assert_Equals_Int(_Feed.Get_Generation(), _GenerationBefore, f"the reset in {Target :n} kept the generation");
            Assert_Equals_Int(NewSettles, 0, f"the reset in {Target :n} settled nothing");
            Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Carry || _Feed.Get_Phase() == EMars_CookingFeed_Phase::AwaitAdmission,
                f"the committed transfer carries on (got {_Feed.Get_Phase() :n})");
            Assert_True(_ActiveBefore.IsSet() && _Feed.TryGet_ActivePiece().IsSet() && _Feed.TryGet_ActivePiece().GetValue().Get_IsSame(_ActiveBefore.GetValue()),
                "under the same reservation");
            return;
        }

        Assert_Equals_Int(_Feed.Get_Generation(), _GenerationBefore + 1, f"the reset in {Target :n} moved the generation on");
        Assert_Equals_Int(_Feed.Get_Admitted(), 0, f"nothing is admitted after the reset in {Target :n}");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");

        if (Target == EMars_CookingFeed_Phase::Return)
        {
            Assert_False(_ActiveBefore.IsSet(), "the returning hand held no reservation");
            Assert_Equals_Int(NewSettles, 0, "the reset settled nothing more");
            return;
        }

        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"idle after the reset in {Target :n} (got {_Feed.Get_Phase() :n})");
        Assert_True(_ActiveBefore.IsSet(), f"a piece was reserved in {Target :n}");
        if (Target == EMars_CookingFeed_Phase::Reach)
        { Assert_True(_ActivePieceBefore.TryGet_Platter() == _Platter, "the piece reserved while reaching was still on the platter"); }

        Assert_Equals_Int(NewSettles, 1, "the reset settled the reservation once");
        if (NewSettles != 1 || _ActiveBefore.IsSet() == false)
        { return; }

        Assert_True(_Settles.Last() == EMars_CookingFeed_Settle::Cancelled, "it settled Cancelled");
        Assert_True(_SettledPieces.Last().Get_IsSame(_ActiveBefore.GetValue()), "under its old id");
        Assert_Equals_Int(_SettledPieces.Last().Generation, _GenerationBefore, "of the old generation");
    }

    UFUNCTION()
    private void Check_StockSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == Get_ExpectedStock() && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertRound(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Targets[_Round];
        const auto ExpectedStock = Get_ExpectedStock();
        const auto IsCommittedRound = Get_IsCommittedRound();
        _Round += 1;

        Assert_Ledger(ExpectedStock, 0, f"after the round of {Target :n}");
        Assert_Equals_Int(_Platter.Get_HeldCount(), ExpectedStock, f"the platter holds {ExpectedStock} after the round of {Target :n}");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");

        if (Target != EMars_CookingFeed_Phase::Reach && Target != EMars_CookingFeed_Phase::Return)
        {
            Assert_True(_ActivePieceBefore.TryGet_Platter() == _Platter, f"the piece taken in {Target :n} is back on the platter");
            Assert_True(_Platter.Get_Held().Contains(_ActivePieceBefore), f"and landed there");
        }

        if (IsCommittedRound == false)
        { return; }

        Assert_Equals_Int(_Settles.Num() - _SettlesBefore, 1, f"the round of {Target :n} settled once, by its answer");
        Assert_True(_Settles.Last() == EMars_CookingFeed_Settle::Rejected, "it settled Rejected");
        Assert_True(_ActiveBefore.IsSet() && _SettledPieces.Last().Get_IsSame(_ActiveBefore.GetValue()), "under the reservation the reset left be");
    }
}
