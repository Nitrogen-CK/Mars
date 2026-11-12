// The client grips its copy of a replicated lever and pulls it: its own handle follows the pull while no engagement has
// replicated, the threshold ends its interaction Succeeded, the engage crosses to the authority, and both machines end
// with the lever active, one engagement and one OnEngaged; the client's handle comes to rest at the end pose.
// Surface: Ck.Control.Net.AS_Control_AClientPullsALeverPastTheThreshold
class UCk_AutoTest_Net_Control_AClientPullsALeverPastTheThreshold : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(118000.0, 0.0, 5000.0);

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
        Assert_False(utils_net::Get_HasAuthority(_Control), "the client's lever has no authority");
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
        WaitUntil(n"Is_InteractionFinished", n"OnClientInteractionFinished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteractionFinished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ActiveOnceAndHandleAtEnd", n"OnClientConverged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ActiveOnceAndHandleAtEnd(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Control.Get_IsActive() && Get_Engagements() == 1 && ck::IsValid(_Mover) && _Mover.Get_Alpha() > 0.99f);
    }

    UFUNCTION()
    private void OnClientConverged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Result = _FinishedResults.Num() > 0 ? _FinishedResults[0] : ECk_SucceededFailed::Failed;
        Log(f"[ControlNetTest] AClientPullsALeverPastTheThreshold client: maxAlphaBeforeEngage {_MaxAlphaBeforeEngage}, finished {_FinishedResults.Num()} first {Result :n}, active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, mover {_Mover.Get_Alpha()}, ensures {Get_NewEnsures()}");
        Assert_True(_MaxAlphaBeforeEngage >= 0.85f, f"the client's handle rose to the threshold before any engagement replicated (got {_MaxAlphaBeforeEngage})");
        Assert_True(_FinishedResults.Num() == 1 && Result == ECk_SucceededFailed::Succeeded,
            f"the client's interaction ended Succeeded once (got {_FinishedResults.Num()}, first {Result :n})");
        Assert_True(_Control.Get_IsActive() && Get_Engagements() == 1, f"the client mirrors active and one engagement (got {_Control.Get_IsActive()}, {Get_Engagements()})");
        Assert_True(_EngagedCount == 1, f"OnEngaged fired once on the client (got {_EngagedCount})");
        Assert_True(_Mover.Get_Alpha() > 0.99f, f"the client's handle rests at the end pose (got {_Mover.Get_Alpha()})");
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
        WaitUntil(n"Is_EngagedOnce", n"OnServerEngaged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEngaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientPullsALeverPastTheThreshold server: active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, manipulating {_Control.Get_IsManipulating()}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsActive(), "the server's lever is active");
        Assert_True(Get_Engagements() == 1, f"the server counts one engagement (got {Get_Engagements()})");
        Assert_True(_EngagedCount == 1, f"OnEngaged fired once on the server (got {_EngagedCount})");
        Assert_False(_Control.Get_IsManipulating(), "the server never gripped");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
