// The server asks its monster to Die with a Blunt cause of 5, its body Health untouched: the client's copy reads dead
// while its body Health reads 100 and is not depleted, and raised OnDied once with the Blunt cause.
// Surface: Ck.Monster.Net.AS_Monster_ADeathWithoutDepletionReachesTheClient
class UCk_AutoTest_Net_Monster_ADeathWithoutDepletionReachesTheClient : UMars_AutoTestRig_NetMonster
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(544000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_Dead", n"OnClientDead", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMonster(0);
        WaitUntil(n"Is_MonsterFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_BluntDie(5.0f);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldDead");
    }

    UFUNCTION()
    private void OnServerHeldDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("ADeathWithoutDepletionReachesTheClient", "");
        Assert_True(_Monster.Get_IsDead(), "the server's monster is dead");
        Assert_Equals_Int(_Died, 1, "the server raised OnDied once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("ADeathWithoutDepletionReachesTheClient", "");
        const auto BodyHealth = _Monster.Get_BodyHealth();
        Assert_True(_Monster.Get_IsDead(), "the client's monster is dead");
        Assert_Equals_Float(BodyHealth.Get_Current(), 100.0f, 0.01f, "the client's body Health reads 100");
        Assert_False(BodyHealth.Get_IsDepleted(), "the client's body Health is not depleted");
        Assert_Equals_Int(_Died, 1, "the client raised OnDied once");
        Assert_True(_LastCause.DamageType == GameplayTags::DamageType_Mars_Blunt, "the client's cause is Blunt");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
