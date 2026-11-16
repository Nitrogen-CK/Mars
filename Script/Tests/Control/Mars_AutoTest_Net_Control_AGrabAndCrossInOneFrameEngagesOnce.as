// The server issues a stand-in's grab and its crossing in one frame: the lever engages once and is Released. Then, with
// the stand-in holding a new grip, its crossing and the subject's grab land in one frame: the lever engages once more and
// the subject holds it.
// Surface: Ck.Control.Net.AS_Control_AGrabAndCrossInOneFrameEngagesOnce
class UCk_AutoTest_Net_Control_AGrabAndCrossInOneFrameEngagesOnce : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(138000.0, 0.0, 5000.0);
    private const int32 k_DrainFrames = 3;

    private int32 _EngagementsAfterPair = -1;
    private bool _ReleasedAfterPair = false;

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
        WaitUntil(n"Is_GrippedBySubject", n"OnClientSawSubjectHold", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawSubjectHold(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGrabAndCrossInOneFrameEngagesOnce client: engagements {Get_Engagements()}, onEngaged {_EngagedCount}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(Get_Engagements() == 2 && _EngagedCount == 2, f"the client mirrors two engagements (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Control.Get_Gripper() == Get_SubjectEntity(), f"the subject holds the lever (got {Get_WhoText(_Control.Get_Gripper())})");
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

    // A settled interval after the find, so the act reaches the client's copy after the state it was born into.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerReadyToGrabAndCross");
    }

    UFUNCTION()
    private void OnServerReadyToGrabAndCross(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Cross);
        WaitFrames(k_DrainFrames, n"OnServerPairDrained");
    }

    UFUNCTION()
    private void OnServerPairDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EngagementsAfterPair = Get_Engagements();
        _ReleasedAfterPair = _Control.Get_IsGripped() == false;
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        WaitUntil(n"Is_GrippedByStandIn", n"OnServerStandInHolds", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStandInHolds(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Cross);
        Request_ServerGrip(Get_SubjectEntity(), EMars_Control_GripVerb::Begin);
        WaitFrames(k_DrainFrames, n"OnServerHandOverDrained");
    }

    UFUNCTION()
    private void OnServerHandOverDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGrabAndCrossInOneFrameEngagesOnce server: engagementsAfterPair {_EngagementsAfterPair}, releasedAfterPair {_ReleasedAfterPair}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_EngagementsAfterPair == 1 && _ReleasedAfterPair,
            f"a grab and its crossing in one frame engage once and release (got {_EngagementsAfterPair}, released {_ReleasedAfterPair})");
        Assert_True(Get_Engagements() == 2 && _EngagedCount == 2, f"the crossing beside the next grab engaged once more (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Control.Get_Gripper() == Get_SubjectEntity() && _Control.Get_GripSerial() == 3,
            f"the subject holds the third grip (got {Get_WhoText(_Control.Get_Gripper())}, serial {_Control.Get_GripSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
