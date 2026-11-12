// With one slab on the platter the server sources its feed and presses add food; at AwaitAdmission it destroys the
// platter, and once it is gone answers Rejected: no platter is left, so the slab is let go where it lies (OnPieceLetGo
// once). When the slab has come to rest it reports its pose. The client raised OnPieceLetGo once, its ledger counts one
// piece let go, its feed reads unsourced and idle, and its slab hangs from no node and lies at the server's pose.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_APieceLetGoIsSaidOnTheClient
class UCk_AutoTest_Net_CookingFeed_APieceLetGoIsSaidOnTheClient : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 280000.0;
    private const float64 k_PieceToleranceCm = 2.0;

    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _SlabCount = 1;
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
        Begin_Transfer();
        Await_Phase(EMars_CookingFeed_Phase::AwaitAdmission, n"OnServerAwaiting");
    }

    UFUNCTION()
    private void OnServerAwaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = _Feed.TryGet_ActiveFoodPiece();
        utils_entity_lifetime::Request_DestroyEntity(_PlatterEntity);
        WaitUntil(n"Is_ServerPlatterGone", n"OnServerPlatterGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPlatterGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_cooking_feed::Get_IsAlive(_Platter) == false);
    }

    UFUNCTION()
    private void OnServerPlatterGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Answer(EMars_CookingFeed_Admission::Rejected);
        _Rock = _Piece;
        Reset_RockStill();
        WaitUntil(n"Is_ServerSlabAtRest", n"OnServerSlabAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Still = Tick_RockStill();
        auto Result = OutResult;
        Result.Set(Still && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle && _LetGo > 0);
    }

    UFUNCTION()
    private void OnServerSlabAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Report = Make_FeedStep(1);
        Report.PieceId = _Piece.Get_Id();
        Report.PieceWorld = Get_PieceWorld(_Piece);
        Publish_FeedStep(Report);
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_LetGo, 1, f"the server raised OnPieceLetGo once ({Describe_Record()})");
        End_FeedServer(f"{Describe_Record()} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_FeedReport();
        const auto Ledger = _Feed.Get_Ledger();
        _Piece = Find_PieceById(Report.PieceId);
        Assert_Equals_Int(_LetGo, 1, f"the client raised OnPieceLetGo once ({Describe_Record()})");
        Assert_Equals_Int(Ledger.LetGoSerial, 1, "the client's ledger counts one piece let go");
        Assert_False(_Feed.Get_IsSourced(), "the client's feed reads unsourced");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the client's feed is idle");

        auto PieceCm = -1.0;
        Assert_True(Get_IsLive(_Piece), "the client finds its slab");
        if (Get_IsLive(_Piece))
        {
            Assert_True(ck::Is_NOT_Valid(Get_Parent(_Piece)), f"the client's slab hangs from no node ([{Get_Parent(_Piece).ToString()}])");
            PieceCm = Get_PieceWorld(_Piece).GetLocation().Distance(Report.PieceWorld.GetLocation());
            Assert_True(PieceCm <= k_PieceToleranceCm, f"the client's slab lies where the server's does (off by {PieceCm} cm)");
        }

        End_FeedClient(f"{Describe_Record()} pieceCm={PieceCm} ledger [{Describe_Ledger(Ledger)}]");
    }
}
