// The client pulls its copy of a replicated lever past the threshold and asks for a new grip every frame until the
// engagement replicates back: none begins while its ledger still shows the old state, one asked after the mirror begins
// normally, and both machines end with one engagement.
// Surface: Ck.Control.Net.AS_Control_ARegripBeforeTheEngageArrivesEngagesOnce
class UCk_AutoTest_Net_Control_ARegripBeforeTheEngageArrivesEngagesOnce : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(123000.0, 0.0, 5000.0);
    private const float32 k_ServerWindowSeconds = 6.0f;

    private int32 _AsksBeforeMirror = 0;
    private int32 _GripsBeforeMirror = 0;

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
        WaitUntil(n"Is_Manipulating", n"OnClientGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.BindTo_OnManipulationChanged(FMars_Delegate_Control_OnManipulationChanged(this, n"OnClientGripChanged"));
        WaitUntil(n"Is_PulledUntilEnded", n"OnClientCrossed", k_SlowPolls);
    }

    // The first ask lands in the crossing's own frame, as a player pressing again at once would.
    UFUNCTION()
    private void OnClientGripChanged(FCk_Handle_Control InControl, EMars_Control_Grip InGrip)
    {
        if (InGrip != EMars_Control_Grip::Released || Get_Engagements() != 0 || _AsksBeforeMirror > 0)
        { return; }

        _AsksBeforeMirror += 1;
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation());
    }

    UFUNCTION()
    private void OnClientCrossed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_RegripAskedUntilMirrored", n"OnClientMirrored", k_SlowPolls);
    }

    // Every frame the ledger still counts no engagement: a grip that began is counted, then a new one is asked.
    UFUNCTION()
    private void Is_RegripAskedUntilMirrored(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_Engagements() != 0)
        {
            Result.Set(true);
            return;
        }

        if (_Control.Get_IsManipulating())
        { _GripsBeforeMirror += 1; }

        _AsksBeforeMirror += 1;
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation());
        Result.Set(false);
    }

    UFUNCTION()
    private void OnClientMirrored(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation());
        WaitUntil(n"Is_Manipulating", n"OnClientRegripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRegripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
        WaitUntil(n"Is_HandleAtEnd", n"OnClientLetGo", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLetGo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ARegripBeforeTheEngageArrivesEngagesOnce client: asksBeforeMirror {_AsksBeforeMirror}, gripsBeforeMirror {_GripsBeforeMirror}, active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, mover {_Mover.Get_Alpha()}, ensures {Get_NewEnsures()}");
        Assert_True(_AsksBeforeMirror > 0, f"the client asked for a grip before the engagement replicated (got {_AsksBeforeMirror})");
        Assert_True(_GripsBeforeMirror == 0, f"no grip began before the engagement replicated (got {_GripsBeforeMirror})");
        Assert_True(_Control.Get_IsActive() && Get_Engagements() == 1 && _EngagedCount == 1,
            f"the client mirrors one engagement and the lever active (got {_Control.Get_IsActive()}, {Get_Engagements()}, {_EngagedCount})");
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
        WaitUntil(n"Is_EngagedOnce", n"OnServerEngaged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEngaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ARegripBeforeTheEngageArrivesEngagesOnce server: active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsActive(), "the server's lever is active");
        Assert_True(Get_Engagements() == 1 && _EngagedCount == 1, f"the server counts one engagement (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
