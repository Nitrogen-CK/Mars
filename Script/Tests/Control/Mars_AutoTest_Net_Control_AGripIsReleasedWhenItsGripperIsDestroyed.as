// A stand-in holds the grip on the server, which then destroys the stand-in: both machines read the grip Released with
// GripperLost, and the client can then grip and is granted.
// Surface: Ck.Control.Net.AS_Control_AGripIsReleasedWhenItsGripperIsDestroyed
class UCk_AutoTest_Net_Control_AGripIsReleasedWhenItsGripperIsDestroyed : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(132000.0, 0.0, 5000.0);

    private EMars_Control_GripRelease _ReleaseSeen = EMars_Control_GripRelease::Ended;
    private int32 _SerialAtLoss = -1;

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

    // A granted grip released because its gripper was lost.
    UFUNCTION()
    private void Is_GripperLost(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Control) && _Control.Get_GripSerial() >= 1 && _Control.Get_IsGripped() == false
            && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::GripperLost);
    }

    // Client: the loss shows, and the lever is free here again (another's grip held the Operated claim on it).
    UFUNCTION()
    private void Is_GripperLostAndUnclaimed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Control) && _Control.Get_GripSerial() >= 1 && _Control.Get_IsGripped() == false
            && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::GripperLost && Get_IsClaimed() == false);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_GripperLostAndUnclaimed", n"OnClientSawLoss", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawLoss(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ReleaseSeen = _Control.Get_LastGripRelease();
        _SerialAtLoss = _Control.Get_GripSerial();
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
        Log(f"[ControlNetTest] AGripIsReleasedWhenItsGripperIsDestroyed client: releaseSeen {_ReleaseSeen :n}, serialAtLoss {_SerialAtLoss}, {Get_GripText(_Control)}, manipulating {_Control.Get_IsManipulating()}, refusalsRaised {_GripRefusals.Num()}, ensures {Get_NewEnsures()}");
        Assert_True(_ReleaseSeen == EMars_Control_GripRelease::GripperLost && _SerialAtLoss == 1,
            f"the client read the stand-in's grip released as GripperLost (got {_ReleaseSeen :n}, serial {_SerialAtLoss})");
        Assert_True(_Control.Get_Gripper() == Get_SubjectEntity() && _Control.Get_GripSerial() == 2,
            f"the client's grip was granted next (got {Get_WhoText(_Control.Get_Gripper())}, serial {_Control.Get_GripSerial()})");
        Assert_True(_Control.Get_IsManipulating(), "the client's own grip stands");
        Assert_True(_GripRefusals.Num() == 0, f"nothing was refused (got {_GripRefusals.Num()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
        WaitSeconds(k_SettleSeconds, n"OnClientLetGo");
    }

    UFUNCTION()
    private void OnClientLetGo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
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
        utils_entity_lifetime::Request_DestroyEntity(_StandIn);
        WaitUntil(n"Is_GripperLost", n"OnServerLost", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLost(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ReleaseSeen = _Control.Get_LastGripRelease();
        _SerialAtLoss = _Control.Get_GripSerial();
        WaitUntil(n"Is_GrippedBySubject", n"OnServerGrantedSubject", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGrantedSubject(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGripIsReleasedWhenItsGripperIsDestroyed server: releaseSeen {_ReleaseSeen :n}, serialAtLoss {_SerialAtLoss}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_ReleaseSeen == EMars_Control_GripRelease::GripperLost && _SerialAtLoss == 1,
            f"destroying the stand-in released its grip as GripperLost (got {_ReleaseSeen :n}, serial {_SerialAtLoss})");
        Assert_True(_Control.Get_GripSerial() == 2 && _Control.Get_RefusalSerial() == 0,
            f"the subject was granted the next grip, unrefused (got serial {_Control.Get_GripSerial()}, refusals {_Control.Get_RefusalSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
