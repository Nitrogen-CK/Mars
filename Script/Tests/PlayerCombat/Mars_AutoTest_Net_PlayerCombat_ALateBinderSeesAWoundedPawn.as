// A pawn wounded as early as the server can wound it, before the client's copy has composed or bound: the client's copy
// comes to read 70 and raises OnDamaged at most once for it.
// Surface: Ck.PlayerCombat.Net.AS_PlayerCombat_ALateBinderSeesAWoundedPawn
class UCk_AutoTest_Net_PlayerCombat_ALateBinderSeesAWoundedPawn : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(534000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const FString k_Row = "ALateBinderSeesAWoundedPawn";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PawnComposed", n"OnComposed", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        if (Get_IsServer())
        {
            // In the continuation that first finds the Health: the client's copy cannot have bound yet.
            Request_ZoneHit(30.0f, GameplayTags::DamageType_Mars_Blunt);
            WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
            return;
        }

        WaitUntil(n"Is_Wounded", n"OnClientWounded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Wounded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCurrent(70.0f));
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row(k_Row, "");
        Assert_Equals_Float(_Health.Get_Current(), 70.0f, 0.01f, "the server's copy reads 70");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        TearDown();
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientWounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row(k_Row, "");
        Assert_Equals_Float(_Health.Get_Current(), 70.0f, 0.01f, "the client's copy reads 70");
        Assert_True(_Damaged.Num() <= 1, f"the client's copy raised OnDamaged at most once (got {_Damaged.Num()})");
        Assert_False(_Health.Get_IsDepleted(), "the client's copy is not depleted");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown();
        FinishSuccess();
    }
}
