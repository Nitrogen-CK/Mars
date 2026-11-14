// Two lethal hits the server applies in one frame deplete its target once; the client's copy reads depleted at 0 and
// raises OnDepleted exactly once, after its OnDamaged.
// Surface: Ck.Health.Net.AS_Health_ALethalHitDepletesOnBothMachines
class UCk_AutoTest_Net_Health_ALethalHitDepletesOnBothMachines : UMars_AutoTestRig_NetHealth
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(501000.0, 0.0, 5000.0);

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
        Request_ServerHit(60.0f, k_Base, FVector::UpVector);
        Request_ServerHit(60.0f, k_Base, FVector::UpVector);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAfterHits");
    }

    UFUNCTION()
    private void OnServerHeldAfterHits(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_Ledger();
        Log_Row("ALethalHitDepletesOnBothMachines", "");
        Assert_True(_Health.Get_IsDepleted(), "the server's target is depleted");
        Assert_Equals_Int(_Depleted, 1, "the server raised OnDepleted once");
        Assert_Equals_Int(Ledger.DepletionSerial, 1, "the server's ledger counts one depletion");
        Assert_Equals_Int(Ledger.DamageSerial, 2, "the server's ledger counts two damages");
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
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("ALethalHitDepletesOnBothMachines", "");
        Assert_True(_Health.Get_IsDepleted(), "the client's target is depleted");
        Assert_Equals_Float(_Health.Get_Current(), 0.0f, 0.01f, "the client's target reads 0");
        Assert_Equals_Int(_Depleted, 1, "the client raised OnDepleted exactly once");
        Assert_True(_Damaged.Num() == 1 || _Damaged.Num() == 2, f"the client raised OnDamaged once or twice (got {_Damaged.Num()})");
        Assert_True(_Order.EndsWith("DX"), f"the client's signals end with a damage then the depletion (got {_Order})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
