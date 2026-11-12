// On the station with four zero-length phases the server sources its feed and presses add food: the transfer reaches
// AwaitAdmission in the frame of its press. It answers Accepted for the pending release's piece; once the hand is idle and
// the piece is off the platter it reports the piece's world pose. On the client the feed is idle with one admitted and one
// available, its piece lies at the server's pose and hangs from no hand node on any frame sampled after the report, and its
// hand is at rest.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_AWholeTransferInOneFrameLeavesTheClientConsistent
class UCk_AutoTest_Net_CookingFeed_AWholeTransferInOneFrameLeavesTheClientConsistent : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 276000.0;
    private const float64 k_PieceToleranceCm = 1.0;

    private FCk_Handle_FoodPiece _Piece;
    // Client: the frame its report arrived.
    private int64 _ReportFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _StationKind = EMars_TESTONLY_NetFeedStationKind::Instant;
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
        const auto PieceId = _Feed.Get_PendingRelease().PieceId;
        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(PieceId, EMars_CookingFeed_Admission::Accepted, "test answer"));
        WaitUntil(n"Is_ServerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle && ck::Is_NOT_Valid(_Piece.TryGet_Platter()));
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Report = Make_FeedStep(1);
        Report.PieceId = _Piece.Get_Id();
        Report.PieceWorld = Get_PieceWorld(_Piece);
        Publish_FeedStep(Report);
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the server admitted one");
        End_FeedServer(f"{Describe_Record()} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }

    protected void On_FeedSample() override
    {
        if (Get_IsServer() == false && _ReportFrame < 0 && Get_FeedReport().Step >= 1)
        { _ReportFrame = utils_time::Get_FrameCounter(); }
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_FeedReport();
        _Piece = Find_PieceById(Report.PieceId);
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the client's feed is idle");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        Assert_Equals_Int(_Feed.Get_Available(), 1, "the client's feed reads one available");

        auto PieceCm = -1.0;
        Assert_True(Get_IsLive(_Piece), "the client finds its piece");
        if (Get_IsLive(_Piece))
        {
            PieceCm = Get_PieceWorld(_Piece).GetLocation().Distance(Report.PieceWorld.GetLocation());
            Assert_True(PieceCm <= k_PieceToleranceCm, f"the client's piece lies where the server's does (off by {PieceCm} cm)");
        }

        Assert_True(_ReportFrame >= 0 && _LastUnderHandFrame < _ReportFrame,
            f"no food hung from the client's hand node after the report (last frame {_LastUnderHandFrame}, report frame {_ReportFrame})");
        Assert_True(Get_IsHandAtRest(), f"the client's hand is at rest ({Describe_HandRest()})");
        End_FeedClient(f"{Describe_Record()} pieceCm={PieceCm} lastUnderHand={_LastUnderHandFrame} reportFrame={_ReportFrame} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }
}
