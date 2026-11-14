// A dealer the server composes deals 20 Sever on its target's hurtbox: the server's zone applies it (80) and its dealer
// raises OnDamageDealt once; the client's Health reads 80 from the ledger and raises OnDamaged once.
// Surface: Ck.DamageDealer.Net.AS_DamageDealer_TheServersDealReachesTheClient
class UCk_AutoTest_Net_DamageDealer_TheServersDealReachesTheClient : UMars_AutoTestRig_NetHitZone
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(516000.0, 0.0, 5000.0);

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
        Compose_Dealer();
        Request_DealOnHurtbox(20.0f);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAfterDeal");
    }

    UFUNCTION()
    private void OnServerHeldAfterDeal(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ZoneRow("TheServersDealReachesTheClient", "");
        Assert_Equals_Float(_Health.Get_Current(), 80.0f, 0.01f, "the server's target reads 80");
        Assert_Equals_Int(_Dealt, 1, "the server's dealer raised OnDamageDealt once");
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
        Log_ZoneRow("TheServersDealReachesTheClient", "");
        Assert_Equals_Float(_Health.Get_Current(), 80.0f, 0.01f, "the client's target reads 80");
        Assert_Equals_Int(_Damaged.Num(), 1, "the client raised OnDamaged once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
