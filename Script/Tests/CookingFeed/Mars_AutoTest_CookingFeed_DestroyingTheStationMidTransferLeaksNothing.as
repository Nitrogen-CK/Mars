// The station entity destroyed while the hand carries a piece takes the feed with it: the handle goes invalid, no release
// and no settle ever arrive, and nothing ensures. The carried piece rode the station's hand node; the feed's teardown ends
// it with the station (in a station the platter it came from goes in the same teardown, so nothing could take it back).
// The rig's platter outlives the station here: the rest of its pile re-settles after the unload and it keeps the other five.
class UMars_AutoTest_CookingFeed_DestroyingTheStationMidTransferLeaksNothing : UMars_AutoTestRig_CookingFeed
{
    private int32 _SignalsAtDestroy = 0;
    private FCk_Handle_FoodPiece _Carried;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand carries the piece", n"Check_Carrying", 0, 0);
        Add_Step("destroy the station", n"Step_DestroyStation");
        Add_Step_WaitUntil("the feed and the carried piece are gone", n"Check_FeedAndPieceGone", 0, 0);
        Add_Step_WaitSeconds("past the carry's end", 0.3f);
        Add_Step_WaitUntil("the platter's pile has re-settled", n"Check_PileSettled", k_SlowPolls, 0);
        Add_Step("no release, no settle, no signal since; the platter keeps the other five", n"Step_AssertNothingLeaked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Carrying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Carry && _Feed.TryGet_PieceHold() == EMars_CookingFeed_PieceHold::InHand);
    }

    UFUNCTION()
    private void Step_DestroyStation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Ledger(k_Stock - 1, 0, "carrying");
        _Carried = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(ck::IsValid(_Carried), "the feed names the carried piece");
        Assert_False(ck::IsValid(_Carried.TryGet_Platter()), "the carried piece is off the platter");
        _SignalsAtDestroy = _Phases.Num() + _Releases.Num() + _Settles.Num() + _Refusals.Num() + _StockAvailable.Num();
        utils_entity_lifetime::Request_DestroyEntity(_Station);
    }

    UFUNCTION()
    private void Check_FeedAndPieceGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsPieceGone = ck::Is_NOT_Valid(_Carried)
            || utils_entity_lifetime::Get_IsPendingDestroy(_Carried, ECk_EntityLifetime_DestructionPhase::BeginDestroy);

        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Feed) && ck::Is_NOT_Valid(_Station) && IsPieceGone);
    }

    UFUNCTION()
    private void Step_AssertNothingLeaked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 0, "no release");
        Assert_Equals_Int(_Settles.Num(), 0, "no settle");
        const auto Signals = _Phases.Num() + _Releases.Num() + _Settles.Num() + _Refusals.Num() + _StockAvailable.Num();
        Assert_Equals_Int(Signals, _SignalsAtDestroy, "no signal after the destroy");
        Assert_False(ck::IsValid(_ReleaseNode), "the release node went with the station");
        Assert_False(ck::IsValid(_Carried), "the carried piece ended with the station");
        Assert_Equals_Int(_Platter.Get_HeldCount(), k_Stock - 1, "the platter keeps the other five");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 0, "and nothing comes back to it");
    }
}
