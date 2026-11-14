// The client pulls its copy of a replicated turnip bed half way, holds, then lets go: its interaction ends Failed, its
// target stays available and nothing is released; the server granted one grip, released it Ended and never engaged.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_APullLetGoEarlyReleasesNothing
class UCk_AutoTest_Net_ScreamingTurnip_APullLetGoEarlyReleasesNothing : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(401000.0, 0.0, 5000.0);
    private const float32 k_PullTo = 0.5f;
    private const float32 k_ClientAfterCancelSeconds = 1.5f;
    private const float32 k_ServerWatchSeconds = 5.0f;

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
        _HoldSeconds = 0.5f;
        WaitUntil(n"Is_PulledAndHeld", n"OnClientHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cancel_Pull();
        WaitSeconds(k_ClientAfterCancelSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Result = _FinishedResults.Num() > 0 ? _FinishedResults[0] : ECk_SucceededFailed::Succeeded;
        Log(f"[TurnipNetTest] APullLetGoEarlyReleasesNothing client: finished {Result :n}, {Get_BedText()}");
        Assert_True(_FinishedResults.Num() == 1 && Result == ECk_SucceededFailed::Failed,
            f"the client's interaction ended Failed once (got {_FinishedResults.Num()}, {Result :n})");
        Assert_True(Get_IsTargetEnabled(), "the client's target is available");
        Assert_True(_Forage.Get_ChargesLeft() == 1, f"the client's bed holds its one charge (got {_Forage.Get_ChargesLeft()})");
        Assert_True(_ReleaseReasons.Num() == 0, f"the client raised no OnReleased (got {_ReleaseReasons.Num()})");
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
        Log(f"[TurnipNetTest] APullLetGoEarlyReleasesNothing server: {Get_BedText()}");
        Assert_True(_Forage.Get_ReleasedCount() == 0 && _Forage.Get_ChargesLeft() == 1,
            f"the server released nothing and holds one charge (got {_Forage.Get_ReleasedCount()}, {_Forage.Get_ChargesLeft()})");
        Assert_True(_Control.Get_GripSerial() == 1, f"one grip was granted (got {_Control.Get_GripSerial()})");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended,
            f"the grip was released Ended (got {_Control.Get_LastGripRelease() :n})");
        Assert_True(Get_Engagements() == 0, f"nothing engaged (got {Get_Engagements()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
