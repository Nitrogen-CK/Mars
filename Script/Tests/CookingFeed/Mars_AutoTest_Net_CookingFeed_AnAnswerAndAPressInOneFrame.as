// The server sources its feed and presses add food; at AwaitAdmission, in one frame, it answers Accepted and presses again.
// The press is refused Busy (the hand is returning); it reports at Idle. On the client one is admitted, it raised the
// refusal once, Busy, the feed is idle with one available and its hand is at rest.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_AnAnswerAndAPressInOneFrame
class UCk_AutoTest_Net_CookingFeed_AnAnswerAndAPressInOneFrame : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 275000.0;

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
        Answer(EMars_CookingFeed_Admission::Accepted);
        Begin_Transfer();
        Await_Phase(EMars_CookingFeed_Phase::Idle, n"OnServerIdle");
    }

    UFUNCTION()
    private void OnServerIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_FeedStep(Make_FeedStep(1));
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::Busy, f"the server refused the press Busy ({Describe_Record()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the server admitted one");
        End_FeedServer(f"{Describe_Record()} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::Busy, f"the client raised one refusal, Busy ({Describe_Record()})");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the client's feed is idle");
        Assert_Equals_Int(_Feed.Get_Available(), 1, "the client's feed reads one available");
        Assert_True(Get_IsHandAtRest(), f"the client's hand is at rest ({Describe_HandRest()})");
        End_FeedClient(f"{Describe_Record()} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }
}
