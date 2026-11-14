// Disabling a zone and releasing its hurtboxes are local acts: the client's copy disables and loses its hurtbox, while the
// server's zone stays enabled with its one hurtbox.
// Surface: Ck.HitZone.Net.AS_HitZone_EnableAndReleaseApplyOnTheMachineThatAsks
class UCk_AutoTest_Net_HitZone_EnableAndReleaseApplyOnTheMachineThatAsks : UMars_AutoTestRig_NetHitZone
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(512000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 5.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ZoneTargetFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerTarget();
        WaitUntil(n"Is_ZoneTargetFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ZoneRow("EnableAndReleaseApplyOnTheMachineThatAsks", "");
        Assert_True(_Zone.Get_IsEnabled(), "the server's zone stays enabled");
        Assert_Equals_Int(_Zone.Get_Hurtboxes().Num(), 1, "the server's zone keeps its one hurtbox");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));
        _Zone.Request_ReleaseHurtboxes(FMars_Request_HitZone_ReleaseHurtboxes());
        WaitUntil(n"Is_ClientZoneReleased", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientZoneReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Zone.Get_IsEnabled() == false && _Zone.Get_Hurtboxes().Num() == 0);
    }

    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ZoneRow("EnableAndReleaseApplyOnTheMachineThatAsks", "");
        Assert_False(_Zone.Get_IsEnabled(), "the client's zone reads disabled");
        Assert_Equals_Int(_Zone.Get_Hurtboxes().Num(), 0, "the client's zone has no hurtbox");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
