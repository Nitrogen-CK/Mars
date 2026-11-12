// The station ends its construction in its spawn frame and its authority composes the feed from a tick a frame later, as a
// replicating real station composes its feed once its docks have; a machine without authority composes it at once. Once
// the server's feed exists it sources it (step 1), presses add food, holds a second at AwaitAdmission, answers the
// release Accepted and reports at Idle (step 2). The client's copy composed its own feed at once; at step 1 its ledger reads sourced with two available, at
// step 2 one admitted, and it raised the server's phases in the server's order.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_AFeedComposedAfterItsStationWasBuiltMirrors
class UCk_AutoTest_Net_CookingFeed_AFeedComposedAfterItsStationWasBuiltMirrors : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 290000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _StationKind = EMars_TESTONLY_NetFeedStationKind::Late;
        Begin_FeedRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_FeedStep(1, n"OnClientStep1"); }
    }

    protected void On_ServerFeedFound() override
    {
        Log_Feed(f"the server's feed found at frame {_FeedFoundFrame}");
        Source_AfterBind();
    }

    protected void On_ServerSourced() override
    {
        Publish_FeedStep(Make_FeedStep(1));
        WaitSeconds(k_StepSeconds, n"OnServerBegin");
    }

    UFUNCTION()
    private void OnServerBegin(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_Transfer();
        Await_Phase(EMars_CookingFeed_Phase::AwaitAdmission, n"OnServerAwaiting");
    }

    UFUNCTION()
    private void OnServerAwaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnServerAnswer");
    }

    // Held a beat at AwaitAdmission, so the phase reaches the client before the answer moves it on.
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
        End_FeedServer(f"{Describe_Record()} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Feed.Get_Ledger();
        FCk_Handle Entity = _Feed;
        Log_Feed(f"step 1: the client's feed found at frame {_FeedFoundFrame}, ledger fragment {Entity.Has_Fragment(FMars_Fragment_CookingFeed_Net)} [{Describe_Ledger(Ledger)}]");
        Assert_True(Ledger.Sourcing == EMars_CookingFeed_Sourcing::Sourced, "the client's ledger reads sourced");
        Assert_Equals_Int(Ledger.Available, 2, "the client's ledger reads two available");
        Await_FeedStep(2, n"OnClientStep2");
    }

    UFUNCTION()
    private void OnClientStep2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Feed.Get_Ledger();
        Assert_Equals_Int(Ledger.Admitted, 1, "the client's ledger reads one admitted");
        Assert_True(Get_ArePhases(Get_TransferPhases()), f"the client raised the server's phases in order ({Describe_Record()})");
        End_FeedClient(f"{Describe_Record()} ledger [{Describe_Ledger(Ledger)}]");
    }
}
