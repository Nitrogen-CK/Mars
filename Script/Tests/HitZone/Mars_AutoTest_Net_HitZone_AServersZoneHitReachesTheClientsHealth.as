// A hit the server routes through its target's zone (20 Crush, x1.5 on the Body zone) lands 30 on the server's Health,
// counts once and raises OnHit once there; the client's Health reads the server's 70 from the ledger, while its own zone
// counted nothing and raised no OnHit.
// Surface: Ck.HitZone.Net.AS_HitZone_AServersZoneHitReachesTheClientsHealth
class UCk_AutoTest_Net_HitZone_AServersZoneHitReachesTheClientsHealth : UMars_AutoTestRig_NetHitZone
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(510000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_HitInTheLedger", n"OnClientHitArrived", k_SlowPolls);
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
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ZoneHit(20.0f, GameplayTags::DamageType_Mars_Crush);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAfterHit");
    }

    UFUNCTION()
    private void OnServerHeldAfterHit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ZoneRow("AServersZoneHitReachesTheClientsHealth", "");
        Assert_Equals_Float(_Health.Get_Current(), 70.0f, 0.01f, "the server's target reads 70");
        Assert_Equals_Int(_Zone.Get_HitCount(), 1, "the server's zone counted the hit");
        Assert_Equals_Int(_OnHit, 1, "the server's zone raised OnHit once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_HitInTheLedger(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsZoneTargetFound() && Get_Ledger().DamageSerial == 1);
    }

    UFUNCTION()
    private void OnClientHitArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ZoneRow("AServersZoneHitReachesTheClientsHealth", "");
        Assert_False(utils_net::Get_HasAuthority(_Target), "the client's target has no authority");
        Assert_Equals_Float(_Health.Get_Current(), 70.0f, 0.01f, "the client's target reads 70");
        Assert_Equals_Int(_Zone.Get_HitCount(), 0, "the client's own zone counted nothing");
        Assert_Equals_Int(_OnHit, 0, "the client's own zone raised no OnHit");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
