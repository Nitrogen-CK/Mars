// The client grips its copy of a replicated lever without an interaction, so crossing the threshold ends nothing and no
// engage is sent. Its handle waits at the threshold and refuses a new grip until the pending engage times out; then the
// handle settles back to rest, a new grip begins, and the server's ledger never moved.
// Surface: Ck.Control.Net.AS_Control_APendingEngageThatNeverArrivesSettlesBack
class UCk_AutoTest_Net_Control_APendingEngageThatNeverArrivesSettlesBack : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(125000.0, 0.0, 5000.0);
    private const float32 k_ServerWindowSeconds = 8.0f;
    private const int32 k_DrainFrames = 3;

    private float32 _AlphaAtCrossing = 0.0f;
    private float32 _AlphaWhilePending = 0.0f;
    private bool _GrippedWhilePending = false;

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
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation());
        WaitUntil(n"Is_Manipulating", n"OnClientGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_PulledUntilEnded", n"OnClientCrossed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientCrossed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AlphaAtCrossing = _Mover.Get_Alpha();
        WaitSeconds(utils_control::k_PendingEngageSeconds * 0.5f, n"OnClientMidPending");
    }

    UFUNCTION()
    private void OnClientMidPending(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation());
        WaitFrames(k_DrainFrames, n"OnClientPendingRegripDrained");
    }

    UFUNCTION()
    private void OnClientPendingRegripDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _GrippedWhilePending = _Control.Get_IsManipulating();
        _AlphaWhilePending = _Mover.Get_Alpha();
        WaitUntil(n"Is_HandleAtRest", n"OnClientSettledBack", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSettledBack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation());
        WaitUntil(n"Is_Manipulating", n"OnClientRegripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRegripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] APendingEngageThatNeverArrivesSettlesBack client: alphaAtCrossing {_AlphaAtCrossing}, grippedWhilePending {_GrippedWhilePending}, alphaWhilePending {_AlphaWhilePending}, moverAtRegrip {_Mover.Get_Alpha()}, regripped {_Control.Get_IsManipulating()}, active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, ensures {Get_NewEnsures()}");
        Assert_True(_AlphaAtCrossing >= 0.85f, f"the client's handle stood at the threshold when it crossed (got {_AlphaAtCrossing})");
        Assert_False(_GrippedWhilePending, "a grip asked while the engage was pending did not begin");
        Assert_True(_AlphaWhilePending >= 0.85f, f"the handle waited at the threshold while the engage was pending (got {_AlphaWhilePending})");
        Assert_True(_Control.Get_IsManipulating(), "a grip asked after the pending engage timed out began");
        Assert_True(_Control.Get_IsActive() == false && Get_Engagements() == 0, f"nothing engaged (got {_Control.Get_IsActive()}, {Get_Engagements()})");
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
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] APendingEngageThatNeverArrivesSettlesBack server: active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, ensures {Get_NewEnsures()}");
        Assert_False(_Control.Get_IsActive(), "the server's lever stayed inactive");
        Assert_True(Get_Engagements() == 0 && _EngagedCount == 0, f"the server counted no engagement (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
