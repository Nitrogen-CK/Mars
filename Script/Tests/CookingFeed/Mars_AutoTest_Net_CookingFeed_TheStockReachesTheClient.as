// The server sources its feed from the platter of two frozen slabs (step 1), and 1.5 s later sources it from no platter
// (step 2). At step 1 the client's copy reads sourced from its own copy of the platter, two available, none admitted, not
// settling and idle; at step 2 not sourced and none available. Each machine raised OnStockChanged (2, 0) then (0, 0) and
// nothing else.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_TheStockReachesTheClient
class UCk_AutoTest_Net_CookingFeed_TheStockReachesTheClient : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 270000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FeedRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_FeedStep(1, n"OnClientStep1"); }
    }

    protected void On_ServerFeedFound() override
    {
        Source_AfterBind();
    }

    protected void On_ServerSourced() override
    {
        Publish_FeedStep(Make_FeedStep(1));
        WaitSeconds(k_StepSeconds, n"OnServerUnsource");
    }

    UFUNCTION()
    private void OnServerUnsource(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(FCk_Handle_Platter()));
        WaitUntil(n"Is_ServerUnsourced", n"OnServerUnsourced", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerUnsourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Feed.Get_IsSourced() == false);
    }

    UFUNCTION()
    private void OnServerUnsourced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_FeedStep(Make_FeedStep(2));
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsStockTwoThenNone(), f"the server raised OnStockChanged (2, 0) then (0, 0) and nothing else ({Describe_Record()})");
        End_FeedServer(Describe_Record());
    }

    private bool Get_IsStockTwoThenNone()
    {
        return _Events.Num() == 2 && Get_EventCount(EMars_TESTONLY_NetFeedEvent::StockChanged) == 2
            && _StockAvailable[0] == 2 && _StockAdmitted[0] == 0 && _StockAvailable[1] == 0 && _StockAdmitted[1] == 0;
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Feed.Get_IsSourced(), "the client's feed reads sourced");
        Assert_True(Try_FindPlatter() && _Feed.Get_Source() == _Platter, "the client's feed reads its own copy of the platter as its source");
        Assert_Equals_Int(_Feed.Get_Available(), 2, "the client's feed reads two available");
        Assert_Equals_Int(_Feed.Get_Admitted(), 0, "the client's feed reads none admitted");
        Assert_False(_Feed.Get_IsSettling(), "the client's feed reads the pile frozen");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the client's feed is idle");
        Await_FeedStep(2, n"OnClientStep2");
    }

    UFUNCTION()
    private void OnClientStep2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Feed.Get_IsSourced(), "the client's feed reads unsourced");
        Assert_Equals_Int(_Feed.Get_Available(), 0, "the client's feed reads none available");
        Assert_True(Get_IsStockTwoThenNone(), f"the client raised OnStockChanged (2, 0) then (0, 0) and nothing else ({Describe_Record()})");
        End_FeedClient(f"{Describe_Record()} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }
}
