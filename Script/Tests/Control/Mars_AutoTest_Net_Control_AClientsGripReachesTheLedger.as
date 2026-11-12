// The client grips its copy of a replicated lever through an interaction: the server's grip ledger reads Gripped by the
// subject with the grip serial advanced by one, and once the client lets go both machines read Released (Ended).
// Surface: Ck.Control.Net.AS_Control_AClientsGripReachesTheLedger
class UCk_AutoTest_Net_Control_AClientsGripReachesTheLedger : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(128000.0, 0.0, 5000.0);

    private int32 _SerialWhenGripped = -1;

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
        WaitUntil(n"Is_GrippedBySubject", n"OnClientGrantMirrored", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGrantMirrored(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialWhenGripped = _Control.Get_GripSerial();
        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
        WaitUntil(n"Is_GripReleased", n"OnClientReleaseMirrored", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientReleaseMirrored(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientsGripReachesTheLedger client: serialWhenGripped {_SerialWhenGripped}, {Get_GripText(_Control)}, manipulating {_Control.Get_IsManipulating()}, refusalsRaised {_GripRefusals.Num()}, ensures {Get_NewEnsures()}");
        Assert_True(_SerialWhenGripped == 1, f"the client mirrored the subject's grip as the first granted (got serial {_SerialWhenGripped})");
        Assert_True(_Control.Get_IsGripped() == false && ck::Is_NOT_Valid(_Control.Get_Gripper()), "the client reads the grip released, with no gripper");
        Assert_True(_Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended, f"the client reads the release Ended (got {_Control.Get_LastGripRelease() :n})");
        Assert_True(_GripRefusals.Num() == 0 && _Control.Get_RefusalSerial() == 0, "nothing was refused");
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
        _SerialWhenGripped = _Control.Get_GripSerial();
        WaitUntil(n"Is_GripReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientsGripReachesTheLedger server: serialWhenGripped {_SerialWhenGripped}, {Get_GripText(_Control)}, manipulating {_Control.Get_IsManipulating()}, ensures {Get_NewEnsures()}");
        Assert_True(_SerialWhenGripped == 1, f"the server granted the subject the first grip (got serial {_SerialWhenGripped})");
        Assert_True(_Control.Get_GripSerial() == 1, f"one grip was granted (got {_Control.Get_GripSerial()})");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended,
            f"the server released the grip as Ended (got {_Control.Get_LastGripRelease() :n})");
        Assert_False(_Control.Get_IsManipulating(), "the server never gripped locally");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
