// The host's subject pulls the server's copy of a replicated turnip bed half way, holds, then lets go. While it holds,
// the client reads the holder AnotherMachine, keeps its target claimed and shows a stretch that follows its grip
// ledger's pull through the bed's spring without running ahead of it; after the let-go the holder is Nobody, the
// stretch unset, the claim gone and the release Ended.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_TheClientsBedShowsTheHostsStretch
class UCk_AutoTest_Net_ScreamingTurnip_TheClientsBedShowsTheHostsStretch : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(403000.0, 0.0, 5000.0);
    private const float32 k_PullTo = 0.5f;
    private const float32 k_ComposeSeconds = 2.0f;

    // Client: whether the grip was seen held, the first sample within tolerance of the pull and the claim at it, the
    // worst error from then on, how far the stretch ever ran past the pull, and the seconds from the grant to convergence.
    private bool _SawHeld = false;
    private bool _Converged = false;
    private bool _ClaimedWhenConverged = false;
    private float32 _WorstErrorAfterConverged = 0.0f;
    private float32 _MaxLead = 0.0f;
    private TOptional<float64> _GrantSeenAt;
    private float64 _SecondsToConverge = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BedFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientWatchedUntilReleased", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientWatchedUntilReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Holder = _Control.Get_GripHolder();
        if (Holder == EMars_Control_GripHolder::AnotherMachine)
        {
            const auto Now = float64(System::GetGameTimeInSeconds());
            if (_GrantSeenAt.IsSet() == false)
            { _GrantSeenAt = Now; }

            _SawHeld = true;
            const auto Pull = _Control.Get_GripPull();
            const auto Stretch = Get_Stretch();
            _MaxLead = Math::Max(_MaxLead, Stretch - Pull);
            const auto Error = Math::Abs(Stretch - Pull);
            if (_Converged)
            { _WorstErrorAfterConverged = Math::Max(_WorstErrorAfterConverged, Error); }
            else if (Math::Abs(Pull - k_PullTo) <= utils_control::k_PullReportQuantum && Error <= k_StretchTolerance)
            {
                _Converged = true;
                _ClaimedWhenConverged = Get_IsClaimed();
                _SecondsToConverge = Now - _GrantSeenAt.GetValue();
            }
        }

        auto Result = OutResult;
        Result.Set(_SawHeld && Holder == EMars_Control_GripHolder::Nobody);
    }

    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] TheClientsBedShowsTheHostsStretch client: converged {_Converged} after {_SecondsToConverge :.3} s, claimedWhenConverged {_ClaimedWhenConverged}, worstErrorAfterConverged {_WorstErrorAfterConverged :.3}, maxLead {_MaxLead :.3}, {Get_BedText()}");
        Assert_True(_Converged, "while the host held, the client's stretch came within 0.05 of its ledger's pull at the host's half pull");
        Assert_True(_ClaimedWhenConverged, "the client's target held the Operated claim while the host held the grip");
        Assert_True(_WorstErrorAfterConverged <= k_StretchTolerance, f"the client's stretch stayed within 0.05 of its ledger's pull (worst {_WorstErrorAfterConverged})");
        Assert_True(_MaxLead <= k_StretchTolerance, f"the client's stretch never ran past its ledger's pull by more than 0.05 (got {_MaxLead})");
        Assert_True(_Control.Get_GripHolder() == EMars_Control_GripHolder::Nobody, f"the holder is Nobody (got {_Control.Get_GripHolder() :n})");
        Assert_False(_Control.TryGet_ShownGripAlpha().IsSet(), "the client's stretch is unset");
        Assert_False(Get_IsClaimed(), "the client's claim is gone");
        Assert_True(_Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended, f"the release was Ended (got {_Control.Get_LastGripRelease() :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBed();
        WaitUntil(n"Is_BedFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnServerInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_Pull();
        WaitUntil(n"Is_Manipulating", n"OnServerGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Walk_To(k_PullTo);
        _HoldSeconds = 2.0f;
        WaitUntil(n"Is_PulledAndHeld", n"OnServerHeldHalf", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHeldHalf(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cancel_Pull();
        WaitUntil(n"Is_GripReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] TheClientsBedShowsTheHostsStretch server: {Get_BedText()}");
        Assert_True(_Control.Get_GripSerial() == 1 && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended,
            f"the host's one grip was released Ended (got serial {_Control.Get_GripSerial()}, {_Control.Get_LastGripRelease() :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
