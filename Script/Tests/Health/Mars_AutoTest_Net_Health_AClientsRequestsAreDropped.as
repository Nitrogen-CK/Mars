// A client that requests a hit, a heal and invulnerability on its own copy of the target changes nothing: its drain drops
// the requests (it has no authority), so the target stays full and vulnerable on both machines and neither raises a
// signal.
// Surface: Ck.Health.Net.AS_Health_AClientsRequestsAreDropped
class UCk_AutoTest_Net_Health_AClientsRequestsAreDropped : UMars_AutoTestRig_NetHealth
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(504000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 5.0f;
    private const float32 k_ClientSettleSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_TargetFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerTarget();
        WaitUntil(n"Is_TargetFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_Untouched();
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Event = FMars_DamageEvent(30.0f, GameplayTags::DamageType_Mars_Sever);
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Event));
        _Health.Request_Heal(FMars_Request_Health_Heal(10.0f));
        _Health.Request_SetInvulnerable(FMars_Request_Health_SetInvulnerable(ECk_EnableDisable::Enable));
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Health.Has_Fragment(FMars_Fragment_Health_Requests), "the client's copy holds no Health requests");
        Check_Untouched();
        FinishSuccess();
    }

    private void Check_Untouched()
    {
        const auto Ledger = Get_Ledger();
        const auto Machine = Get_MachineName();
        Log_Row("AClientsRequestsAreDropped", "");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, f"the {Machine}'s target is still full");
        Assert_False(_Health.Get_IsInvulnerable(), f"the {Machine}'s target is not invulnerable");
        Assert_True(Ledger.DamageSerial == 0 && Ledger.HealSerial == 0 && Ledger.DepletionSerial == 0,
            f"the {Machine}'s ledger counts nothing (d{Ledger.DamageSerial} h{Ledger.HealSerial} x{Ledger.DepletionSerial})");
        Assert_True(_Damaged.Num() == 0 && _Healed.Num() == 0 && _Depleted == 0, f"the {Machine} raised no signal (got {_Order})");
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Machine}");
    }
}
