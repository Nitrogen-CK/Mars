// The station entity destroyed while the hand carries a piece takes the feed with it: the handle goes invalid, no release
// and no settle ever arrive, and nothing ensures. The pieces are the platter's and the platter is the test's: the carried
// piece rode the station's hand node, and the feed's teardown puts it back, so the platter holds all six again.
class UMars_AutoTest_CookingFeed_DestroyingTheStationMidTransferLeaksNothing : UMars_AutoTestRig_CookingFeed
{
    private int32 _SignalsAtDestroy = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand carries the piece", n"Check_Carrying", 0, 2.0f);
        Add_Step("destroy the station", n"Step_DestroyStation");
        Add_Step_WaitUntil("the feed is gone", n"Check_FeedGone", 0, 2.0f);
        Add_Step_WaitSeconds("past the carry's end", 0.3f);
        Add_Step_WaitUntil("the carried piece is back on the platter", n"Check_StockBack", 0, 3.0f);
        Add_Step("no release, no settle, no signal since; the platter holds the stock again", n"Step_AssertNothingLeaked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Carrying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Carry);
    }

    UFUNCTION()
    private void Check_StockBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == k_Stock && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_DestroyStation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock - 1, 0, "carrying");
        Assert_False(ck::IsValid(_Feed.TryGet_ActiveFoodPiece().TryGet_Platter()), "the carried piece is off the platter");
        _SignalsAtDestroy = _Phases.Num() + _Releases.Num() + _Settles.Num() + _Refusals.Num() + _StockAvailable.Num();
        utils_entity_lifetime::Request_DestroyEntity(_Station);
    }

    UFUNCTION()
    private void Check_FeedGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Feed) && ck::Is_NOT_Valid(_Station));
    }

    UFUNCTION()
    private void Step_AssertNothingLeaked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 0, "no release");
        Assert_Equals_Int(_Settles.Num(), 0, "no settle");
        const auto Signals = _Phases.Num() + _Releases.Num() + _Settles.Num() + _Refusals.Num() + _StockAvailable.Num();
        Assert_Equals_Int(Signals, _SignalsAtDestroy, "no signal after the destroy");
        Assert_False(ck::IsValid(_ReleaseNode), "the release node went with the station");
        Assert_Equals_Int(_Platter.Get_HeldCount(), k_Stock, "the platter still holds all six pieces");
    }
}
