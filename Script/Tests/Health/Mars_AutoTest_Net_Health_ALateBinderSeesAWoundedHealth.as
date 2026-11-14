// The server hits its target in the continuation in which it first finds it, before the client's copy can be sure to
// have bound: the client reads the wound as it stands (70, a LastHit, at most one OnDamaged), and a later hit reaches it
// as exactly one more OnDamaged.
// Surface: Ck.Health.Net.AS_Health_ALateBinderSeesAWoundedHealth
class UCk_AutoTest_Net_Health_ALateBinderSeesAWoundedHealth : UMars_AutoTestRig_NetHealth
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(505000.0, 0.0, 5000.0);
    private const float32 k_WoundedHoldSeconds = 4.0f;

    private int32 _DamagedAtWound = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_Wounded", n"OnClientWounded", k_SlowPolls);
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
        Request_ServerHit(30.0f, k_Base, FVector::UpVector);
        WaitSeconds(k_WoundedHoldSeconds, n"OnServerHeldWounded");
    }

    UFUNCTION()
    private void OnServerHeldWounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerHit(10.0f, k_Base, FVector::UpVector);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAfterHit");
    }

    UFUNCTION()
    private void OnServerHeldAfterHit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("ALateBinderSeesAWoundedHealth", "");
        Assert_Equals_Float(_Health.Get_Current(), 60.0f, 0.01f, "the server's target reads 60");
        Assert_Equals_Int(_Damaged.Num(), 2, "the server raised OnDamaged twice");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_Wounded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTargetFound() && Get_IsCurrent(70.0f));
    }

    UFUNCTION()
    private void OnClientWounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _DamagedAtWound = _Damaged.Num();
        Assert_True(_DamagedAtWound <= 1, f"the client raised OnDamaged at most once for the first hit (got {_DamagedAtWound})");
        Assert_True(_Health.Get_LastHit().IsSet(), "the client's wounded target has a LastHit");
        WaitUntil(n"Is_HitAgain", n"OnClientHitAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_HitAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Ledger().DamageSerial >= 2);
    }

    UFUNCTION()
    private void OnClientHitAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("ALateBinderSeesAWoundedHealth", f"damagedAtWound={_DamagedAtWound}");
        Assert_Equals_Float(_Health.Get_Current(), 60.0f, 0.01f, "the client's target reads 60");
        Assert_Equals_Int(_Damaged.Num(), _DamagedAtWound + 1, "the second hit raised exactly one more OnDamaged on the client");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
