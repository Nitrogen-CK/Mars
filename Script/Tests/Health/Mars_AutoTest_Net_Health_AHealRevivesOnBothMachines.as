// The server depletes its target with one hit, then heals it: the client's copy first reads depleted at 0, then revived
// at 40 with one OnHealed (40 applied, 40 left), and raised OnDepleted once in all.
// Surface: Ck.Health.Net.AS_Health_AHealRevivesOnBothMachines
class UCk_AutoTest_Net_Health_AHealRevivesOnBothMachines : UMars_AutoTestRig_NetHealth
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(502000.0, 0.0, 5000.0);
    private const float32 k_DepletedHoldSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_Depleted", n"OnClientDepleted", k_SlowPolls);
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
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerHit(100.0f, k_Base, FVector::UpVector);
        WaitSeconds(k_DepletedHoldSeconds, n"OnServerHeldDepleted");
    }

    UFUNCTION()
    private void OnServerHeldDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Health.Request_Heal(FMars_Request_Health_Heal(40.0f));
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAfterHeal");
    }

    UFUNCTION()
    private void OnServerHeldAfterHeal(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("AHealRevivesOnBothMachines", "");
        Assert_False(_Health.Get_IsDepleted(), "the server's target is revived");
        Assert_Equals_Float(_Health.Get_Current(), 40.0f, 0.01f, "the server's target reads 40");
        Assert_Equals_Int(_Healed.Num(), 1, "the server raised OnHealed once");
        Assert_Equals_Int(_Depleted, 1, "the server raised OnDepleted once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_Depleted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTargetFound() && _Health.Get_IsDepleted());
    }

    UFUNCTION()
    private void OnClientDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Float(_Health.Get_Current(), 0.0f, 0.01f, "the client's target first reads 0");
        WaitUntil(n"Is_Healed", n"OnClientHealed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Healed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Ledger().HealSerial >= 1);
    }

    UFUNCTION()
    private void OnClientHealed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("AHealRevivesOnBothMachines", "");
        Assert_False(_Health.Get_IsDepleted(), "the client's target is revived");
        Assert_Equals_Float(_Health.Get_Current(), 40.0f, 0.01f, "the client's target reads 40");
        Assert_Equals_Int(_Healed.Num(), 1, "the client raised OnHealed exactly once");
        if (_Healed.Num() > 0)
        {
            Assert_Equals_Float(_Healed[0].Applied, 40.0f, 0.01f, "the client's OnHealed applied 40");
            Assert_Equals_Float(_Healed[0].Remaining, 40.0f, 0.01f, "the client's OnHealed left 40");
        }

        Assert_Equals_Int(_Depleted, 1, "the client raised OnDepleted once in all");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
