// The feed is the one owner of the put-back. The rig answers releases and puts nothing back itself: a release answered
// Rejected comes back to the platter it was reserved from by the feed's own hand. The piece lands there again (the
// platter's OnLoaded names it a second time) and freezes into the pile, the stock is whole, the transfer settled Rejected
// once, and the hand ran its Return to rest.
class UMars_AutoTest_CookingFeed_ARejectedReleaseReturnsToThePlatterItCameFrom : UMars_AutoTestRig_CookingFeed
{
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("the released piece is off the platter; reject it", n"Step_AssertReleasedAndReject");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 0);
        Add_Step_WaitUntil("the piece landed back on the platter", n"Check_LandedBack", k_SlowPolls, 0);
        Add_Step("it is the platter's again and nothing was spent", n"Step_AssertReturned");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertReleasedAndReject(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 1, "one release");
        _Piece = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(ck::IsValid(_Piece) && _Releases.Num() == 1 && _Piece == _Releases[0].Piece, "the release carries the reserved piece");
        Assert_True(_Feed.TryGet_PieceHold() == EMars_CookingFeed_PieceHold::Released, "the feed let it go");
        Assert_False(ck::IsValid(_Piece.TryGet_Platter()), "the released piece is on no platter");
        Assert_Equals_Int(Get_LandedCount(_Piece), 1, "it landed on the platter once, with the stock");

        Step_RejectPending(InHandle, InPayload);
    }

    UFUNCTION()
    private void Check_LandedBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_LandedCount(_Piece) == 2 && _Platter.Get_HeldCount() == k_Stock && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertReturned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Piece.TryGet_Platter() == _Platter, "the piece is the platter's again");
        Assert_True(_Platter.Get_Held().Contains(_Piece), "frozen into its pile");
        Assert_Ledger(k_Stock, 0, "after the rejection");
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Rejected, "it settled Rejected");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");

        const auto ReturnIndex = _Phases.FindIndex(EMars_CookingFeed_Phase::Return);
        Assert_True(ReturnIndex >= 0 && ReturnIndex == _Phases.Num() - 2, "the hand ran its Return");
        Assert_True(_Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle, "and ended at rest");
    }
}
