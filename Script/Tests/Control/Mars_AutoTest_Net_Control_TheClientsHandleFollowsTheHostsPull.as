// The server's subject grips a replicated lever, as the listen host's player does, pulls it to about half and holds: the
// authority's own grip publishes its pull, the client's grip ledger Pull follows it and the client's Mover alpha converges
// on it, while the client's own Get_IsManipulating stays false.
// Surface: Ck.Control.Net.AS_Control_TheClientsHandleFollowsTheHostsPull
class UCk_AutoTest_Net_Control_TheClientsHandleFollowsTheHostsPull : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(141000.0, 0.0, 5000.0);
    // Long enough for the client to see the held pull and finish.
    private const float32 k_HostHoldSeconds = 5.0f;

    private bool _EverManipulated = false;

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
        WaitUntil(n"Is_ClientFollowing", n"OnClientFollowed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientFollowing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _EverManipulated = _EverManipulated || _Control.Get_IsManipulating();

        auto Result = OutResult;
        Result.Set(_Control.Get_Gripper() == Get_SubjectEntity()
            && Math::Abs(_Control.Get_GripPull() - k_HalfPull) <= utils_control::k_PullReportQuantum
            && ck::IsValid(_Mover) && Math::Abs(_Mover.Get_Alpha() - k_HalfPull) < k_FollowTolerance);
    }

    UFUNCTION()
    private void OnClientFollowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] TheClientsHandleFollowsTheHostsPull client: everManipulated {_EverManipulated}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_EverManipulated == false, "the client's own Get_IsManipulating stayed false");
        Assert_True(_Control.TryGet_MirroredGripAlpha().IsSet(), "the client shows the host's grip");
        Assert_True(Math::Abs(_Control.Get_GripPull() - k_HalfPull) <= utils_control::k_PullReportQuantum,
            f"the client's ledger pull follows the host's (got {_Control.Get_GripPull()})");
        Assert_True(Math::Abs(_Mover.Get_Alpha() - k_HalfPull) < k_FollowTolerance, f"the client's handle converged on it (got {_Mover.Get_Alpha()})");
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
        Log(f"[ControlNetTest] TheClientsHandleFollowsTheHostsPull server: manipulating {_Control.Get_IsManipulating()}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsManipulating(), "the host still holds its grip");
        Assert_True(Math::Abs(_Control.Get_GripPull() - k_HalfPull) <= utils_control::k_PullReportQuantum,
            f"the host's grip published its pull to the ledger (got {_Control.Get_GripPull()})");
        Assert_True(_Control.TryGet_MirroredGripAlpha().IsSet() == false, "the host does not mirror its own grip");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
