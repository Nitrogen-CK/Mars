// The client pulls its copy of a replicated pull chain past the threshold: one engagement. A second crossing (Cross) from
// the subject for the grip already released changes nothing; a new grip by the subject engages again, so both machines
// end at two.
// Surface: Ck.Control.Net.AS_Control_AGripEngagesAtMostOnce
class UCk_AutoTest_Net_Control_AGripEngagesAtMostOnce : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(131000.0, 0.0, 5000.0);

    private int32 _EngagementsAfterRepeat = -1;

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
        WaitUntil(n"Is_EngagedOnce", n"OnClientEngagedOnce", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEngagedOnce(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Fire_GripCue(Get_SubjectEntity(), EMars_Control_GripVerb::Cross);
        WaitSeconds(k_SettleSeconds, n"OnClientRepeatSettled");
    }

    UFUNCTION()
    private void OnClientRepeatSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EngagementsAfterRepeat = Get_Engagements();
        _Interaction = FCk_Handle_Interaction();
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteractingAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteractingAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        WaitUntil(n"Is_Manipulating", n"OnClientGrippedAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGrippedAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_PulledUntilEnded", n"OnClientCrossedAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientCrossedAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EngagedTwice", n"OnClientEngagedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_EngagedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Engagements() >= 2);
    }

    UFUNCTION()
    private void OnClientEngagedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGripEngagesAtMostOnce client: engagementsAfterRepeat {_EngagementsAfterRepeat}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, finished {_FinishedResults.Num()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_EngagementsAfterRepeat == 1, f"a second crossing for the released grip changed nothing (got {_EngagementsAfterRepeat})");
        Assert_True(Get_Engagements() == 2 && _EngagedCount == 2, f"the new grip engaged again (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Control.Get_GripSerial() == 2, f"two grips were granted (got {_Control.Get_GripSerial()})");
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
        WaitUntil(n"Is_EngagedTwice", n"OnServerEngagedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEngagedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGripEngagesAtMostOnce server: engagements {Get_Engagements()}, onEngaged {_EngagedCount}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(Get_Engagements() == 2 && _EngagedCount == 2, f"the server counts two engagements, one per grip (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Control.Get_GripSerial() == 2, f"two grips were granted (got {_Control.Get_GripSerial()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
