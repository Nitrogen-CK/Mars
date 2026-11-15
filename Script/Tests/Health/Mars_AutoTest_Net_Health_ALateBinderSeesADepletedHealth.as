// The server's target is born hit for 100 in its spawn frame: the client's copy takes it depleted at 0 as it stands,
// raises OnDepleted exactly once, in its first notify's frame (a depletion that stands is announced), and no OnDamaged.
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
        auto Hits = TArray<float32>();
        Hits.Add(100.0f);
        Spawn_ServerBornTarget(TArray<float32>(), Hits);
        WaitUntil(n"Is_TargetFound", n"OnServerFound", k_SlowPolls);
    }

    // The server finds its target before the spawn frame's drain has run.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerBornDepleted", n"OnServerBornDepleted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerBornDepleted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ledger = Get_Ledger();
        auto Result = OutResult;
        Result.Set(Ledger.DamageSerial == 1 && Ledger.DepletionSerial == 1);
    }

    UFUNCTION()
    private void OnServerBornDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_DepletedHoldSeconds, n"OnServerHeldDepleted");
    }

    UFUNCTION()
    private void OnServerHeldDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_Ledger();
        Log_Row("ALateBinderSeesADepletedHealth", "");
        Assert_True(_Health.Get_IsDepleted(), "the server's target is depleted");
        Assert_True(Ledger.DamageSerial == 1 && Ledger.DepletionSerial == 1 && Ledger.Vitality == EMars_Health_Vitality::Depleted,
            "the server's ledger counts one hit and one depletion and reads Depleted");
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
        const auto First = Get_TargetFirstNotifyLedger();
        const auto FirstFrame = Get_TargetFirstNotifyFrame();
        const auto Ledger = Get_Ledger();
        const auto Line = Describe_TargetFind();
        Log_Row("ALateBinderSeesADepletedHealth", "");
        Assert_True(Get_TargetInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(_TargetInitialAtFind == EMars_Net_InitialState::Awaited, f"the client found its copy before its ledger's first application ({Line})");
        Assert_True(_TargetNotifyFrames.Num() > 0, f"the client recorded a rep-notify of its copy's ledger ({Line})");
        Assert_True(Math::IsNearlyEqual(First.Current, 0.0f, 0.01f) && First.DamageSerial == 1 && First.DepletionSerial == 1
            && First.Vitality == EMars_Health_Vitality::Depleted, f"the first notify carried the depletion it was born into ({Line})");
        Assert_Equals_Int(_Depleted, 1, f"the client raised OnDepleted exactly once ({Line})");
        Assert_True(_DepletedFrames.Num() == 1 && _DepletedFrames[0] == FirstFrame, f"the client raised OnDepleted in its first notify's frame ({Line})");
        Assert_Equals_Int(_Damaged.Num(), Ledger.DamageSerial - First.DamageSerial, f"the client was damaged only after its first notify ({Line})");
        Assert_Equals_Int(_Healed.Num(), 0, f"the client raised no OnHealed ({Line})");
        Assert_True(_Health.Get_LastHit().IsSet(), "the client's depleted target has a LastHit");
        Assert_True(_Health.Get_IsDepleted(), "the client's target is depleted");
        Assert_Equals_Float(_Health.Get_Current(), 0.0f, 0.01f, "the client's target reads 0");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
