// A Cellar Bat spawned 100 off its roost's hang point discovers the roost, hangs there 2 s, patrols two flight nodes
// and comes back to hang from it (Alert, Launching, Patrolling, Returning, Braking, Perching, Roosting). The client's
// copy reads the roost's place as its perch anchor from the ledger while it still roosts (100 from the place it would
// work out for itself), records the same seven phases in that order with each change's From the To of the one before,
// ends within 60 of the roost's hang point and raises no OnRouteOutcome, OnPerchLost or OnTargetChanged.
// Surface: Ck.Bat.Net.AS_Bat_APatrolRunsItsPhasesAndThePerchReachesTheClient
class UCk_AutoTest_Net_Bat_APatrolRunsItsPhasesAndThePerchReachesTheClient : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(662000.0, 0.0, 5000.0);
    private const FVector k_SpawnOffset = FVector(100.0, 0.0, 0.0);
    private const float32 k_DiscoverRadius = 150.0f;
    private const float32 k_RoostIdleSeconds = 2.0f;
    private const float32 k_ServerWatchSeconds = 2.0f;
    private const float64 k_HomeCm = 60.0;

    // The frame the client's copy first read the roost's place, and the phase it read then.
    private int32 _AnchorFrame = -1;
    private EMars_Bat_Phase _PhaseAtAnchor = EMars_Bat_Phase::Dead;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_Floor);
        _WithVisuals = true;
        _GivesRoost = ECk_EnableDisable::Disable;
        _SpawnOffset = k_SpawnOffset;
        _Spec.Roost.DiscoverRadius = k_DiscoverRadius;
        _Spec.Timing.RoostIdleSeconds = k_RoostIdleSeconds;
        _Spec.FlightNodes.Add(_Floor + FVector(400.0, 0.0, 350.0));
        _Spec.FlightNodes.Add(_Floor + FVector(0.0, 400.0, 350.0));

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerWorld(n"OnServerReady");
    }

    private TArray<EMars_Bat_Phase> Get_PatrolOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Alert);
        Order.Add(EMars_Bat_Phase::Launching);
        Order.Add(EMars_Bat_Phase::Patrolling);
        Order.Add(EMars_Bat_Phase::Returning);
        Order.Add(EMars_Bat_Phase::Braking);
        Order.Add(EMars_Bat_Phase::Perching);
        Order.Add(EMars_Bat_Phase::Roosting);
        return Order;
    }

    private FVector Get_RoostHangPoint() const
    {
        return Get_RoostAnchor() + _Spec.Roost.HangOffset;
    }

    UFUNCTION()
    private void Is_BackOnTheRoost(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && Get_HasRoostedAfterPerching());
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_BackOnTheRoost", n"OnServerBack", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerBack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto FromHome = (_Bat.Get_Location() - Get_RoostHangPoint()).Size();
        Assert_True(Get_SawPhasesInOrder(Get_PatrolOrder()), f"the server recorded the patrol's seven phases in order (saw {Describe_BatPhases()})");
        Assert_True(FromHome <= k_HomeCm, f"the server's root is within 60 of the roost's hang point (reads {FromHome})");
        Assert_True(_Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Held, "the server's bat holds the roost");
        Hold_BatServerRow("APatrolRunsItsPhasesAndThePerchReachesTheClient", "");
    }

    UFUNCTION()
    private void Is_AnchorAtTheRoost(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_PerchAnchor().Equals(Get_RoostAnchor(), 1.0));
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_AnchorAtTheRoost", n"OnClientAnchored", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAnchored(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AnchorFrame = int32(utils_time::Get_FrameCounter());
        _PhaseAtAnchor = _Bat.Get_Phase();
        WaitUntil(n"Is_BackOnTheRoost", n"OnClientBack", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientBack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto FromHome = (_Bat.Get_Location() - Get_RoostHangPoint()).Size();
        Assert_True(_PhaseAtAnchor == EMars_Bat_Phase::Roosting, f"the roost's place reached the client while its copy roosted (read {_PhaseAtAnchor :n})");
        Assert_True(Get_SawExactlyPhases(Get_PatrolOrder()), f"the client recorded the seven phases in order, each from the last (saw {Describe_BatPhases()})");
        Assert_True(FromHome <= k_HomeCm, f"the client's root is within 60 of the roost's hang point (reads {FromHome})");
        Assert_Equals_Int(_BatRouteOutcomes, 0, "the client raised no OnRouteOutcome");
        Assert_Equals_Int(_BatPerchLost, 0, "the client raised no OnPerchLost");
        Assert_Equals_Int(_BatTargetChanges, 0, "the client raised no OnTargetChanged");
        Finish_BatRow("APatrolRunsItsPhasesAndThePerchReachesTheClient", f"anchorFrame={_AnchorFrame} phaseAtAnchor={_PhaseAtAnchor :n}");
    }
}
