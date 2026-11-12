// The server grants a stand-in a grip and applies its report of 0.3. A report naming the subject, which is not the
// gripper, then leaves the ledger's Pull at 0.3; so does the stand-in's own report queued in the frame its LetGo is, after
// it, and one sent once the release shows. The client's ledger reads the same 0.3.
// Surface: Ck.Control.Net.AS_Control_AReportFromANonGripperIsDropped
class UCk_AutoTest_Net_Control_AReportFromANonGripperIsDropped : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(142000.0, 0.0, 5000.0);
    private const float32 k_GrippersPull = 0.3f;
    private const int32 k_DrainFrames = 10;

    private float32 _PullAfterNonGripper = -1.0f;
    private float32 _PullAfterSameFrameLetGo = -1.0f;

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
        WaitUntil(n"Is_GripReleased", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AReportFromANonGripperIsDropped client: {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(Math::Abs(_Control.Get_GripPull() - k_GrippersPull) < 0.0001f, f"the client's ledger pull is the gripper's report (got {_Control.Get_GripPull()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Inactive);
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
        WaitUntil(n"Is_GrippedByStandIn", n"OnServerGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_ReportPull(FMars_Request_Control_ReportPull(_StandIn, k_GrippersPull));
        WaitUntil(n"Is_LedgerAtTheGrippersPull", n"OnServerReported", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_LedgerAtTheGrippersPull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Math::Abs(_Control.Get_GripPull() - k_GrippersPull) < 0.0001f);
    }

    UFUNCTION()
    private void OnServerReported(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_ReportPull(FMars_Request_Control_ReportPull(Get_SubjectEntity(), 0.9f));
        WaitFrames(k_DrainFrames, n"OnServerNonGripperDrained");
    }

    UFUNCTION()
    private void OnServerNonGripperDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PullAfterNonGripper = _Control.Get_GripPull();

        // The end first, its trailing report after it, in one frame.
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::LetGo);
        _Control.Request_ReportPull(FMars_Request_Control_ReportPull(_StandIn, 0.8f));
        WaitUntil(n"Is_GripReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PullAfterSameFrameLetGo = _Control.Get_GripPull();
        _Control.Request_ReportPull(FMars_Request_Control_ReportPull(_StandIn, 0.7f));
        WaitFrames(k_DrainFrames, n"OnServerLateDrained");
    }

    UFUNCTION()
    private void OnServerLateDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AReportFromANonGripperIsDropped server: afterNonGripper {_PullAfterNonGripper :.3}, afterSameFrameLetGo {_PullAfterSameFrameLetGo :.3}, afterLate {_Control.Get_GripPull() :.3}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(Math::Abs(_PullAfterNonGripper - k_GrippersPull) < 0.0001f, f"a report naming a non-gripper changed nothing (got {_PullAfterNonGripper})");
        Assert_True(Math::Abs(_PullAfterSameFrameLetGo - k_GrippersPull) < 0.0001f, f"a report queued after the LetGo changed nothing (got {_PullAfterSameFrameLetGo})");
        Assert_True(Math::Abs(_Control.Get_GripPull() - k_GrippersPull) < 0.0001f, f"a report after the release changed nothing (got {_Control.Get_GripPull()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
