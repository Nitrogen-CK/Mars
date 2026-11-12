// The server sources its feed, presses add food and answers the release Rejected; once the platter has frozen the piece
// again and the hand is idle it publishes the rides and reports. On the client the piece rides its platter at the server's
// ride and hangs from no hand node, two are available and none admitted, the last phase it raised is Idle and its hand is
// at rest.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_ARejectedPieceGoesBackOnTheClient
class UCk_AutoTest_Net_CookingFeed_ARejectedPieceGoesBackOnTheClient : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 272000.0;

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
        Await_Phase(EMars_CookingFeed_Phase::AwaitAdmission, n"OnServerAwaiting");
    }

    UFUNCTION()
    private void OnServerAwaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PieceId = _Feed.TryGet_ActiveFoodPiece().Get_Id();
        Answer(EMars_CookingFeed_Admission::Rejected);
        Await_PileFrozen(2, n"OnServerFrozenAgain");
    }

    UFUNCTION()
    private void OnServerFrozenAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_Phase(EMars_CookingFeed_Phase::Idle, n"OnServerIdle");
    }

    UFUNCTION()
    private void OnServerIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Report = Make_FeedStep(1);
        Report.PieceId = _PieceId;
        Publish_FeedStep(Report);
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Rejected, "the server settled one transfer Rejected");
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
        Assert_Equals_Int(_Feed.Get_Available(), 2, "the client's feed reads two available");
        Assert_Equals_Int(_Feed.Get_Admitted(), 0, "the client's feed reads none admitted");
        Assert_True(_Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle, f"the last phase the client raised is Idle ({Describe_Record()})");
        Assert_True(Get_IsHandAtRest(), f"the client's hand is at rest ({Describe_HandRest()})");
        End_FeedClient(f"{Describe_Record()} pileFault=[{Fault}] {Describe_Counts()}");
    }
}
