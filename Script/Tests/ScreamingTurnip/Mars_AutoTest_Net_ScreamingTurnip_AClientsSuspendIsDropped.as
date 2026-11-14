// A client asks its copy of a breathing root to Suspend: the copy drops the request and keeps showing the authority's
// Inhale, raising nothing, its ledger untouched. When the server suspends its own root, the copy follows the authority
// on to a fresh Anticipate; no scream is committed anywhere.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_AClientsSuspendIsDropped
class UCk_AutoTest_Net_ScreamingTurnip_AClientsSuspendIsDropped : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(603000.0, 0.0, 5000.0);
    private const float32 k_ServerBeforeSuspendSeconds = 3.0f;
    private const float32 k_ServerAfterSuspendSeconds = 3.0f;
    private const float32 k_ClientAfterRequestSeconds = 1.5f;

    // The recorded entry into the Inhale, and how many phase entries stood when the server suspended.
    private int32 _InhaleEntry = -1;
    private int32 _PhasesAtSuspend = -1;
    private int32 _SignalsAtRequest = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);
        Expect_Root(FVector::ZeroVector);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_Inhale", n"OnClientInhale", k_SlowPolls);
            return;
        }

        Spawn_ServerTurnipFloor();
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Inhale(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootPhase(0, EMars_ScreamingTurnip_Phase::Inhale));
    }

    UFUNCTION()
    private void Is_AnticipateAfterTheInhale(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootGone(0) == false && Find_PhaseEntry(0, EMars_ScreamingTurnip_Phase::Anticipate, _InhaleEntry + 1) > _InhaleEntry);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerRoot(0, Make_LongInhaleVocal());
        WaitUntil(n"Is_Inhale", n"OnServerInhale", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInhale(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _InhaleEntry = Find_PhaseEntry(0, EMars_ScreamingTurnip_Phase::Inhale, 0);
        WaitSeconds(k_ServerBeforeSuspendSeconds, n"OnServerSuspend");
    }

    UFUNCTION()
    private void OnServerSuspend(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PhasesAtSuspend = _Roots[0].Phases.Num();
        auto Turnip = _Roots[0].Turnip;
        Turnip.Request_Suspend(FMars_Request_ScreamingTurnip_Suspend());
        WaitSeconds(k_ServerAfterSuspendSeconds, n"OnServerSuspended");
    }

    UFUNCTION()
    private void OnServerSuspended(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] AClientsSuspendIsDropped server: inhaleEntry {_InhaleEntry}, phasesAtSuspend {_PhasesAtSuspend}, {Get_RootText(0)}";
        Log(Line);
        const auto& Phases = _Roots[0].Phases;
        Assert_True(_InhaleEntry >= 0 && _PhasesAtSuspend == _InhaleEntry + 1, "before its own Suspend no phase followed the server's Inhale");
        Assert_True(_PhasesAtSuspend >= 0 && _PhasesAtSuspend + 1 < Phases.Num() && Phases[_PhasesAtSuspend].New == EMars_ScreamingTurnip_Phase::Dormant
            && Phases[_PhasesAtSuspend + 1].New == EMars_ScreamingTurnip_Phase::Anticipate, "after its Suspend the server recorded Dormant, then Anticipate");
        Assert_Equals_Int(_Roots[0].Turnip.Get_ScreamSequence(), 0, "the server committed no scream");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the server (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientInhale(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _InhaleEntry = Find_PhaseEntry(0, EMars_ScreamingTurnip_Phase::Inhale, 0);
        _SignalsAtRequest = Get_SignalCount(0);
        auto Turnip = _Roots[0].Turnip;
        Turnip.Request_Suspend(FMars_Request_ScreamingTurnip_Suspend());
        WaitSeconds(k_ClientAfterRequestSeconds, n"OnClientRequested");
    }

    UFUNCTION()
    private void OnClientRequested(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRootGone(0))
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Line = f"[TurnipNetTest] AClientsSuspendIsDropped client after its request: inhaleEntry {_InhaleEntry}, {Get_RootText(0)}";
        Log(Line);
        auto Turnip = _Roots[0].Turnip;
        const auto Ledger = TryGet_Ledger(0);
        Assert_True(Turnip.Get_Phase() == EMars_ScreamingTurnip_Phase::Inhale, f"the client's copy still reads Inhale (got {Turnip.Get_Phase() :n})");
        Assert_False(Turnip.Has_Fragment(FMars_Fragment_ScreamingTurnip_Requests), "no request is left on the client's copy");
        Assert_Equals_Int(Get_SignalCount(0), _SignalsAtRequest, "the client's copy raised no signal since the request");
        Assert_True(Ledger.IsSet() && Ledger.GetValue().Placement == EMars_ScreamingTurnip_Placement::LooseSettled
            && Ledger.GetValue().Phase == EMars_ScreamingTurnip_Phase::Inhale && Ledger.GetValue().Support == EMars_ScreamingTurnip_Support::Supported
            && Ledger.GetValue().ScreamSequence == 0, "the client's ledger reads LooseSettled, Inhale, Supported, 0");
        WaitUntil(n"Is_AnticipateAfterTheInhale", n"OnClientAnticipate", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAnticipate(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] AClientsSuspendIsDropped client after the server's Suspend: {Get_RootText(0)}";
        Log(Line);
        Assert_Equals_Int(_Roots[0].Turnip.Get_ScreamSequence(), 0, "the client's copy reads sequence 0");
        Assert_Equals_Int(_Roots[0].Screams.Num(), 0, "the client recorded no scream");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired on the client (got {Get_NewEnsures()})");
        FinishSuccess();
    }
}
