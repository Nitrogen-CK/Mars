// A hit the client routes through its own copy of the target's zone is dropped there: no count, no OnHit, no Health
// request, and its requests fragment is gone; the server's target is never touched.
// Surface: Ck.HitZone.Net.AS_HitZone_AClientsHitIsDropped
class UCk_AutoTest_Net_HitZone_AClientsHitIsDropped : UMars_AutoTestRig_NetHitZone
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(511000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

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
        Log_ZoneRow("AClientsHitIsDropped", "");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the server's target reads 100");
        Assert_Equals_Int(_Zone.Get_HitCount(), 0, "the server's zone counted nothing");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ZoneHit(20.0f, GameplayTags::DamageType_Mars_Sever);
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasRequests = _Zone.Has_Fragment(FMars_Fragment_HitZone_Requests);
        Log_ZoneRow("AClientsHitIsDropped", f"hasRequests={HasRequests}");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the client's target reads 100");
        Assert_Equals_Int(_OnHit, 0, "the client's zone raised no OnHit");
        Assert_Equals_Int(_Zone.Get_HitCount(), 0, "the client's zone counted nothing");
        Assert_False(HasRequests, "the client's zone holds no requests");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
