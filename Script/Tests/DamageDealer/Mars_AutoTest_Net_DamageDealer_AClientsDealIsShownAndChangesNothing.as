// A dealer the client composes deals on its copy of the target's hurtbox: the client's dealer counts the hit and raises
// OnDamageDealt once naming the root zone, so the blow can be shown there, but the zone without authority drops it: the
// client's zone counts nothing and raises no OnHit, and both machines' Health stays full.
// Surface: Ck.DamageDealer.Net.AS_DamageDealer_AClientsDealIsShownAndChangesNothing
class UCk_AutoTest_Net_DamageDealer_AClientsDealIsShownAndChangesNothing : UMars_AutoTestRig_NetHitZone
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(515000.0, 0.0, 5000.0);
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
        Log_ZoneRow("AClientsDealIsShownAndChangesNothing", "");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the server's target reads 100");
        Assert_Equals_Int(_Zone.Get_HitCount(), 0, "the server's zone counted nothing");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Compose_Dealer();
        Request_DealOnHurtbox(20.0f);
        WaitUntil(n"Is_Dealt", n"OnClientDealt", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Dealt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Dealt > 0 || _Rejected > 0);
    }

    UFUNCTION()
    private void OnClientDealt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Dealer.Get_HitsDealt(), 1, "the client's dealer counted the hit");
        Assert_Equals_Int(_Dealt, 1, "the client's dealer raised OnDamageDealt once");
        Assert_True(_LastDealtZone == _Zone, "the client's OnDamageDealt names its copy's root zone");
        Assert_Equals_Int(_Rejected, 0, "the client's dealer rejected nothing");
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ZoneRow("AClientsDealIsShownAndChangesNothing", f"dealFrame={_DealFrame} dealtFrame={_DealtFrame} frames={_DealtFrame - _DealFrame}");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the client's target still reads 100");
        Assert_Equals_Int(_Zone.Get_HitCount(), 0, "the client's zone counted nothing");
        Assert_Equals_Int(_OnHit, 0, "the client's zone raised no OnHit");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
