// The server nudges the hand three times, holding each value: after each, the client's ledger hand and its own lateral
// node's offset equal the server's.
// Surface: Ck.Cutting.Net.AS_Cutting_TheHandFollowsTheAuthorityOnTheClient
class UCk_AutoTest_Net_Cutting_TheHandFollowsTheAuthorityOnTheClient : UMars_AutoTestRig_NetCutting
{
    private const FVector k_Location = FVector(108000.0, 0.0, 5000.0);
    private const float32 k_NudgeCm = 7.5f;
    private const int32 k_Steps = 3;
    // How long the server holds each value before the next nudge: the client reads each one.
    private const float32 k_StepHoldSeconds = 1.0f;

    private int32 _Step = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetStationTest();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientAtStep", n"OnClientAtStep", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private float32 Get_StepHand(int32 InStep) const
    {
        return k_NudgeCm * float32(InStep);
    }

    UFUNCTION()
    private void Is_ClientAtStep(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Expected = Get_StepHand(_Step + 1);
        Result.Set(Get_IsCuttingStationFound() && Get_IsNear(_Cutting.Get_HandLateral(), Expected) && Get_IsNear(Get_NodeHand(), Expected));
    }

    UFUNCTION()
    private void OnClientAtStep(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Step += 1;
        if (_Step < k_Steps)
        {
            WaitUntil(n"Is_ClientAtStep", n"OnClientAtStep", k_SlowPolls);
            return;
        }

        Log(f"[CuttingNetTest] TheHandFollowsTheAuthorityOnTheClient client: {k_Steps} of {k_Steps} steps followed, ensures {Get_NewEnsures()}");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCuttingStation(k_Location);
        WaitUntil(n"Is_CuttingStationFound", n"OnServerNudge", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerNudge(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Cutting.Request_Nudge(FMars_Request_Cutting_Nudge(k_NudgeCm));
        WaitUntil(n"Is_ServerAtStep", n"OnServerAtStep", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAtStep(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsNear(_Cutting.Get_HandLateral(), Get_StepHand(_Step + 1)));
    }

    UFUNCTION()
    private void OnServerAtStep(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Step += 1;
        WaitSeconds(k_StepHoldSeconds, _Step < k_Steps ? n"OnServerNudge" : n"OnServerDone");
    }

    UFUNCTION()
    private void OnServerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CuttingNetTest] TheHandFollowsTheAuthorityOnTheClient server: hand {_Cutting.Get_HandLateral()}, node {Get_NodeHand()}, ensures {Get_NewEnsures()}");
        Assert_True(Get_IsNear(_Cutting.Get_HandLateral(), Get_StepHand(k_Steps)), f"the server's hand is {Get_StepHand(k_Steps)} (got {_Cutting.Get_HandLateral()})");
        Assert_True(Get_IsNear(Get_NodeHand(), Get_StepHand(k_Steps)), f"the server's node is at {Get_StepHand(k_Steps)} (got {Get_NodeHand()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
