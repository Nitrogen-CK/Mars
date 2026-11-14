// The server depletes its dummy (30 hit points, rearm 30 s) in the continuation in which it first finds it, before the
// client's copy can be sure to have composed: the client's copy reads depleted, raised OnDepleted exactly once and its
// body is flattened to 0.2.
// Surface: Ck.TargetDummy.Net.AS_TargetDummy_ALateBinderSeesAFlattenedDummy
class UCk_AutoTest_Net_TargetDummy_ALateBinderSeesAFlattenedDummy : UMars_AutoTestRig_NetTargetDummy
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(563000.0, 0.0, 5000.0);
    private const FString k_Row = "ALateBinderSeesAFlattenedDummy";
    private const float32 k_DummyHitPoints = 30.0f;
    private const float32 k_DepletedHoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TargetDummy(k_Base, k_DummyHitPoints, 30.0f);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_DummyDepleted", n"OnClientDepleted", k_SlowPolls);
            return;
        }

        Start_ServerDummyRow();
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerDummyHit(k_DummyHitPoints);
        WaitSeconds(k_DepletedHoldSeconds, n"OnServerHeldDepleted");
    }

    UFUNCTION()
    private void OnServerHeldDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Health.Get_IsDepleted(), "the server's dummy reads depleted");
        Assert_BodyHeight(k_FlattenedHeight, "the server");
        Finish_DummyRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_DummyDepleted, 1, "the client raised OnDepleted exactly once");
        Assert_BodyHeight(k_FlattenedHeight, "the client");
        Finish_DummyRow(k_Row, "");
    }
}
