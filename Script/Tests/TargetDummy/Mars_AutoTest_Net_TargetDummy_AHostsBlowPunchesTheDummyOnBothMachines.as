// The server hits its dummy (100 hit points) for 10: on both machines the Health reads 90, OnDamaged is raised once, the
// dummy is not depleted and the punched body is back at full height; the client's copy holds no Health requests.
// Surface: Ck.TargetDummy.Net.AS_TargetDummy_AHostsBlowPunchesTheDummyOnBothMachines
class UCk_AutoTest_Net_TargetDummy_AHostsBlowPunchesTheDummyOnBothMachines : UMars_AutoTestRig_NetTargetDummy
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(561000.0, 0.0, 5000.0);
    private const FString k_Row = "AHostsBlowPunchesTheDummyOnBothMachines";
    private const float32 k_HitAmount = 10.0f;
    private const float32 k_AfterHit = 90.0f;
    private const float32 k_WatchSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TargetDummy(k_Base, 100.0f, 30.0f);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_DummyAt90", n"OnClientAt90", k_SlowPolls);
            return;
        }

        Start_ServerDummyRow();
    }

    UFUNCTION()
    private void Is_DummyAt90(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDummyFound() && Get_IsCurrent(k_AfterHit));
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerDummyHit(k_HitAmount);
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCurrent(k_AfterHit), "the server's dummy reads 90");
        Assert_Equals_Int(_DummyDamaged, 1, "the server raised OnDamaged once");
        Assert_BodyHeight(k_StandingHeight, "the server");
        Hold_ServerDummyRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientAt90(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_DummyDamaged, 1, "the client raised OnDamaged exactly once");
        Assert_Equals_Int(_DummyDepleted, 0, "the client raised no OnDepleted");
        Assert_BodyHeight(k_StandingHeight, "the client");
        Assert_False(Get_HasHealthRequests(), "the client's copy holds no Health requests");
        Finish_DummyRow(k_Row, "");
    }
}
