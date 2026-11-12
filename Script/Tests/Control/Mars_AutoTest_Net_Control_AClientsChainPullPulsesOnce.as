// The client pulls its copy of a replicated pull chain (Momentary, returns to rest) past the threshold: its handle springs
// back at once, the server counts one engagement and its active state rises then falls, and the client mirrors the one
// engagement with its handle at rest.
// Surface: Ck.Control.Net.AS_Control_AClientsChainPullPulsesOnce
class UCk_AutoTest_Net_Control_AClientsChainPullPulsesOnce : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(121000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PullChainFound", n"OnClientFound", k_SlowPolls);
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
        WaitUntil(n"Is_Manipulating", n"OnClientGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_PulledUntilEnded", n"OnClientCrossed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientCrossed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EngagedOnceAndAtRest", n"OnClientConverged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_EngagedOnceAndAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Engagements() == 1 && _Control.Get_IsActive() == false && _Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    private void OnClientConverged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientsChainPullPulsesOnce client: maxAlphaBeforeEngage {_MaxAlphaBeforeEngage}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, active {_Control.Get_IsActive()}, activations [{Get_ActivationsText()}], mover {_Mover.Get_Alpha()}, ensures {Get_NewEnsures()}");
        Assert_True(_MaxAlphaBeforeEngage >= 0.85f, f"the client's chain reached the threshold before any engagement replicated (got {_MaxAlphaBeforeEngage})");
        Assert_True(Get_Engagements() == 1 && _EngagedCount == 1, f"the client mirrors one engagement (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Mover.Get_Alpha() < 0.01f, f"the client's handle is back at rest (got {_Mover.Get_Alpha()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPullChain(k_Location);
        WaitUntil(n"Is_PullChainFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_PulsedAndReleased", n"OnServerPulsed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_PulsedAndReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Engagements() >= 1 && _Activations.Num() >= 2);
    }

    UFUNCTION()
    private void OnServerPulsed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientsChainPullPulsesOnce server: engagements {Get_Engagements()}, onEngaged {_EngagedCount}, active {_Control.Get_IsActive()}, activations [{Get_ActivationsText()}], ensures {Get_NewEnsures()}");
        Assert_True(Get_Engagements() == 1 && _EngagedCount == 1, f"the server counts one engagement (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Activations.Num() == 2 && _Activations[0] == EMars_Control_Activation::Active && _Activations[1] == EMars_Control_Activation::Inactive,
            f"the server's chain rose then fell (got [{Get_ActivationsText()}])");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
