// The platter is frozen first; then the station. In the continuation in which the server first finds its feed it sources
// it and presses add food twice (one refused Busy), holds at AwaitAdmission 4 s, answers Accepted and reports at Idle. The
// client starts counting what its copy raises only once its ledger reads one refusal and AwaitAdmission (a listener that
// arrives after them): its hand is then at the release pose, and from then on it raises Return then Idle once each, no
// refusal and no piece let go, and one is admitted.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_CookingFeed_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 277000.0;
    private const float32 k_ServerHoldAtAwaitSeconds = 4.0f;
    private const float64 k_ReleasePoseToleranceCm = 0.5;
    // Frames the client lets its tick pose the hand after its ledger reads AwaitAdmission.
    private const int32 k_PoseFrames = 5;

    private float64 _ReleasePoseCm = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FeedRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientLedgerAwaiting", n"OnClientLedgerAwaiting", k_SlowPolls); }
    }

    protected void On_ServerFeedFound() override
    {
        _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(_Platter));
        Begin_Transfer();
        Begin_Transfer();
        Await_Phase(EMars_CookingFeed_Phase::AwaitAdmission, n"OnServerAwaiting");
    }

    UFUNCTION()
    private void OnServerAwaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldAtAwaitSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Answer(EMars_CookingFeed_Admission::Accepted);
        Await_Phase(EMars_CookingFeed_Phase::Idle, n"OnServerIdle");
    }

    UFUNCTION()
    private void OnServerIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_FeedStep(Make_FeedStep(1));
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::Busy, f"the server refused one press Busy ({Describe_Record()})");
        End_FeedServer(f"{Describe_Record()} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }

    UFUNCTION()
    private void Is_ClientLedgerAwaiting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Try_FindFeed() == false)
        {
            Result.Set(false);
            return;
        }

        const auto Ledger = _Feed.Get_Ledger();
        Result.Set(Ledger.RefusalSerial == 1 && Ledger.Phase == EMars_CookingFeed_Phase::AwaitAdmission);
    }

    // The listener arrives now: what its copy raised before is not its to count.
    UFUNCTION()
    private void OnClientLedgerAwaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Feed(f"before the clear: {Describe_Record()} foundFrame={_FeedFoundFrame} now={utils_time::Get_FrameCounter()}");
        Clear_FeedRecord();
        WaitFrames(k_PoseFrames, n"OnClientPosed");
    }

    UFUNCTION()
    private void OnClientPosed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ReleasePoseCm = Get_HandOffset().GetLocation().Distance(constants_cooking_feed_net_autotest::k_ReleaseLocal);
        Assert_True(_ReleasePoseCm <= k_ReleasePoseToleranceCm, f"the client's hand is at the release pose (off by {_ReleasePoseCm} cm)");
        Await_FeedStep(1, n"OnClientStep1");
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TArray<EMars_CookingFeed_Phase> Expected;
        Expected.Add(EMars_CookingFeed_Phase::Return);
        Expected.Add(EMars_CookingFeed_Phase::Idle);
        Assert_True(Get_ArePhases(Expected), f"the client raised Return then Idle once each since it started counting ({Describe_Record()})");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetFeedEvent::TransferRefused), 0, "the client raised no earlier refusal again");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetFeedEvent::PieceLetGo), 0, "the client raised no piece let go");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        End_FeedClient(f"{Describe_Record()} releasePoseCm={_ReleasePoseCm} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }
}
