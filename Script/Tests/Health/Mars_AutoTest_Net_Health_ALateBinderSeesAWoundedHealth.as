// The server's target is born healed for 10 (on a full Health, so it applies nothing) and hit for 30, in its spawn
// frame: the client's copy takes 70, the wound and its LastHit as they stand and raises neither the heal nor the hit;
// a later hit of 10 reaches it as exactly one OnDamaged.
// Surface: Ck.Health.Net.AS_Health_ALateBinderSeesAWoundedHealth
class UCk_AutoTest_Net_Health_ALateBinderSeesAWoundedHealth : UMars_AutoTestRig_NetHealth
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(505000.0, 0.0, 5000.0);
    private const float32 k_WoundedHoldSeconds = 4.0f;

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
        auto Heals = TArray<float32>();
        Heals.Add(10.0f);
        auto Hits = TArray<float32>();
        Hits.Add(30.0f);
        Spawn_ServerBornTarget(Heals, Hits);
        WaitUntil(n"Is_TargetFound", n"OnServerFound", k_SlowPolls);
    }

    // The server finds its target before the spawn frame's drain has run.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerBornWounded", n"OnServerBornWounded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerBornWounded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ledger = Get_Ledger();
        auto Result = OutResult;
        Result.Set(Ledger.DamageSerial == 1 && Ledger.HealSerial == 1);
    }

    UFUNCTION()
    private void OnServerBornWounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
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
        const auto Ledger = Get_Ledger();
        Log_Row("ALateBinderSeesAWoundedHealth", "");
        Assert_Equals_Float(_Health.Get_Current(), 60.0f, 0.01f, "the server's target reads 60");
        Assert_True(Ledger.DamageSerial == 2 && Ledger.HealSerial == 1, "the server's ledger counts two hits and one heal");
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
        const auto First = Get_TargetFirstNotifyLedger();
        const auto FirstFrame = Get_TargetFirstNotifyFrame();
        const auto Ledger = Get_Ledger();
        const auto Line = Describe_TargetFind();
        Log_Row("ALateBinderSeesAWoundedHealth", "");
        Assert_True(Get_TargetInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(_TargetInitialAtFind == EMars_Net_InitialState::Awaited, f"the client found its copy before its ledger's first application ({Line})");
        Assert_True(_TargetNotifyFrames.Num() > 0, f"the client recorded a rep-notify of its copy's ledger ({Line})");
        Assert_True(Math::IsNearlyEqual(First.Current, 70.0f, 0.01f) && First.HealSerial == 1 && First.DamageSerial == 1
            && First.Vitality == EMars_Health_Vitality::Standing, f"the first notify carried the heal and the wound it was born into ({Line})");
        Assert_Equals_Int(_Healed.Num(), Ledger.HealSerial - First.HealSerial, f"the client healed only after its first notify ({Line})");
        Assert_Equals_Int(_Damaged.Num(), Ledger.DamageSerial - First.DamageSerial, f"the client was damaged only after its first notify ({Line})");
        Assert_Equals_Int(Count_DamagedAfter(FirstFrame), _Damaged.Num(), f"every OnDamaged came after the first notify's frame ({Line})");
        if (_Damaged.Num() > 0)
        {
            const auto Last = _Damaged[_Damaged.Num() - 1];
            Assert_Equals_Float(Last.Applied, 10.0f, 0.01f, f"the later hit applied 10 ({Line})");
            Assert_Equals_Float(Last.Remaining, 60.0f, 0.01f, f"the later hit left 60 ({Line})");
        }

        Assert_Equals_Int(_Depleted, 0, f"the client raised no OnDepleted ({Line})");
        Assert_True(_Health.Get_LastHit().IsSet(), "the client's wounded target has a LastHit");
        Assert_Equals_Float(_Health.Get_Current(), 60.0f, 0.01f, "the client's target reads 60");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
