// A client in the production pawn turns its view 180 degrees and looks down k_Pitch (its own camera director, as its
// look input would). The host's copy of that pawn is not locally controlled and gets no look input; its view follows the
// pawn's replicated aim (UMars_Processor_PlayerViewpoint_FollowAim): measured at the end of every frame over
// k_WatchSeconds, the host's copy's view forward stays within k_ToleranceDeg of the forward the client turned to. The
// server reports what it measured; the client asserts its own view reached the target.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsViewForwardFollowsItsAimOnTheHost
class UCk_AutoTest_Net_RealPawn_AClientsViewForwardFollowsItsAimOnTheHost : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(936000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsViewForwardFollowsItsAimOnTheHost";
    private const float64 k_Yaw = 180.0;
    private const float64 k_Pitch = -30.0;
    // The client's own view reaches the target within this.
    private const float64 k_ClientToleranceDeg = 1.0;
    // The host's copy turns with the replicated control rotation (a compressed short per axis), the same frame.
    private const float64 k_ToleranceDeg = 3.0;
    private const float64 k_WatchSeconds = 1.0;

    private AMars_AutoTestProbe_ViewForward _Probe;
    private float64 _ClientAngleDeg = -1.0;

    private FVector Get_TargetForward() const
    {
        return FRotator(k_Pitch, k_Yaw, 0.0).Quaternion().GetForwardVector();
    }

    private float64 Get_AngleToTargetDeg()
    {
        return Math::RadiansToDegrees(Math::Acos(Math::Clamp(Get_ViewForward().DotProduct(Get_TargetForward()), -1.0, 1.0)));
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        Add_Report();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientOwnerReady", n"OnClientReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        WaitUntil(n"Is_ServerPawnAndOwnerReady", n"OnServerComposed", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); return; }

        Mark_Deadline(12.0);
        WaitUntil(n"Is_ServerViewTurned", n"OnServerViewTurned", k_SlowPolls);
    }

    // The server's copy has turned with the client (or the deadline passed: the watch then measures how far it is off).
    UFUNCTION()
    private void Is_ServerViewTurned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_AngleToTargetDeg() <= k_ToleranceDeg);
    }

    UFUNCTION()
    private void OnServerViewTurned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Probe = Spawn_ViewProbe(Get_TargetForward());
        if (ck::Is_NOT_Valid(_Probe))
        { FinishFailure("the view probe did not spawn on the server"); return; }

        _Probe.IsSampling = true;
        WaitSeconds(float32(k_WatchSeconds), n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Probe.IsSampling = false;
        const auto Forward = Get_ViewForward();
        const auto Aim = _Pawn.GetBaseAimRotation().GetNormalized();
        Write_ViewReport(_Probe.MaxAngleDeg, _Probe.Samples);
        Log_RealPawnRow(k_Row, f"samples={_Probe.Samples} maxAngle={_Probe.MaxAngleDeg :.2} lastAngle={_Probe.LastAngleDeg :.2} forward={Forward} target={Get_TargetForward()} baseAim={Aim}");
        Assert_True(_Probe.Samples > 10, f"the server sampled its copy's view at the end of {_Probe.Samples} frames");
        Assert_True(_Probe.MaxAngleDeg <= k_ToleranceDeg,
            f"the server's copy of the client's view points where the client looks: max {_Probe.MaxAngleDeg :.2} deg off over {_Probe.Samples} frames (last {_Probe.LastAngleDeg :.2}; forward {Forward}, target {Get_TargetForward()}, base aim {Aim})");
        _Probe.DestroyActor();
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerTurnView(FRotator(k_Pitch, k_Yaw, 0.0));
        Mark_Deadline(4.0);
        WaitUntil(n"Is_ClientViewTurned", n"OnClientViewTurned", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientViewTurned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_AngleToTargetDeg() <= k_ClientToleranceDeg);
    }

    UFUNCTION()
    private void OnClientViewTurned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientAngleDeg = Get_AngleToTargetDeg();
        if (_ClientAngleDeg > k_ClientToleranceDeg)
        {
            Log_RealPawnRow(k_Row, f"clientAngle={_ClientAngleDeg :.2} forward={Get_ViewForward()}");
            FinishFailure(f"the client's own view did not turn to the target ({_ClientAngleDeg :.2} deg off)");
            return;
        }

        Mark_Deadline(20.0);
        WaitUntil(n"Is_ClientReportArrived", n"OnClientChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReportArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_Report().Serial > 0);
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_Report();
        Log_RealPawnRow(k_Row, f"clientAngle={_ClientAngleDeg :.2} report={Report.Serial} serverMaxAngle={Report.ViewMaxAngleDeg :.2} serverSamples={Report.ViewSamples}");
        Assert_True(Report.Serial > 0, "the server reported what it measured");
        Assert_True(Report.ViewMaxAngleDeg >= 0.0 && Report.ViewMaxAngleDeg <= k_ToleranceDeg,
            f"the server's copy of this client's view followed its aim (max {Report.ViewMaxAngleDeg :.2} deg off over {Report.ViewSamples} frames)");
        FinishSuccess();
    }
}
