// The server depletes its target in the continuation in which it first finds it, before the client's copy can be sure to
// have bound: the client reads it depleted at 0, raised OnDepleted exactly once and OnDamaged at most once.
// Surface: Ck.Health.Net.AS_Health_ALateBinderSeesADepletedHealth
class UCk_AutoTest_Net_Health_ALateBinderSeesADepletedHealth : UMars_AutoTestRig_NetHealth
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(506000.0, 0.0, 5000.0);
    private const float32 k_DepletedHoldSeconds = 4.0f;

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
        Request_ServerHit(100.0f, k_Base, FVector::UpVector);
        WaitSeconds(k_DepletedHoldSeconds, n"OnServerHeldDepleted");
    }

    UFUNCTION()
    private void OnServerHeldDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("ALateBinderSeesADepletedHealth", "");
        Assert_True(_Health.Get_IsDepleted(), "the server's target is depleted");
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
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("ALateBinderSeesADepletedHealth", "");
        Assert_True(_Health.Get_IsDepleted(), "the client's target is depleted");
        Assert_Equals_Float(_Health.Get_Current(), 0.0f, 0.01f, "the client's target reads 0");
        Assert_Equals_Int(_Depleted, 1, "the client raised OnDepleted exactly once");
        Assert_True(_Damaged.Num() <= 1, f"the client raised OnDamaged at most once (got {_Damaged.Num()})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
