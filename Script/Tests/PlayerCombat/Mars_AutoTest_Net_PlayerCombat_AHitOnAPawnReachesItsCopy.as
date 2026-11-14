// A hit the server lands on a pawn's zone reaches the client's copy of that pawn: 30 Blunt on the server's copy leaves
// both reading 70, and the client's copy raises OnDamaged once with 30 applied and is not depleted.
// Surface: Ck.PlayerCombat.Net.AS_PlayerCombat_AHitOnAPawnReachesItsCopy
class UCk_AutoTest_Net_PlayerCombat_AHitOnAPawnReachesItsCopy : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(531000.0, 0.0, 5000.0);
    private const FString k_Row = "AHitOnAPawnReachesItsCopy";

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
            WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
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
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ZoneHit(30.0f, GameplayTags::DamageType_Mars_Blunt);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAfterHit");
    }

    UFUNCTION()
    private void OnServerHeldAfterHit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
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
        const auto FirstApplied = _Damaged.Num() > 0 ? _Damaged[0] : -1.0f;
        Log_Row(k_Row, f"firstApplied={FirstApplied}");
        Assert_Equals_Float(_Health.Get_Current(), 70.0f, 0.01f, "the client's copy reads 70");
        Assert_Equals_Int(_Damaged.Num(), 1, "the client's copy raised OnDamaged once");
        Assert_Equals_Float(FirstApplied, 30.0f, 0.01f, "with 30 applied");
        Assert_False(_Health.Get_IsDepleted(), "the client's copy is not depleted");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown();
        FinishSuccess();
    }
}
