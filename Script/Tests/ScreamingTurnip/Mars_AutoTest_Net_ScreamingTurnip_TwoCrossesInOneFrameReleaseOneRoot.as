// In one frame the server grants a stand-in a grip on a replicated turnip bed, crosses it, grants it again and crosses
// again: the bed's Control engages twice, but its one charge is spent once, so both machines read one release and one
// root lies near the bed.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_TwoCrossesInOneFrameReleaseOneRoot
class UCk_AutoTest_Net_ScreamingTurnip_TwoCrossesInOneFrameReleaseOneRoot : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(405000.0, 0.0, 5000.0);
    private const float32 k_ComposeSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BedFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_TwiceEngagedAndHarvested", n"OnClientHarvested", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_TwiceEngagedAndHarvested(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Engagements() >= 2 && _Forage.Get_IsExhausted() && Count_RootsNearBed() >= 1);
    }

    UFUNCTION()
    private void OnClientHarvested(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] TwoCrossesInOneFrameReleaseOneRoot client: {Get_BedText()}");
        Assert_True(Get_Engagements() == 2, f"the client reads two engagements (got {Get_Engagements()})");
        Assert_True(_Forage.Get_ReleasedCount() == 1 && _Forage.Get_IsExhausted(),
            f"the client's bed reads one release and is exhausted (got {_Forage.Get_ReleasedCount()})");
        Assert_True(_ReleaseReasons.Num() == 1, f"the client raised OnReleased once (got {_ReleaseReasons.Num()})");
        Assert_True(Count_RootsNearBed() == 1, f"one root lies near the client's bed (got {Count_RootsNearBed()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerBed();
        WaitUntil(n"Is_BedAndStandInFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Cross);
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Cross);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[TurnipNetTest] TwoCrossesInOneFrameReleaseOneRoot server: {Get_BedText()}");
        Assert_True(Get_Engagements() == 2, f"the bed's Control engaged twice (got {Get_Engagements()})");
        Assert_True(_Control.Get_GripSerial() == 2, f"two grips were granted (got {_Control.Get_GripSerial()})");
        Assert_True(_Forage.Get_ReleasedCount() == 1, f"the server released one root (got {_Forage.Get_ReleasedCount()})");
        Assert_True(Count_RootsNearBed() == 1, f"one root lies near the server's bed (got {Count_RootsNearBed()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
