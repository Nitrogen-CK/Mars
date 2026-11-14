// The server depletes its monster's body Health with 100 Sever: both machines read it dead, its Dead attribute at 1, and
// each raised OnDied exactly once; the client's cause is the Sever hit of 100 and its body Health reads depleted.
// Surface: Ck.Monster.Net.AS_Monster_ABodyDepletionKillsTheMonsterOnBothMachines
class UCk_AutoTest_Net_Monster_ABodyDepletionKillsTheMonsterOnBothMachines : UMars_AutoTestRig_NetMonster
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(540000.0, 0.0, 5000.0);
    private int32 _HitFrame = -1;

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
        _HitFrame = int32(utils_time::Get_FrameCounter());
        Request_ServerBodyHit(100.0f);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldDead");
    }

    UFUNCTION()
    private void OnServerHeldDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Extra = f"hitFrame={_HitFrame}";
        Log_Row("ABodyDepletionKillsTheMonsterOnBothMachines", Extra);
        Assert_True(_Monster.Get_IsDead(), "the server's monster is dead");
        Assert_Equals_Int(Get_DeadValue(), 1, "the server's Dead attribute reads 1");
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
        Log_Row("ABodyDepletionKillsTheMonsterOnBothMachines", "");
        Assert_True(_Monster.Get_IsDead(), "the client's monster is dead");
        Assert_Equals_Int(Get_DeadValue(), 1, "the client's Dead attribute reads 1");
        Assert_Equals_Int(_Died, 1, "the client raised OnDied exactly once");
        Assert_True(Get_IsLastCause(GameplayTags::DamageType_Mars_Sever, 100.0f), "the client's cause is the Sever hit of 100");
        Assert_True(_Monster.Get_BodyHealth().Get_IsDepleted(), "the client's body Health is depleted");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
