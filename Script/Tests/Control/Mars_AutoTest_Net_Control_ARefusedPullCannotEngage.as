// A stand-in holds the grip on the server; the client reports a crossing (Cross) for the subject, once while the stand-in
// holds and once more after the stand-in's grip is released. Neither engages: the subject never held the grip, so the
// engagement count stays where it was on both machines.
// Surface: Ck.Control.Net.AS_Control_ARefusedPullCannotEngage
class UCk_AutoTest_Net_Control_ARefusedPullCannotEngage : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(130000.0, 0.0, 5000.0);
    // Long enough for the client to see the stand-in's grip and its first engage to land before the release.
    private const float32 k_ServerHoldGripSeconds = 2.0f;
    private const float32 k_ServerAfterReleaseSeconds = 3.0f;

    private int32 _EngagementsWhileHeld = -1;

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
        WaitUntil(n"Is_GrippedByStandIn", n"OnClientSawStandIn", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawStandIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Fire_GripCue(Get_SubjectEntity(), EMars_Control_GripVerb::Cross);
        WaitUntil(n"Is_GripReleased", n"OnClientSawRelease", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EngagementsWhileHeld = Get_Engagements();
        Fire_GripCue(Get_SubjectEntity(), EMars_Control_GripVerb::Cross);
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ARefusedPullCannotEngage client: engagementsWhileHeld {_EngagementsWhileHeld}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, active {_Control.Get_IsActive()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_EngagementsWhileHeld == 0, f"no engagement while the stand-in held the grip (got {_EngagementsWhileHeld})");
        Assert_True(Get_Engagements() == 0 && _EngagedCount == 0, f"no engagement after the release either (got {Get_Engagements()}, {_EngagedCount})");
        Assert_False(_Control.Get_IsActive(), "the client's lever stayed inactive");
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
        WaitSeconds(k_ServerHoldGripSeconds, n"OnServerHeldGrip");
    }

    UFUNCTION()
    private void OnServerHeldGrip(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EngagementsWhileHeld = Get_Engagements();
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::LetGo);
        WaitSeconds(k_ServerAfterReleaseSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ARefusedPullCannotEngage server: engagementsWhileHeld {_EngagementsWhileHeld}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, active {_Control.Get_IsActive()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_EngagementsWhileHeld == 0, f"the subject's crossing was dropped while the stand-in held the grip (got {_EngagementsWhileHeld})");
        Assert_True(Get_Engagements() == 0 && _EngagedCount == 0, f"the subject's crossing after the release was dropped too (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended,
            "the stand-in's grip was released");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
