// The client asks its own copy of a replicated turnip bed directly for an engage, an active state, a grip begun and
// crossed, a pull report and a Plucked release: every one is dropped, so neither machine's three ledgers move, the
// client raises nothing and no root is released.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_TheClientWroteNothing
class UCk_AutoTest_Net_ScreamingTurnip_TheClientWroteNothing : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(410000.0, 0.0, 5000.0);
    private const float32 k_ClientHoldSeconds = 1.0f;
    private const float32 k_ClientAfterRequestsSeconds = 1.5f;
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ReportedPull = 0.8f;

    private FString _LedgersBefore;

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
        WaitSeconds(k_ClientHoldSeconds, n"OnClientHeld");
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LedgersBefore = Get_LedgersText();
        Clear_Record();

        auto Subject = Get_SubjectEntity();
        _Control.Request_Engage(FMars_Request_Control_Engage());
        _Control.Request_SetActive(FMars_Request_Control_SetActive(EMars_Control_Activation::Active));
        _Control.Request_Grip(FMars_Request_Control_Grip(Subject, EMars_Control_GripVerb::Begin));
        _Control.Request_Grip(FMars_Request_Control_Grip(Subject, EMars_Control_GripVerb::Cross));
        _Control.Request_ReportPull(FMars_Request_Control_ReportPull(Subject, k_ReportedPull));
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Plucked));
        WaitSeconds(k_ClientAfterRequestsSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto LedgersAfter = Get_LedgersText();
        Log(f"[TurnipNetTest] TheClientWroteNothing client: before [{_LedgersBefore}], {Get_BedText()}");
        Assert_True(LedgersAfter == _LedgersBefore, f"the client's three ledgers are unchanged (before [{_LedgersBefore}], after [{LedgersAfter}])");
        Assert_True(_ReleaseReasons.Num() == 0 && _ExhaustedCount == 0 && _EngagedCount == 0 && _Activations.Num() == 0
            && _GripRefusals.Num() == 0 && _HolderChanges.Num() == 0,
            f"the client raised nothing (got released {_ReleaseReasons.Num()}, exhausted {_ExhaustedCount}, engaged {_EngagedCount}, activations {_Activations.Num()}, refusals {_GripRefusals.Num()}, holder [{Get_HolderChangesText()}])");
        Assert_True(Count_RootsNearBed() == 0, f"no root is near the client's bed (got {Count_RootsNearBed()})");
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
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] TheClientWroteNothing server: {Get_BedText()}");
        Assert_True(Get_Engagements() == 0 && _Control.Get_IsActive() == false, f"nothing engaged (got {Get_Engagements()}, active {_Control.Get_IsActive()})");
        Assert_True(_Control.Get_GripSerial() == 0 && _Control.Get_RefusalSerial() == 0,
            f"no grip was granted or refused (got {_Control.Get_GripSerial()}, {_Control.Get_RefusalSerial()})");
        Assert_True(_Forage.Get_ReleasedCount() == 0 && _Forage.Get_ChargesLeft() == 1,
            f"nothing was released (got {_Forage.Get_ReleasedCount()}, charges {_Forage.Get_ChargesLeft()})");
        Assert_True(Count_RootsNearBed() == 0, f"no root is near the server's bed (got {Count_RootsNearBed()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
