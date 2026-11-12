// The client calls Request_Engage and Request_SetActive on its own copy of a replicated lever: its drain drops both, so
// neither machine's ledger moves and no OnEngaged or OnActiveChanged is raised.
// Surface: Ck.Control.Net.AS_Control_AClientsEngageAndSetActiveRequestsAreDropped
class UCk_AutoTest_Net_Control_AClientsEngageAndSetActiveRequestsAreDropped : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(122000.0, 0.0, 5000.0);
    private const float32 k_ClientWindowSeconds = 2.0f;
    private const float32 k_ServerWindowSeconds = 5.0f;

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
        _Control.Request_Engage(FMars_Request_Control_Engage());
        _Control.Request_SetActive(FMars_Request_Control_SetActive(EMars_Control_Activation::Active));
        WaitSeconds(k_ClientWindowSeconds, n"OnClientWindowOver");
    }

    UFUNCTION()
    private void OnClientWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientsEngageAndSetActiveRequestsAreDropped client: active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, activations [{Get_ActivationsText()}], mover {_Mover.Get_Alpha()}, ensures {Get_NewEnsures()}");
        Assert_False(_Control.Get_IsActive(), "the client's lever stayed inactive");
        Assert_True(Get_Engagements() == 0 && _EngagedCount == 0, f"no engagement on the client (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Activations.Num() == 0, f"no OnActiveChanged on the client (got [{Get_ActivationsText()}])");
        Assert_True(_Mover.Get_Alpha() < 0.01f, f"the client's handle never moved (got {_Mover.Get_Alpha()})");
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
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientsEngageAndSetActiveRequestsAreDropped server: active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, activations [{Get_ActivationsText()}], ensures {Get_NewEnsures()}");
        Assert_False(_Control.Get_IsActive(), "the server's lever stayed inactive");
        Assert_True(Get_Engagements() == 0 && _EngagedCount == 0, f"the server counted no engagement (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Activations.Num() == 0, f"no OnActiveChanged on the server (got [{Get_ActivationsText()}])");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
