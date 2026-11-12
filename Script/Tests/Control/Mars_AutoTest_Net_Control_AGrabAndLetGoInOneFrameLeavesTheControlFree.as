// The server issues a stand-in's grab and its let-go in one frame, as a real connection delivers two reliable messages
// sent a few frames apart: the control is Released with the grip serial advanced by one, and another gripper is then
// granted.
// Surface: Ck.Control.Net.AS_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree
class UCk_AutoTest_Net_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(137000.0, 0.0, 5000.0);
    private const int32 k_DrainFrames = 3;

    private bool _ReleasedAfterPair = false;
    private int32 _SerialAfterPair = -1;

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
        WaitUntil(n"Is_GrippedBySubject", n"OnClientSawSecondGrant", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawSecondGrant(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGrabAndLetGoInOneFrameLeavesTheControlFree client: {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_GripSerial() == 2 && _Control.Get_RefusalSerial() == 0,
            f"the client mirrors two grants and no refusal (got {_Control.Get_GripSerial()}, {_Control.Get_RefusalSerial()})");
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
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::LetGo);
        WaitFrames(k_DrainFrames, n"OnServerPairDrained");
    }

    UFUNCTION()
    private void OnServerPairDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ReleasedAfterPair = _Control.Get_IsGripped() == false;
        _SerialAfterPair = _Control.Get_GripSerial();
        Request_ServerGrip(Get_SubjectEntity(), EMars_Control_GripVerb::Begin);
        WaitFrames(k_DrainFrames, n"OnServerSecondDrained");
    }

    UFUNCTION()
    private void OnServerSecondDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGrabAndLetGoInOneFrameLeavesTheControlFree server: releasedAfterPair {_ReleasedAfterPair}, serialAfterPair {_SerialAfterPair}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_ReleasedAfterPair && _SerialAfterPair == 1,
            f"a grab and a let-go in one frame leave the control Released, serial advanced by one (got released {_ReleasedAfterPair}, serial {_SerialAfterPair})");
        Assert_True(_Control.Get_Gripper() == Get_SubjectEntity() && _Control.Get_GripSerial() == 2 && _Control.Get_RefusalSerial() == 0,
            f"another gripper is then granted (got {Get_WhoText(_Control.Get_Gripper())}, serial {_Control.Get_GripSerial()}, refusals {_Control.Get_RefusalSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
