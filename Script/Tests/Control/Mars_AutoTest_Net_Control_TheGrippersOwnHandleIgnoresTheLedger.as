// The client grips a replicated lever and pulls it slowly to about half, reporting its pull, then holds and lets go. The
// ledger's Pull lags the client's own, and it never moves the client's handle: in every frame the client's Mover shows its
// own spring's alpha (this frame's or the last), and the client never shows a mirrored grip.
// Surface: Ck.Control.Net.AS_Control_TheGrippersOwnHandleIgnoresTheLedger
class UCk_AutoTest_Net_Control_TheGrippersOwnHandleIgnoresTheLedger : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(143000.0, 0.0, 5000.0);
    private const float32 k_SlowNudgeDegrees = 0.5f;
    private const float32 k_HoldSeconds = 1.0f;

    private float32 _HeldSeconds = 0.0f;
    private int32 _Frames = 0;
    private int32 _MirroredFrames = 0;
    private int32 _LaggingFrames = 0;
    private float32 _MaxMoverGap = 0.0f;
    private TOptional<float32> _PreviousOwnAlpha;

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
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        WaitUntil(n"Is_GrippedBySubject", n"OnClientGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Get_FrameSeconds();
        WaitUntil(n"Is_ClientPulledAndHeld", n"OnClientHeld", k_SlowPolls);
    }

    // Client, every frame: the Mover against the own spring, then a slow nudge toward half and a report.
    UFUNCTION()
    private void Is_ClientPulledAndHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Seconds = Get_FrameSeconds();
        const auto OwnAlpha = _Control.TryGet_ManipulationAlpha();
        const auto Pull = _Control.TryGet_ManipulationPull();
        auto Result = OutResult;
        if (OwnAlpha.IsSet() == false || Pull.IsSet() == false)
        {
            Result.Set(true);
            return;
        }

        _Frames += 1;
        if (_Control.TryGet_MirroredGripAlpha().IsSet())
        { _MirroredFrames += 1; }

        if (Math::Abs(_Control.Get_GripPull() - Pull.GetValue()) > utils_control::k_PullReportQuantum)
        { _LaggingFrames += 1; }

        // The Mover shows a scrub in the frame it is asked or the next.
        auto Gap = Math::Abs(_Mover.Get_Alpha() - OwnAlpha.GetValue());
        if (_PreviousOwnAlpha.IsSet())
        { Gap = Math::Min(Gap, Math::Abs(_Mover.Get_Alpha() - _PreviousOwnAlpha.GetValue())); }

        _MaxMoverGap = Math::Max(_MaxMoverGap, Gap);
        _PreviousOwnAlpha = OwnAlpha.GetValue();

        const auto Remaining = k_HalfPull - Pull.GetValue();
        if (Remaining > 0.0001f)
        {
            const auto AlphaPerDegree = _Control.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.AlphaPerDegree;
            _Control.Request_Nudge(FMars_Request_Control_Nudge(Math::Min(k_SlowNudgeDegrees, Remaining / AlphaPerDegree)));
        }
        else
        { _HeldSeconds += Seconds; }

        Send_PullReport(Seconds);
        Result.Set(_HeldSeconds >= k_HoldSeconds);
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] TheGrippersOwnHandleIgnoresTheLedger client: frames {_Frames}, mirroredFrames {_MirroredFrames}, laggingFrames {_LaggingFrames}, maxMoverGap {_MaxMoverGap :.4}, reportsSent {_ReportsSent}, {Get_PullText()}, ensures {Get_NewEnsures()}");
        Assert_True(_Frames > 0 && _MirroredFrames == 0, f"the gripping client never showed a mirrored grip (got {_MirroredFrames} of {_Frames})");
        Assert_True(_LaggingFrames > 0, f"the ledger's pull lagged the client's own in some frame (got {_LaggingFrames})");
        Assert_True(_MaxMoverGap < 0.001f, f"the client's Mover showed its own spring in every frame (largest gap {_MaxMoverGap})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Inactive);
        WaitUntil(n"Is_LeverFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_GrippedBySubject", n"OnServerGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_GripReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] TheGrippersOwnHandleIgnoresTheLedger server: {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(Math::Abs(_Control.Get_GripPull() - k_HalfPull) <= utils_control::k_PullReportQuantum, f"the client's pull reached the ledger (got {_Control.Get_GripPull()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
