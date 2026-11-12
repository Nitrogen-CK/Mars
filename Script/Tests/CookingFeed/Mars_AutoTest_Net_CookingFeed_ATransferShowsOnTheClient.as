// The server sources its feed and presses add food. Through the carry it samples its piece's offset under its hand node;
// at AwaitAdmission it reports step 1 (the piece, its hand's offset, that held offset and the piece's world pose), holds
// 1.5 s and answers Accepted; at Idle it reports step 2. The client raised Reach, Grasp, Carry, AwaitAdmission, Return and
// Idle once each, in order; through the carry its own copy of the piece rode its own hand node at the server's held offset
// for at least ten frames. At step 1 it awaits admission with its hand where the server's is and its piece, let go, where
// the server's lies; at step 2 it is idle with one admitted and its hand at rest. Its hand never moved 30 cm or more in one
// frame and its phase progress never went down inside a phase.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_ATransferShowsOnTheClient
class UCk_AutoTest_Net_CookingFeed_ATransferShowsOnTheClient : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 271000.0;
    private const float64 k_HeldToleranceCm = 0.1;
    private const float64 k_HeldToleranceDegrees = 0.5;
    private const int32 k_MinCarryFrames = 10;
    private const float64 k_HandToleranceCm = 0.5;
    private const float64 k_PieceToleranceCm = 1.0;
    private const float64 k_MaxHandStepCm = 30.0;

    private FCk_Handle_FoodPiece _Piece;

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
        _Piece = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(_CarryHeld.Num() > 0, "the server sampled its piece under its hand through the carry");

        auto Report = Make_FeedStep(1);
        Report.PieceId = _Piece.Get_Id();
        if (_CarryHeld.Num() > 0)
        { Report.HeldLocal = _CarryHeld.Last(); }

        Report.PieceWorld = Get_PieceWorld(_Piece);
        Publish_FeedStep(Report);
        WaitSeconds(k_StepSeconds, n"OnServerAnswer");
    }

    UFUNCTION()
    private void OnServerAnswer(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Answer(EMars_CookingFeed_Admission::Accepted);
        Await_Phase(EMars_CookingFeed_Phase::Idle, n"OnServerIdle");
    }

    UFUNCTION()
    private void OnServerIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_FeedStep(Make_FeedStep(2));
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_ArePhases(Get_TransferPhases()), f"the server raised one transfer's phases ({Describe_Record()})");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Admitted, "the server settled one transfer Admitted");
        End_FeedServer(f"{Describe_Record()} carryFrames={_CarryHeld.Num()} handMaxStepCm={_HandMaxStepCm}");
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_FeedReport();
        _Piece = Find_PieceById(Report.PieceId);
        Assert_True(Get_IsLive(_Piece), "the client finds its piece");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::AwaitAdmission, f"the client's feed awaits admission (reads {_Feed.Get_Phase() :n})");

        const auto HandCm = Get_HandOffset().GetLocation().Distance(Report.HandLocal.GetLocation());
        Assert_True(HandCm <= k_HandToleranceCm, f"the client's hand is where the server's is (off by {HandCm} cm)");

        auto PieceCm = -1.0;
        if (Get_IsLive(_Piece))
        {
            Assert_False(Get_IsUnderFeedHand(_Piece), "the client's piece hangs from no hand node");
            PieceCm = Get_PieceWorld(_Piece).GetLocation().Distance(Report.PieceWorld.GetLocation());
            Assert_True(PieceCm <= k_PieceToleranceCm, f"the client's piece lies where the server's does (off by {PieceCm} cm)");
        }

        Assert_Equals_Int(_Feed.Get_Available(), 1, "the client's feed reads one available");
        Log_Feed(f"step 1: handCm={HandCm} releasePoseCm={PieceCm}");
        Await_FeedStep(2, n"OnClientStep2");
    }

    UFUNCTION()
    private void OnClientStep2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_FeedReport();
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the client's feed is idle");
        Assert_False(_Feed.Get_IsBusy(), "the client's feed is not busy");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        Assert_True(Get_IsHandAtRest(), f"the client's hand is at rest ({Describe_HandRest()})");
        Assert_True(Get_ArePhases(Get_TransferPhases()), f"the client raised one transfer's phases once each, in order ({Describe_Record()})");

        const auto HeldFrames = Get_CarryFramesAt(Report.PieceId, Report.HeldLocal, k_HeldToleranceCm, k_HeldToleranceDegrees);
        const auto WorstCm = Get_CarryWorstCm(Report.HeldLocal);
        Assert_True(HeldFrames >= k_MinCarryFrames,
            f"the client's piece rode its hand node at the server's held offset for {HeldFrames} of {_CarryHeld.Num()} carry frames (worst {WorstCm} cm)");
        Assert_Equals_Int(_CarryFaults.Num(), 0, "the client's piece never left its hand node through the carry");
        for (const auto& Fault : _CarryFaults)
        { Log_Feed(f"carry fault: {Fault}"); }

        Assert_True(_HandMaxStepCm < k_MaxHandStepCm, f"the client's hand never moved {k_MaxHandStepCm} cm in one frame (largest {_HandMaxStepCm} cm)");
        Assert_Equals_Int(_ProgressDrops, 0, "the client's phase progress never went down inside a phase");
        End_FeedClient(f"{Describe_Record()} carryFrames={_CarryHeld.Num()} heldFrames={HeldFrames} heldWorstCm={WorstCm} handMaxStepCm={_HandMaxStepCm} progressDrops={_ProgressDrops} foundFrame={_FeedFoundFrame}");
    }
}
