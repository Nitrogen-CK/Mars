// The platter is frozen first; then a station that, as it composes, sources its feed from the platter and presses add
// food twice: its drain begins a reach and refuses the second press Busy in the spawn frame. The server asks nothing
// more: it holds at AwaitAdmission 4 s, answers Accepted and reports at Idle. The client's copy is born into the reach
// and the refusal: it raises no refusal and no piece let go, announces the reach once in the frame it takes that state,
// never shows the reach from its start, raises each later phase once, its hand reaches the release pose and one is
// admitted.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_CookingFeed_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;
    default _StationKind = EMars_TESTONLY_NetFeedStationKind::Born;

    private const float64 k_X = 277000.0;
    private const float32 k_ServerHoldAtAwaitSeconds = 4.0f;
    private const float64 k_ReleasePoseToleranceCm = 0.5;
    // Frames the client lets its tick pose the hand after its ledger reads AwaitAdmission.
    private const int32 k_PoseFrames = 5;
    // A phase the copy was born into is shown finished.
    private const float32 k_FinishedProgress = 0.999f;

    private float64 _ReleasePoseCm = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _StationKind = EMars_TESTONLY_NetFeedStationKind::Born;
        Begin_FeedRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientLedgerAwaiting", n"OnClientLedgerAwaiting", k_SlowPolls); }
    }

    // The server's rig bound its listeners after the spawn frame's drain: the refusal is read from the ledger.
    protected void On_ServerFeedFound() override
    {
        const auto Ledger = _Feed.Get_Ledger();
        Assert_True(Ledger.RefusalSerial == 1 && Ledger.LastRefusal == EMars_CookingFeed_Refusal::Busy,
            f"the server found its feed with one press refused Busy ({Describe_Ledger(Ledger)})");
        Log_Feed(f"found ledger [{Describe_Ledger(Ledger)}]");
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
        const auto Ledger = _Feed.Get_Ledger();
        Assert_True(Ledger.RefusalSerial == 1 && Ledger.LastRefusal == EMars_CookingFeed_Refusal::Busy,
            f"the server's ledger counts one press refused Busy ({Describe_Ledger(Ledger)})");
        End_FeedServer(f"{Describe_Record()} ledger [{Describe_Ledger(Ledger)}]");
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

    UFUNCTION()
    private void OnClientLedgerAwaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_PoseFrames, n"OnClientPosed");
    }

    UFUNCTION()
    private void OnClientPosed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ReleasePoseCm = Get_HandOffset().GetLocation().Distance(constants_cooking_feed_net_autotest::k_ReleaseLocal);
        Assert_True(_ReleasePoseCm <= k_ReleasePoseToleranceCm, f"the client's hand is at the release pose (off by {_ReleasePoseCm} cm)");
        Await_FeedStep(1, n"OnClientStep1");
    }

    // Each count raised = what the ledger counts now less what the first notify carried.
    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Feed.Get_Ledger();
        const auto First = Get_FirstNotifyLedger();
        const auto FirstFrame = Get_FirstNotifyFrame();
        const auto FirstPhaseFrame = _PhaseFrames.Num() > 0 ? _PhaseFrames[0] : int64(-1);

        Assert_True(Get_FeedInitialState() == EMars_Net_InitialState::Taken, "the client's copy took the state it was born into");
        Assert_True(_InitialAtFind == EMars_Net_InitialState::Awaited, "the client found its copy before its ledger's first application");
        Assert_True(Get_HasFirstNotify(), "the client recorded a rep-notify of its copy's ledger");
        Assert_True(First.Phase == EMars_CookingFeed_Phase::Reach && First.RefusalSerial == 1,
            f"the first notify carried the reach and the refusal the station was born into ({Describe_Ledger(First)})");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetFeedEvent::TransferRefused), Ledger.RefusalSerial - First.RefusalSerial,
            "the client raised only the refusals after its first notify");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetFeedEvent::PieceLetGo), 0, "the client raised no piece let go");
        Assert_True(Get_ArePhases(Get_TransferPhases()), f"the client raised each phase of the transfer once ({Describe_Record()})");
        Assert_True(FirstPhaseFrame == FirstFrame, f"the client announced the phase it was born into in its first notify's frame ({FirstPhaseFrame} vs {FirstFrame})");
        Assert_True(_LowestFirstPhaseProgress >= k_FinishedProgress,
            f"the client showed the phase it was born into finished (lowest progress {_LowestFirstPhaseProgress})");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the client's feed reads one admitted");
        End_FeedClient(f"{Describe_Record()} releasePoseCm={_ReleasePoseCm} first [{Describe_Ledger(First)}] ledger [{Describe_Ledger(Ledger)}]");
    }
}
