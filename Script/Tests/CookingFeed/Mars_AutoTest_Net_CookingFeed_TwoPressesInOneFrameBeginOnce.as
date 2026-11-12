// The server sources its feed and presses add food twice in one frame, answers the release Accepted and reports at Idle:
// it refused one press Busy and settled one transfer Admitted. The client raised the refusal exactly once, Busy, its ledger
// counts one refusal, it raised one transfer's phases (Reach once, Idle last), and one is admitted.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_TwoPressesInOneFrameBeginOnce
class UCk_AutoTest_Net_CookingFeed_TwoPressesInOneFrameBeginOnce : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 274000.0;

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
        Begin_Transfer();
        Await_Phase(EMars_CookingFeed_Phase::AwaitAdmission, n"OnServerAwaiting");
    }

    UFUNCTION()
    private void OnServerAwaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Answer(EMars_CookingFeed_Admission::Accepted);
        Await_Phase(EMars_CookingFeed_Phase::Idle, n"OnServerIdle");
    }

    UFUNCTION()
    private void OnServerIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_FeedStep(Make_FeedStep(1));
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::Busy, f"the server refused one press Busy ({Describe_Record()})");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Admitted, "the server settled one transfer Admitted");
        End_FeedServer(f"{Describe_Record()} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Feed.Get_Ledger();
        Assert_True(_Refusals.Num() == 1 && _Refusals[0] == EMars_CookingFeed_Refusal::Busy, f"the client raised one refusal, Busy ({Describe_Record()})");
        Assert_Equals_Int(Ledger.RefusalSerial, 1, "the client's ledger counts one refusal");
        Assert_True(Get_PhaseCount(EMars_CookingFeed_Phase::Reach) == 1 && _Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle,
            f"the client raised one transfer's phases: Reach once, Idle last ({Describe_Record()})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        End_FeedClient(f"{Describe_Record()} ledger [{Describe_Ledger(Ledger)}]");
    }
}
