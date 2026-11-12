// The client grips a replicated lever and pulls it steadily for one second, its pull changing every frame, reporting by
// the kernel's pacing rule; then it stops reporting, holds and lets go. Over that second the client sends at most
// k_PullReportHz + 1 reports, and the server's ledger Pull changes at most that many times.
// Surface: Ck.Control.Net.AS_Control_ReportsStayUnderTheRate
class UCk_AutoTest_Net_Control_ReportsStayUnderTheRate : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(144000.0, 0.0, 5000.0);
    private const float32 k_PullSeconds = 1.0f;
    // Pull per second: a steady change every frame that stays well short of the threshold.
    private const float32 k_PullRate = 0.4f;
    private const float32 k_HoldSeconds = 1.0f;

    private float32 _PulledSeconds = 0.0f;
    private float32 _HeldSeconds = 0.0f;
    private int32 _PulledFrames = 0;
    private int32 _LedgerChanges = 0;
    private float32 _SeenLedgerPull = 0.0f;

    // At most one report at the start of the second and one per 1 / k_PullReportHz after it.
    private int32 Get_MaxReports() const
    {
        return Math::FloorToInt(k_PullSeconds * utils_control::k_PullReportHz) + 1;
    }

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
        WaitUntil(n"Is_ClientPulledForASecond", n"OnClientPulled", k_SlowPolls);
    }

    // Client, every frame of the second: a nudge worth k_PullRate a second, and a paced report.
    UFUNCTION()
    private void Is_ClientPulledForASecond(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Seconds = Get_FrameSeconds();
        auto Result = OutResult;
        if (_Control.Get_IsManipulating() == false)
        {
            Result.Set(true);
            return;
        }

        _PulledSeconds += Seconds;
        if (_PulledSeconds > k_PullSeconds)
        {
            Result.Set(true);
            return;
        }

        _PulledFrames += 1;
        const auto AlphaPerDegree = _Control.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.AlphaPerDegree;
        _Control.Request_Nudge(FMars_Request_Control_Nudge(k_PullRate * Math::Max(Seconds, 1.0f / 120.0f) / AlphaPerDegree));
        Send_PullReport(Seconds);
        Result.Set(false);
    }

    UFUNCTION()
    private void OnClientPulled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_HoldSeconds, n"OnClientHeld");
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ReportsStayUnderTheRate client: pulledFrames {_PulledFrames}, reportsSent {_ReportsSent}, maxReports {Get_MaxReports()}, {Get_PullText()}, ensures {Get_NewEnsures()}");
        Assert_True(_PulledFrames > Get_MaxReports(), f"the pull changed in more frames than the rate allows reports (got {_PulledFrames})");
        Assert_True(_ReportsSent >= 2 && _ReportsSent <= Get_MaxReports(), f"the client sent at most {Get_MaxReports()} reports in the second (got {_ReportsSent})");
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
        _SeenLedgerPull = _Control.Get_GripPull();
        WaitUntil(n"Is_ServerCountedUntilReleased", n"OnServerReleased", k_SlowPolls);
    }

    // Server, every frame: a ledger Pull different from the last frame's is one change.
    UFUNCTION()
    private void Is_ServerCountedUntilReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Pull = _Control.Get_GripPull();
        if (Pull != _SeenLedgerPull)
        {
            _LedgerChanges += 1;
            _SeenLedgerPull = Pull;
        }

        auto Result = OutResult;
        Result.Set(_Control.Get_IsGripped() == false);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ReportsStayUnderTheRate server: ledgerChanges {_LedgerChanges}, maxReports {Get_MaxReports()}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_LedgerChanges >= 1 && _LedgerChanges <= Get_MaxReports(), f"the ledger's pull changed at most {Get_MaxReports()} times (got {_LedgerChanges})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
