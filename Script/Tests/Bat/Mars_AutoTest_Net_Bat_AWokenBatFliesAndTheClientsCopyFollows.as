// Prey stands within reach of a roosting Cellar Bat on the server: the bat takes it as its target, wakes, launches and
// flies at it (Alert, Launching, Approaching). The client's copy, its script ticking, shows the same three phases in
// that order from the ledger, follows its replicated root without a jump (no step of 150 or more between two samples,
// never farther than 1300 from the hang point) and measures its own speed (above 150) and turn from that root; it holds
// no target and raises no OnTargetChanged, OnRouteOutcome or OnSwoopLanded.
// Surface: Ck.Bat.Net.AS_Bat_AWokenBatFliesAndTheClientsCopyFollows
class UCk_AutoTest_Net_Bat_AWokenBatFliesAndTheClientsCopyFollows : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(661000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(-500.0, 300.0, 0.0);
    private const float64 k_Away = 250.0;
    private const float32 k_ServerWatchSeconds = 2.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_Floor);
        _WithVisuals = true;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerWorld(n"OnServerReady");
    }

    private TArray<EMars_Bat_Phase> Get_WakeOrder() const
    {
        auto Order = TArray<EMars_Bat_Phase>();
        Order.Add(EMars_Bat_Phase::Alert);
        Order.Add(EMars_Bat_Phase::Launching);
        Order.Add(EMars_Bat_Phase::Approaching);
        return Order;
    }

    UFUNCTION()
    private void Is_ApproachingAway(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_Phase() == EMars_Bat_Phase::Approaching && Get_BatFromHang() > k_Away);
    }

    UFUNCTION()
    private void Is_CopyAway(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && Get_BatFromHang() > k_Away);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_ApproachingAway", n"OnServerApproaching", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerApproaching(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_BatTargetChanges >= 1, "the server raised OnTargetChanged at least once");
        Assert_True(_Bat.Get_Target() == _PreyEntity, "the server's bat targets the prey");
        Assert_True(Get_SawPhasesInOrder(Get_WakeOrder()), f"the server recorded Alert, Launching, Approaching (saw {Describe_BatPhases()})");
        Hold_BatServerRow("AWokenBatFliesAndTheClientsCopyFollows", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting, "the client found its copy roosting");
        WaitUntil(n"Is_CopyAway", n"OnClientAway", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAway(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_SawPhasesInOrder(Get_WakeOrder()), f"the client recorded Alert, Launching, Approaching (saw {Describe_BatPhases()})");
        Assert_True(_BatHighestSpeed > 150.0f, f"the client measured a speed above 150 (highest {_BatHighestSpeed})");
        Assert_True(_BatLargestTurnRate > 0.0f, "the client measured a turn");
        Assert_True(_BatLargestStep < 150.0, f"the client's root never stepped 150 or more (largest {_BatLargestStep})");
        Assert_True(_BatFarthestFromHang <= 1300.0, f"the client's root stayed within 1300 of the hang point (farthest {_BatFarthestFromHang})");
        Assert_False(ck::IsValid(_Bat.Get_Target()), "the client's copy holds no target");
        Assert_Equals_Int(_BatTargetChanges, 0, "the client raised no OnTargetChanged");
        Assert_Equals_Int(_BatRouteOutcomes, 0, "the client raised no OnRouteOutcome");
        Assert_Equals_Int(_BatSwoopsLanded, 0, "the client raised no OnSwoopLanded");
        Finish_BatRow("AWokenBatFliesAndTheClientsCopyFollows", "");
    }
}
