// A hit the server applies to its target reaches the client: the client's copy reads the server's current value and
// raises OnDamaged once with the server's applied and remaining values, its damage type and where it landed, naming no
// instigator; its LastHit carries the amount, and nothing depleted.
// Surface: Ck.Health.Net.AS_Health_AServersHitReachesTheClient
class UCk_AutoTest_Net_Health_AServersHitReachesTheClient : UMars_AutoTestRig_NetHealth
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(500000.0, 0.0, 5000.0);
    private const FVector k_HitOffset = FVector(12.0, -7.0, 40.0);
    private const FVector k_HitNormal = FVector(1.0, 0.0, 0.0);

    private int32 _HitFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_HitInTheLedger", n"OnClientHitArrived", k_SlowPolls);
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
        _HitFrame = int32(utils_time::Get_FrameCounter());
        Request_ServerHit(30.0f, k_Base + k_HitOffset, k_HitNormal);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAfterHit");
    }

    UFUNCTION()
    private void OnServerHeldAfterHit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("AServersHitReachesTheClient", f"hitFrame={_HitFrame}");
        Assert_Equals_Float(_Health.Get_Current(), 70.0f, 0.01f, "the server's target reads 70");
        Assert_Equals_Int(_Damaged.Num(), 1, "the server raised OnDamaged once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_HitInTheLedger(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTargetFound() && Get_Ledger().DamageSerial == 1);
    }

    UFUNCTION()
    private void OnClientHitArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto DamagedFrame = _Damaged.Num() > 0 ? _Damaged[0].Frame : -1;
        Log_Row("AServersHitReachesTheClient", f"damagedFrame={DamagedFrame}");

        Assert_False(utils_net::Get_HasAuthority(_Target), "the client's target has no authority");
        Assert_Equals_Float(_Health.Get_Current(), 70.0f, 0.01f, "the client's target reads 70");
        Assert_Equals_Int(_Damaged.Num(), 1, "the client raised OnDamaged exactly once");
        if (_Damaged.Num() > 0)
        {
            const auto Record = _Damaged[0];
            Assert_Equals_Float(Record.Applied, 30.0f, 0.01f, "the client's OnDamaged applied 30");
            Assert_Equals_Float(Record.Remaining, 70.0f, 0.01f, "the client's OnDamaged left 70");
            Assert_True(Record.Event.DamageType == GameplayTags::DamageType_Mars_Sever, "the client's OnDamaged is Sever");
            Assert_True((Record.Event.Hit.Location - (k_Base + k_HitOffset)).Size() < 1.0,
                f"the client's OnDamaged landed where the server's hit did (got {Record.Event.Hit.Location})");
            Assert_True(ck::Is_NOT_Valid(Record.Event.Source.Instigator), "the client's OnDamaged names no instigator");
        }

        const auto LastHit = _Health.Get_LastHit();
        Assert_True(LastHit.IsSet() && Math::IsNearlyEqual(LastHit.GetValue().Amount, 30.0f, 0.01f), "the client's LastHit carries 30");
        Assert_False(_Health.Get_IsDepleted(), "the client's target is not depleted");
        Assert_Equals_Int(_Depleted, 0, "the client raised no OnDepleted");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
