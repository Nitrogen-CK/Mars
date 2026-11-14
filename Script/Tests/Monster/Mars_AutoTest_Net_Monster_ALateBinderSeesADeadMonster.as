// The server kills its monster (100 on its body Health) in the continuation in which it first finds it, before the
// client's copy can be sure to have composed: the client's copy reads dead, raised OnDied exactly once and its Dead
// attribute reads 1.
// Surface: Ck.Monster.Net.AS_Monster_ALateBinderSeesADeadMonster
class UCk_AutoTest_Net_Monster_ALateBinderSeesADeadMonster : UMars_AutoTestRig_NetMonster
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(542000.0, 0.0, 5000.0);
    private const float32 k_DeadHoldSeconds = 4.0f;

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
        Request_ServerBodyHit(100.0f);
        WaitSeconds(k_DeadHoldSeconds, n"OnServerHeldDead");
    }

    UFUNCTION()
    private void OnServerHeldDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("ALateBinderSeesADeadMonster", "");
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
        Log_Row("ALateBinderSeesADeadMonster", "");
        Assert_True(_Monster.Get_IsDead(), "the client's monster is dead");
        Assert_Equals_Int(_Died, 1, "the client raised OnDied exactly once");
        Assert_Equals_Int(Get_DeadValue(), 1, "the client's Dead attribute reads 1");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
