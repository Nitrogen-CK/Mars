// The client asks its copy of an unlit candle directly for a Lit from a lit one beside it; its drain has no authority and
// drops it, so after a settle the candle is unlit on both machines.
// Surface: Ck.Flame.Net.AS_Flame_AClientsDirectRequestIsDropped
class UCk_AutoTest_Net_Flame_AClientsDirectRequestIsDropped : UMars_AutoTestRig_NetFlame
{
    private const FVector k_FloorTop = FVector(65000.0, 0.0, 5000.0);
    private const FVector k_CandleOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_SourceOffset = FVector(200.0, 100.0, 0.0);

    private FCk_Handle_Flame _Candle;
    private FCk_Handle_Flame _Source;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetFlame(InHandle, k_FloorTop, 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_CandlesReady", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // Both candles are found on this machine and the source burns.
    UFUNCTION()
    private void Is_CandlesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Find_Candle(k_CandleOffset, _Candle) && Find_Candle(k_SourceOffset, _Source) && _Source.Get_IsLit());
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCandle(k_CandleOffset, EMars_Flame_Ignition::Snuffed);
        Spawn_ServerCandle(k_SourceOffset, EMars_Flame_Ignition::Lit);
        WaitUntil(n"Is_CandlesReady", n"OnServerReady", k_SlowPolls);
    }

    // Long enough for the client to find both, ask, and settle.
    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientCatchUpSeconds + k_SettleSeconds + 2.0f, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Candle.Get_IsLit(), "the server's candle stays unlit");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Candle.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, _Source));
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[FlameNetTest] client's direct request dropped candleLit={_Candle.Get_IsLit()} newEnsures={NewEnsures}");
        Assert_False(_Candle.Get_IsLit(), "the client's candle stays unlit");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
