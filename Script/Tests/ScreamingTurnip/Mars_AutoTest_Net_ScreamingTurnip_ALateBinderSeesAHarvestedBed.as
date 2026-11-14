// The server's stand-in grips and crosses a replicated turnip bed in the frame the server first finds it, before the
// client's copy composed. The client waits until its copy reads the bed exhausted with one engagement and forgets what
// it recorded until then: its target is claimed for Exhausted, and the stand-in's later grip raises
// OnGripHolderChanged to AnotherMachine once while no OnReleased, OnExhausted or OnEngaged follows.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_ALateBinderSeesAHarvestedBed
class UCk_AutoTest_Net_ScreamingTurnip_ALateBinderSeesAHarvestedBed : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(408000.0, 0.0, 5000.0);
    private const float32 k_HarvestedHoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientFoundHarvested", n"OnClientFoundHarvested", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientFoundHarvested(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBedFound() && Get_IsStandInFound() && _Forage.Get_IsExhausted() && Get_Engagements() == 1);
    }

    UFUNCTION()
    private void OnClientFoundHarvested(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Clear_Record();
        WaitUntil(n"Is_GrippedByStandIn", n"OnClientSawLastGrip", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawLastGrip(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] ALateBinderSeesAHarvestedBed client: {Get_BedText()}");
        Assert_True(_Interactable.Get_IsDisabledFor(EMars_Interactable_DisableReason::Exhausted), "the client's target is claimed for Exhausted");
        Assert_True(Count_HolderChangesTo(EMars_Control_GripHolder::AnotherMachine) == 1,
            f"the stand-in's last grip raised OnGripHolderChanged to AnotherMachine once (got [{Get_HolderChangesText()}])");
        Assert_True(_ReleaseReasons.Num() == 0 && _ExhaustedCount == 0 && _EngagedCount == 0,
            f"no OnReleased, OnExhausted or OnEngaged since the bed was found harvested (got {_ReleaseReasons.Num()}, {_ExhaustedCount}, {_EngagedCount})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        WaitUntil(n"Is_StandInFound", n"OnServerStandInFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStandInFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBed();
        WaitUntil(n"Is_BedFound", n"OnServerBedFound", k_SlowPolls);
    }

    // The client's copy has not composed yet: what it finds is the bed as it stands.
    UFUNCTION()
    private void OnServerBedFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Cross);
        WaitSeconds(k_HarvestedHoldSeconds, n"OnServerHeldHarvested");
    }

    UFUNCTION()
    private void OnServerHeldHarvested(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] ALateBinderSeesAHarvestedBed server: {Get_BedText()}");
        Assert_True(_Forage.Get_ReleasedCount() == 1 && Get_Engagements() == 1,
            f"the server released one root on one engagement (got {_Forage.Get_ReleasedCount()}, {Get_Engagements()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
