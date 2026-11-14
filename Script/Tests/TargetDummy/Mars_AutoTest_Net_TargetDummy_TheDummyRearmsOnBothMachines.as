// The server depletes its dummy (30 hit points, rearm 2 s): on both machines it flattens, then the server's rearm heals it
// back to 30 and both machines stand it up from OnHealed, each having raised OnDepleted once and OnHealed once; the
// client's copy stands up only once its Health reads 30 and holds no Health requests.
// Surface: Ck.TargetDummy.Net.AS_TargetDummy_TheDummyRearmsOnBothMachines
class UCk_AutoTest_Net_TargetDummy_TheDummyRearmsOnBothMachines : UMars_AutoTestRig_NetTargetDummy
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(562000.0, 0.0, 5000.0);
    private const FString k_Row = "TheDummyRearmsOnBothMachines";
    private const float32 k_DummyHitPoints = 30.0f;
    private const float32 k_RearmSeconds = 2.0f;
    private const float32 k_WatchSeconds = 2.0f;

    // Set when this machine's body read standing while its Health still read depleted.
    private bool _StoodUpWhileDepleted = false;
    private bool _SeenFlattened = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TargetDummy(k_Base, k_DummyHitPoints, k_RearmSeconds);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_DummyDepleted", n"OnClientDepleted", k_SlowPolls);
            return;
        }

        Start_ServerDummyRow();
    }

    UFUNCTION()
    private void Is_DummyRearmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto IsStanding = Get_BodyHeight() > (k_FlattenedHeight + k_StandingHeight) * 0.5;
        if (IsStanding == false)
        { _SeenFlattened = true; }

        if (_Health.Get_IsDepleted() && IsStanding && _SeenFlattened)
        { _StoodUpWhileDepleted = true; }

        Result.Set(Get_IsCurrent(k_DummyHitPoints) && _Health.Get_IsDepleted() == false);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerDummyHit(k_DummyHitPoints);
        WaitUntil(n"Is_DummyDepleted", n"OnServerDepleted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_DummyRearmed", n"OnServerRearmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRearmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_DummyDepleted, 1, "the server raised OnDepleted once");
        Assert_Equals_Int(_DummyHealed, 1, "the server raised OnHealed once");
        Assert_BodyHeight(k_StandingHeight, "the server");
        Hold_ServerDummyRow(k_Row, f"seenFlattened={_SeenFlattened} stoodUpWhileDepleted={_StoodUpWhileDepleted}");
    }

    UFUNCTION()
    private void OnClientDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_DummyRearmed", n"OnClientRearmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRearmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_DummyDepleted, 1, "the client raised OnDepleted exactly once");
        Assert_Equals_Int(_DummyHealed, 1, "the client raised OnHealed exactly once");
        Assert_BodyHeight(k_StandingHeight, "the client");
        Assert_False(Get_HasHealthRequests(), "the client's copy holds no Health requests");
        Assert_False(_StoodUpWhileDepleted, "the client's dummy stood up only once its Health read 30");
        Finish_DummyRow(k_Row, f"seenFlattened={_SeenFlattened} stoodUpWhileDepleted={_StoodUpWhileDepleted}");
    }
}
