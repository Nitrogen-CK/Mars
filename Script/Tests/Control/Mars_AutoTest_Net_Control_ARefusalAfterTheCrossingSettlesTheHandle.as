// A stand-in holds the grip on the server. The client grips its copy of a stiff, low-threshold lever and pulls it fully in
// the same frame it asks for the grip, so it crosses before the refusal can come back: the refusal, when it is mirrored,
// finds the pending engage already cleared, well inside k_PendingEngageSeconds of the crossing, the handle settles back
// to rest, and nothing engages anywhere. A pending engage can live for less than a frame here, so the crossing and the
// refusal are read from their signals, not by polling.
// Surface: Ck.Control.Net.AS_Control_ARefusalAfterTheCrossingSettlesTheHandle
class UCk_AutoTest_Net_Control_ARefusalAfterTheCrossingSettlesTheHandle : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(133000.0, 0.0, 5000.0);
    // Enough pull, at AlphaPerDegree 0.02, to ask for the full travel in one drain.
    private const float32 k_FullPullDegrees = 60.0f;
    private const float32 k_ServerWindowSeconds = 4.0f;

    private bool _Crossed = false;
    private int32 _RefusalsAtCrossing = -1;
    private float64 _CrossedAtSeconds = 0.0;
    private bool _PendingAtRefusal = true;
    private float64 _RefusedAfterCrossingSeconds = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_LeverFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.BindTo_OnManipulationChanged(FMars_Delegate_Control_OnManipulationChanged(this, n"OnClientGripChanged"));
        _Control.BindTo_OnGripRefused(FMars_Delegate_Control_OnGripRefused(this, n"OnClientRefused"));
        WaitUntil(n"Is_GrippedByStandIn", n"OnClientSawStandIn", k_SlowPolls);
    }

    // The threshold ends the grip (Released) before it arms the pending engage, in the same tick.
    UFUNCTION()
    private void OnClientGripChanged(FCk_Handle_Control InControl, EMars_Control_Grip InGrip)
    {
        if (InGrip != EMars_Control_Grip::Released || _Crossed)
        { return; }

        _Crossed = true;
        _RefusalsAtCrossing = _GripRefusals.Num();
        _CrossedAtSeconds = System::GetGameTimeInSeconds();
    }

    // Raised after the refused machine let go: the pending engage is already cleared here.
    UFUNCTION()
    private void OnClientRefused(FCk_Handle_Control InControl, FCk_Handle InRefused)
    {
        _PendingAtRefusal = Get_HasPendingEngage();
        if (_Crossed)
        { _RefusedAfterCrossingSeconds = System::GetGameTimeInSeconds() - _CrossedAtSeconds; }
    }

    UFUNCTION()
    private void OnClientSawStandIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteracting", k_SlowPolls);
    }

    // The grip and the full pull drain together: the tick of that frame crosses the threshold.
    UFUNCTION()
    private void OnClientInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        _Control.Request_Nudge(FMars_Request_Control_Nudge(k_FullPullDegrees));
        WaitUntil(n"Is_Refused", n"OnClientRefusalSeen", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRefusalSeen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_HandleAtRest", n"OnClientAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Result = _FinishedResults.Num() > 0 ? _FinishedResults[0] : ECk_SucceededFailed::Failed;
        Log(f"[ControlNetTest] ARefusalAfterTheCrossingSettlesTheHandle client: crossed {_Crossed}, refusalsAtCrossing {_RefusalsAtCrossing}, finished {_FinishedResults.Num()} first {Result :n}, pendingAtRefusal {_PendingAtRefusal}, refusedAfterCrossing {_RefusedAfterCrossingSeconds}s, refusalsRaised {_GripRefusals.Num()}, pending {Get_HasPendingEngage()}, mover {_Mover.Get_Alpha()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_Crossed && _RefusalsAtCrossing == 0, f"the client crossed the threshold before the refusal was mirrored (got crossed {_Crossed}, refusals then {_RefusalsAtCrossing})");
        Assert_True(_FinishedResults.Num() == 1 && Result == ECk_SucceededFailed::Succeeded,
            f"the crossing ended the interaction Succeeded, so its engage was sent (got {_FinishedResults.Num()}, {Result :n})");
        Assert_False(_PendingAtRefusal, "the refusal cleared the pending engage");
        Assert_True(_RefusedAfterCrossingSeconds >= 0.0 && _RefusedAfterCrossingSeconds < utils_control::k_PendingEngageSeconds * 0.5f,
            f"the refusal came well inside k_PendingEngageSeconds of the crossing (got {_RefusedAfterCrossingSeconds}s)");
        Assert_True(_GripRefusals.Num() == 1, f"OnGripRefused fired once (got {_GripRefusals.Num()})");
        Assert_False(Get_HasPendingEngage(), "no pending engage stands");
        Assert_True(_Mover.Get_Alpha() < 0.01f, f"the client's handle is at rest (got {_Mover.Get_Alpha()})");
        Assert_True(Get_Engagements() == 0 && _EngagedCount == 0, f"nothing engaged (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerQuickLever(k_Location);
        WaitUntil(n"Is_LeverAndStandInFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_LeverAndStandInFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsControlFound(n"TAG_MarsLever") && Get_IsStandInFound());
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        WaitUntil(n"Is_Refused", n"OnServerRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWindowSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ARefusalAfterTheCrossingSettlesTheHandle server: engagements {Get_Engagements()}, onEngaged {_EngagedCount}, active {_Control.Get_IsActive()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(Get_Engagements() == 0 && _EngagedCount == 0, f"the refused pull's engage was dropped (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Control.Get_Gripper() == _StandIn && _Control.Get_RefusalSerial() == 1,
            f"the stand-in still holds the grip and the subject was refused once (got {Get_WhoText(_Control.Get_Gripper())}, {_Control.Get_RefusalSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
