// A reset in each busy phase (Reach, Grasp, Carry, AwaitAdmission, and Return after an admission) starts a new attempt: the
// generation moves on, the hand is idle and nothing is admitted; the platter is the stock and nothing refills it. While the
// hand reaches the reserved piece is still on the platter; from the grasp the feed has taken it into the hand, and the
// reset puts it back itself, so all six are there again. At AwaitAdmission the released piece was let go; the reset
// settles it Cancelled under its old id and it goes back (as the bridge would), so six are there again. The Return round's
// piece already settled Admitted, settles nothing more and stays spent: five are left.
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
            Add_Step(f"press add food (reset in {Target :n})", n"Step_Begin");
            if (Target == EMars_CookingFeed_Phase::Return)
            {
                Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 2.0f);
                Add_Step("accept the release", n"Step_AcceptPending");
            }

            Add_Step_WaitUntil(f"the hand is in {Target :n}", n"Check_AtTarget", 0, 2.0f);
            Add_Step(f"reset in {Target :n}", n"Step_Reset");
            Add_Step_WaitUntil("the reset applied", n"Check_ResetApplied", 0, 1.0f);
            Add_Step_WaitUntil("the stock is back on the platter", n"Check_StockSettled", 0, 1.0f);
            Add_Step(f"the ledger after the reset in {Target :n}", n"Step_AssertReset");
        }

        Run_Steps(InHandle);
    }

    // Only the Return round has spent a piece.
    private int32 Get_ExpectedStock() const
    {
        return _Targets[_Round] == EMars_CookingFeed_Phase::Return ? k_Stock - 1 : k_Stock;
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
    private void Check_ResetApplied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Generation() == _GenerationBefore + 1);
    }

    UFUNCTION()
    private void Check_StockSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == Get_ExpectedStock() && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertReset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Targets[_Round];
        const auto ExpectedStock = Get_ExpectedStock();
        _Round += 1;

        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"idle after the reset in {Target :n} (got {_Feed.Get_Phase() :n})");
        Assert_Ledger(ExpectedStock, 0, f"after the reset in {Target :n}");
        Assert_Equals_Int(_Platter.Get_HeldCount(), ExpectedStock, f"the platter holds {ExpectedStock} after the reset in {Target :n}");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");

        const auto NewSettles = _Settles.Num() - _SettlesBefore;
        if (Target == EMars_CookingFeed_Phase::Return)
        {
            Assert_False(_ActiveBefore.IsSet(), "the returning hand held no reservation");
            Assert_Equals_Int(NewSettles, 0, "the reset settled nothing more");
            return;
        }

        Assert_True(_ActiveBefore.IsSet(), f"a piece was reserved in {Target :n}");
        if (Target == EMars_CookingFeed_Phase::Reach)
        { Assert_True(_ActivePieceBefore.TryGet_Platter() == _Platter, "the piece reserved while reaching was still on the platter"); }

        Assert_True(_ActivePieceBefore.TryGet_Platter() == _Platter, f"the piece reserved in {Target :n} is back on the platter");
        Assert_Equals_Int(NewSettles, 1, "the reset settled the reservation once");
        if (NewSettles != 1 || _ActiveBefore.IsSet() == false)
        { return; }

        Assert_True(_Settles.Last() == EMars_CookingFeed_Settle::Cancelled, "it settled Cancelled");
        Assert_True(_SettledPieces.Last().Get_IsSame(_ActiveBefore.GetValue()), "under its old id");
        Assert_Equals_Int(_SettledPieces.Last().Generation, _GenerationBefore, "of the old generation");
    }
}
