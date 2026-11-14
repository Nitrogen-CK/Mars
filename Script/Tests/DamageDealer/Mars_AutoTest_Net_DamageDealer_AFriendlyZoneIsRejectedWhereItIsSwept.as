// A target on the dealer's own team: the client's dealer rejects its deal on the target's hurtbox as Friendly on the
// client, counting the rejection and dealing nothing, and the server's target stays full.
// Surface: Ck.DamageDealer.Net.AS_DamageDealer_AFriendlyZoneIsRejectedWhereItIsSwept
class UCk_AutoTest_Net_DamageDealer_AFriendlyZoneIsRejectedWhereItIsSwept : UMars_AutoTestRig_NetHitZone
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(517000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 4.0f;

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
        Spawn_ServerTargetOnTeam(ECk_Team_ID::One);
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
        Log_ZoneRow("AFriendlyZoneIsRejectedWhereItIsSwept", "");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, "the server's target reads 100");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Compose_Dealer();
        Request_DealOnHurtbox(20.0f);
        WaitUntil(n"Is_Answered", n"OnClientAnswered", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Dealt > 0 || _Rejected > 0);
    }

    UFUNCTION()
    private void OnClientAnswered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ZoneRow("AFriendlyZoneIsRejectedWhereItIsSwept", "");
        Assert_Equals_Int(_Rejected, 1, "the client's dealer raised OnDamageRejected once");
        Assert_True(_LastRejectReason.IsSet() && _LastRejectReason.GetValue() == EMars_DamageDealer_RejectReason::Friendly,
            "the client's rejection is Friendly");
        Assert_Equals_Int(_Dealer.Get_HitsRejected(), 1, "the client's dealer counted the rejection");
        Assert_Equals_Int(_Dealt, 0, "the client's dealer raised no OnDamageDealt");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
