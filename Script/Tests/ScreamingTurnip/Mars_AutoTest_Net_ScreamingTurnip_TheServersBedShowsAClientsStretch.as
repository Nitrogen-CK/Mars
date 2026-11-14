// The client pulls its copy of a replicated turnip bed half way, holds, then lets go. The server's bed, which has no
// Mover, shows the client's stretch from its grip ledger's pull, holds the Operated claim while the client holds the
// grip and raises OnGripHolderChanged to and from AnotherMachine once each; the client raises it to and from ThisMachine
// once each and its own target is never claimed.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_TheServersBedShowsAClientsStretch
class UCk_AutoTest_Net_ScreamingTurnip_TheServersBedShowsAClientsStretch : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(402000.0, 0.0, 5000.0);
    private const float32 k_PullTo = 0.5f;
    // How close the ledger's pull must come to where the client pulled.
    private const float32 k_LedgerTolerance = 0.02f;

    // Server: whether a sample while held met both tolerances, the claim at that sample, the worst stretch error from
    // then on, and the seconds from the grant to that sample.
    private bool _Converged = false;
    private bool _ClaimedWhenConverged = false;
    private float32 _WorstErrorAfterConverged = 0.0f;
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
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_Pull();
        WaitUntil(n"Is_Manipulating", n"OnClientGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Walk_To(k_PullTo);
        _HoldSeconds = 2.0f;
        WaitUntil(n"Is_PulledAndHeld", n"OnClientHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cancel_Pull();
        WaitUntil(n"Is_ClientReleaseMirrored", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReleaseMirrored(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _EverClaimed = _EverClaimed || Get_IsClaimed();

        auto Result = OutResult;
        Result.Set(_Control.Get_GripSerial() >= 1 && _Control.Get_IsGripped() == false);
    }

    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EverClaimed = _EverClaimed || Get_IsClaimed();
        Log(f"[TurnipNetTest] TheServersBedShowsAClientsStretch client: everClaimed {_EverClaimed}, {Get_BedText()}");
        Assert_True(Count_HolderChanges(EMars_Control_GripHolder::Nobody, EMars_Control_GripHolder::ThisMachine) == 1
            && Count_HolderChanges(EMars_Control_GripHolder::ThisMachine, EMars_Control_GripHolder::Nobody) == 1 && _HolderChanges.Num() == 2,
            f"the client raised OnGripHolderChanged Nobody to ThisMachine and back once each (got [{Get_HolderChangesText()}])");
        Assert_False(_EverClaimed, "the client's own target never held the Operated claim");
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
        WaitUntil(n"Is_ServerSampledUntilReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSampledUntilReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Control.Get_GripHolder() == EMars_Control_GripHolder::AnotherMachine)
        {
            const auto Now = float64(System::GetGameTimeInSeconds());
            if (_GrantSeenAt.IsSet() == false)
            { _GrantSeenAt = Now; }

            const auto Pull = _Control.Get_GripPull();
            const auto Error = Math::Abs(Get_Stretch() - Pull);
            if (_Converged)
            { _WorstErrorAfterConverged = Math::Max(_WorstErrorAfterConverged, Error); }
            else if (Math::Abs(Pull - k_PullTo) <= k_LedgerTolerance && Error <= k_StretchTolerance)
            {
                _Converged = true;
                _ClaimedWhenConverged = Get_IsClaimed();
                _SecondsToConverge = Now - _GrantSeenAt.GetValue();
            }
        }

        auto Result = OutResult;
        Result.Set(_Control.Get_GripSerial() >= 1 && _Control.Get_IsGripped() == false);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] TheServersBedShowsAClientsStretch server: converged {_Converged} after {_SecondsToConverge :.3} s, claimedWhenConverged {_ClaimedWhenConverged}, worstErrorAfterConverged {_WorstErrorAfterConverged :.3}, {Get_BedText()}");
        Assert_True(Count_HolderChanges(EMars_Control_GripHolder::Nobody, EMars_Control_GripHolder::AnotherMachine) == 1,
            f"the server raised OnGripHolderChanged Nobody to AnotherMachine once (got [{Get_HolderChangesText()}])");
        Assert_True(_Converged, "while held, the server's stretch came within 0.05 of its ledger's pull, and that pull within 0.02 of 0.5");
        Assert_True(_ClaimedWhenConverged, "the server's target held the Operated claim while the client held the grip");
        Assert_True(Count_HolderChanges(EMars_Control_GripHolder::AnotherMachine, EMars_Control_GripHolder::Nobody) == 1 && _HolderChanges.Num() == 2,
            f"after the release the server raised AnotherMachine to Nobody once (got [{Get_HolderChangesText()}])");
        Assert_False(Get_IsClaimed(), "the server's claim is gone");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
