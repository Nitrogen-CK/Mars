// The reserved piece unloaded from the platter by someone else while the hand reaches cancels the transfer within a frame:
// it settles Cancelled under the reservation's id, the hand is at rest before it ever grasps, and the stock is the five
// still on the platter. The next press reserves the next piece.
class UMars_AutoTest_CookingFeed_AReservedPieceTakenOffThePlatterCancelsTheTransfer : UMars_AutoTestRig_CookingFeed
{
    private FMars_CookingFeed_PieceId _Reserved;
    private FCk_Handle_FoodPiece _TakenPiece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // A Reach long enough that the unload lands inside it.
        auto Spec = Make_TestSpec();
        Spec.Timing = FMars_CookingFeed_TimingSpec(0.5f, 0.05f, 0.1f, 0.1f);
        BuildFeed(InHandle, Spec);
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand reaches", n"Check_Reaching", 0, 1.0f);
        Add_Step("unload the reserved piece from the platter", n"Step_TakeTheReservedPiece");
        Add_Step_WaitUntil("the transfer settles within a frame of the unload", n"Check_Settled", 0, 0.1f);
        Add_Step("cancelled, at rest, five left", n"Step_AssertCancelled");
        Add_Step("press add food again", n"Step_Begin");
        Add_Step_WaitUntil("the hand reaches again", n"Check_Reaching", 0, 1.0f);
        Add_Step("the next piece is reserved", n"Step_AssertNextReserved");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TakeTheReservedPiece(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _TakenPiece = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(ck::IsValid(_TakenPiece), "the feed names the reserved piece");
        Assert_True(_TakenPiece.TryGet_Platter() == _Platter, "the reserved piece is on the platter");
        if (_Feed.TryGet_ActivePiece().IsSet())
        { _Reserved = _Feed.TryGet_ActivePiece().GetValue(); }

        if (ck::IsValid(_TakenPiece))
        { _Platter.Request_Unload(FMars_Request_Platter_Unload(_TakenPiece)); }
    }

    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Settles.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Cancelled, "it settled Cancelled");
        Assert_True(_SettledPieces.Num() == 1 && _SettledPieces[0].Get_IsSame(_Reserved), "under the reservation's id");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, f"the hand is at rest (got {_Feed.Get_Phase() :n})");
        Assert_Equals_Int(Get_PhaseCount(EMars_CookingFeed_Phase::Grasp), 0, "the hand never grasped");
        Assert_Equals_Int(_Releases.Num(), 0, "nothing was released");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");
        Assert_False(ck::IsValid(_TakenPiece.TryGet_Platter()), "the taken piece is off the platter");
        Assert_Ledger(k_Stock - 1, 0, "after the unload");
    }

    UFUNCTION()
    private void Step_AssertNextReserved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Next = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(ck::IsValid(Next) && Next != _TakenPiece, "a different piece is reserved");
        Assert_True(Next.TryGet_Platter() == _Platter, "it is on the platter");
        const auto Active = _Feed.TryGet_ActivePiece();
        Assert_True(Active.IsSet() && Active.GetValue().StockIndex != _Reserved.StockIndex, "from another slot");
        Assert_Equals_Int(_Refusals.Num(), 0, "no press was refused");
    }
}
