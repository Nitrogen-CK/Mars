// A source change reaches a transfer in any phase. The feed awaits the answer for a released piece when its source goes
// (the dock lets the platter go: SetSource with none): the transfer settles Cancelled under its id, the hand is at rest at
// once, and the released piece goes back to the platter it came from, which is still alive though the feed no longer draws
// from it. It lands there again (the platter's OnLoaded names it a second time) and the platter holds all six; the feed,
// unsourced, has nothing available and admitted nothing.
class UMars_AutoTest_CookingFeed_AnUndockDuringAwaitAdmissionReturnsThePiece : UMars_AutoTestRig_CookingFeed
{
    private FCk_Handle_FoodPiece _Piece;
    private FMars_CookingFeed_PieceId _Awaited;
    private int32 _GenerationBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("the dock lets the platter go: unsource the feed", n"Step_Unsource");
        Add_Step_WaitUntil("the transfer settles and the hand is at rest", n"Check_SettledAndIdle", 0, 0);
        Add_Step_WaitUntil("the piece landed back on the platter it came from", n"Check_LandedBack", k_SlowPolls, 0);
        Add_Step("cancelled; the piece is that platter's again; the feed is unsourced", n"Step_AssertReturned");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Unsource(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Piece = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(ck::IsValid(_Piece), "a piece is reserved");
        Assert_True(_Feed.TryGet_PieceHold() == EMars_CookingFeed_PieceHold::Released, "and released");
        if (_Feed.TryGet_ActivePiece().IsSet())
        { _Awaited = _Feed.TryGet_ActivePiece().GetValue(); }

        _GenerationBefore = _Feed.Get_Generation();
        SetSource(FCk_Handle_Platter());
    }

    UFUNCTION()
    private void Check_SettledAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Settles.Num() > 0 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
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
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Cancelled, "it settled Cancelled");
        Assert_True(_SettledPieces.Num() == 1 && _SettledPieces[0].Get_IsSame(_Awaited), "under the awaited id");
        Assert_True(_Feed.Get_Generation() > _GenerationBefore, "the generation moved on");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");
        Assert_False(_Feed.Get_IsSourced(), "the feed is unsourced");
        Assert_Ledger(0, 0, "unsourced");

        Assert_True(_Piece.TryGet_Platter() == _Platter, "the piece is the platter's again");
        Assert_True(_Platter.Get_Held().Contains(_Piece), "frozen into its pile");
        Assert_Equals_Int(_Phases.FindIndex(EMars_CookingFeed_Phase::Return), -1, "the hand never ran a Return: it rests at once");
    }
}
