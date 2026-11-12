// The client grips a replicated lever, pulls it to about half and holds, reporting its pull by the kernel's pacing rule
// once its ledger shows the grant: the server's grip ledger Pull comes within the quantum of the client's pull, and the
// server, which holds no grip of its own, shows the handle following it until its Mover alpha converges on it.
// Surface: Ck.Control.Net.AS_Control_TheServersHandleFollowsAClientsPull
class UCk_AutoTest_Net_Control_TheServersHandleFollowsAClientsPull : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(140000.0, 0.0, 5000.0);
    private const float32 k_HoldSeconds = 2.0f;

    private float32 _HeldSeconds = 0.0f;

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

    // Client, every frame: nudges toward half and reports, until it has held half for k_HoldSeconds.
    UFUNCTION()
    private void Is_ClientPulledAndHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Seconds = Get_FrameSeconds();
        Nudge_Toward(k_HalfPull);
        Send_PullReport(Seconds);

        const auto Pull = _Control.TryGet_ManipulationPull();
        if (Pull.IsSet() && Math::Abs(Pull.GetValue() - k_HalfPull) < 0.001f)
        { _HeldSeconds += Seconds; }

        auto Result = OutResult;
        Result.Set(_HeldSeconds >= k_HoldSeconds || Pull.IsSet() == false);
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] TheServersHandleFollowsAClientsPull client: manipulating {_Control.Get_IsManipulating()}, {Get_PullText()}, reportsSent {_ReportsSent}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsManipulating(), "the client still holds its grip");
        Assert_True(_ReportsSent >= 1, f"the client reported its pull (got {_ReportsSent})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
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
        WaitUntil(n"Is_ServerFollowing", n"OnServerFollowed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFollowing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Math::Abs(_Control.Get_GripPull() - k_HalfPull) <= utils_control::k_PullReportQuantum
            && ck::IsValid(_Mover) && Math::Abs(_Mover.Get_Alpha() - k_HalfPull) < k_FollowTolerance);
    }

    UFUNCTION()
    private void OnServerFollowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] TheServersHandleFollowsAClientsPull server: manipulating {_Control.Get_IsManipulating()}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsManipulating() == false, "the server holds no grip of its own");
        Assert_True(_Control.TryGet_MirroredGripAlpha().IsSet(), "the server shows the client's grip");
        Assert_True(Math::Abs(_Control.Get_GripPull() - k_HalfPull) <= utils_control::k_PullReportQuantum,
            f"the ledger's pull is within the quantum of the client's (got {_Control.Get_GripPull()})");
        Assert_True(Math::Abs(_Mover.Get_Alpha() - k_HalfPull) < k_FollowTolerance, f"the server's handle converged on it (got {_Mover.Get_Alpha()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        // The client is still holding: the lever stays until it is done.
        WaitSeconds(k_ServerHoldSeconds + k_HoldSeconds, n"OnServerHeld");
    }
}
