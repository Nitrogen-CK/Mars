// A stand-in holds the grip on a replicated turnip bed; the client then grips its copy through an interaction. The
// authority refuses it: the client raises OnGripRefused once naming the subject, its interaction ends Failed and its
// grip ends. The stand-in's crossing engages the bed once and releases its one root; the client's late Cross for
// itself changes nothing, so the bed reads one release on both machines.
// The client's copy stops watching its interactable once it sees the stand-in's grip, as a client whose claim raced the
// stand-in's grant does: a watched one would hold the Operated claim and the client could not start the interaction.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_ASecondPullerIsRefusedAndTheChargeIsSpentOnce
class UCk_AutoTest_Net_ScreamingTurnip_ASecondPullerIsRefusedAndTheChargeIsSpentOnce : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(404000.0, 0.0, 5000.0);
    private const float32 k_ComposeSeconds = 2.0f;
    private const float32 k_ClientAfterCrossSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BedAndStandInFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_GrippedByStandIn", n"OnClientSawStandIn", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawStandIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Unwatch_Interactable();
        WaitUntil(n"Is_GrippedByStandInUnclaimed", n"OnClientUnclaimed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientUnclaimed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_Pull();
        WaitUntil(n"Is_RefusedAndLetGo", n"OnClientLetGo", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RefusedAndLetGo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_GripRefusals.Num() > 0 && _FinishedResults.Num() > 0 && _Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void OnClientLetGo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Refused = _GripRefusals.Num() > 0 ? _GripRefusals[0] : FCk_Handle();
        const auto Result = _FinishedResults.Num() > 0 ? _FinishedResults[0] : ECk_SucceededFailed::Succeeded;
        Assert_True(_GripRefusals.Num() == 1 && Refused == Get_SubjectEntity(),
            f"OnGripRefused fired once, naming the subject (got {_GripRefusals.Num()}, {Get_WhoText(Refused)})");
        Assert_True(_FinishedResults.Num() == 1 && Result == ECk_SucceededFailed::Failed,
            f"the client's interaction ended Failed once (got {_FinishedResults.Num()}, {Result :n})");
        Assert_False(_Control.Get_IsManipulating(), "the client's grip ended");
        WaitUntil(n"Is_EngagedOnce", n"OnClientSawCross", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawCross(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Fire_GripCue(Get_SubjectEntity(), EMars_Control_GripVerb::Cross);
        WaitSeconds(k_ClientAfterCrossSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] ASecondPullerIsRefusedAndTheChargeIsSpentOnce client: {Get_BedText()}");
        Assert_True(_Forage.Get_ReleasedCount() == 1, f"the client's bed reads one release (got {_Forage.Get_ReleasedCount()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerBed();
        WaitUntil(n"Is_BedAndStandInFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        WaitUntil(n"Is_Refused", n"OnServerRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Cross);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] ASecondPullerIsRefusedAndTheChargeIsSpentOnce server: {Get_BedText()}");
        Assert_True(_Forage.Get_ReleasedCount() == 1, f"the server released one root (got {_Forage.Get_ReleasedCount()})");
        Assert_True(Get_Engagements() == 1, f"the bed's Control engaged once (got {Get_Engagements()})");
        Assert_True(_Control.Get_RefusalSerial() == 1, f"one claim was refused (got {_Control.Get_RefusalSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
