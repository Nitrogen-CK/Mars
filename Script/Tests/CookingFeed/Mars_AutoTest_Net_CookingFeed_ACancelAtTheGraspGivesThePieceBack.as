// The server sources its feed and presses add food; in the first frame its piece rides the hand it cancels. Once the
// platter has frozen the piece again it publishes the rides and reports: it settled one transfer Cancelled. On the client
// the piece rides its platter at the server's ride and hangs from no hand node, the feed is idle with two available, and it
// raised no refusal.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_ACancelAtTheGraspGivesThePieceBack
class UCk_AutoTest_Net_CookingFeed_ACancelAtTheGraspGivesThePieceBack : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 273000.0;

    private FGuid _PieceId;

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
        Begin_Transfer();
        Await_InHand(n"OnServerInHand");
    }

    UFUNCTION()
    private void OnServerInHand(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PieceId = _Feed.TryGet_ActiveFoodPiece().Get_Id();
        _Feed.Request_Cancel(FMars_Request_CookingFeed_Cancel());
        Await_PileFrozen(2, n"OnServerFrozenAgain");
    }

    UFUNCTION()
    private void OnServerFrozenAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Report = Make_FeedStep(1);
        Report.PieceId = _PieceId;
        Publish_FeedStep(Report);
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Cancelled, f"the server settled one transfer Cancelled ({Describe_Record()})");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the server's feed is idle");
        End_FeedServer(f"{Describe_Record()} {Describe_Counts()}");
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_FeedReport();
        const auto Piece = Find_PieceById(Report.PieceId);
        const auto Fault = Get_PileFault();
        Assert_True(Fault.IsEmpty(), f"the client's pile rides its platter at the server's rides ({Fault})");
        Assert_True(Get_IsLive(Piece) && Get_IsUnderFeedHand(Piece) == false, "the client's piece is not under its hand node");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the client's feed is idle");
        Assert_Equals_Int(_Feed.Get_Available(), 2, "the client's feed reads two available");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetFeedEvent::TransferRefused), 0, "the client raised no refusal");
        End_FeedClient(f"{Describe_Record()} pileFault=[{Fault}] {Describe_Counts()}");
    }
}
