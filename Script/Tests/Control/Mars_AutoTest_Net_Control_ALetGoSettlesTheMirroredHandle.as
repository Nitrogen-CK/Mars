// The server's subject grips a replicated lever, pulls it to about half, holds it while the client's handle follows, and
// lets go before the threshold: the client's handle, mirrored near half, returns to rest once the release arrives.
// Surface: Ck.Control.Net.AS_Control_ALetGoSettlesTheMirroredHandle
class UCk_AutoTest_Net_Control_ALetGoSettlesTheMirroredHandle : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(145000.0, 0.0, 5000.0);
    // Long enough for the client's handle to follow the held pull.
    private const float32 k_HostHoldSeconds = 3.0f;

    private float32 _MaxMirroredAlpha = 0.0f;

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
        WaitUntil(n"Is_ClientReleasedAfterFollowing", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReleasedAfterFollowing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Mirrored = _Control.TryGet_MirroredGripAlpha();
        if (Mirrored.IsSet())
        { _MaxMirroredAlpha = Math::Max(_MaxMirroredAlpha, Mirrored.GetValue()); }

        auto Result = OutResult;
        Result.Set(_Control.Get_GripSerial() >= 1 && _Control.Get_IsGripped() == false);
    }

    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_HandleAtRest", n"OnClientAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ALetGoSettlesTheMirroredHandle client: maxMirroredAlpha {_MaxMirroredAlpha :.3}, release {_Control.Get_LastGripRelease() :n}, {Get_PullText()}, ensures {Get_NewEnsures()}");
        Assert_True(Math::Abs(_MaxMirroredAlpha - k_HalfPull) < k_FollowTolerance, f"the client's handle followed the host to about half (got {_MaxMirroredAlpha})");
        Assert_True(_Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended, "the grip was released as a let-go");
        Assert_True(_Control.TryGet_MirroredGripAlpha().IsSet() == false, "the client no longer shows a grip");
        Assert_True(_Mover.Get_Alpha() < 0.01f, f"the client's handle returned to rest (got {_Mover.Get_Alpha()})");
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
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnServerInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        WaitUntil(n"Is_GrippedBySubject", n"OnServerGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerPulledToHalf", n"OnServerPulled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPulledToHalf(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Nudge_Toward(k_HalfPull);
        const auto Pull = _Control.TryGet_ManipulationPull();

        auto Result = OutResult;
        Result.Set(Pull.IsSet() == false || Math::Abs(Pull.GetValue() - k_HalfPull) < 0.001f);
    }

    UFUNCTION()
    private void OnServerPulled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_HostHoldSeconds, n"OnServerHeldHalf");
    }

    UFUNCTION()
    private void OnServerHeldHalf(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
        WaitUntil(n"Is_GripReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ALetGoSettlesTheMirroredHandle server: {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended, "the host's let-go released the grip as Ended");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
