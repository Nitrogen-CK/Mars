// The server lights a candle from a second, lit one and then snuffs it; on the client the candle's Get_IsLit follows,
// OnLitChanged is raised once per change and the Burning tag follows, with no ensure.
// Surface: Ck.Flame.Net.AS_Flame_AServersIgnitionReachesTheClient
class UCk_AutoTest_Net_Flame_AServersIgnitionReachesTheClient : UMars_AutoTestRig_NetFlame
{
    private const FVector k_FloorTop = FVector(58000.0, 0.0, 5000.0);
    private const FVector k_CandleOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_SourceOffset = FVector(200.0, 100.0, 0.0);

    private FCk_Handle_Flame _Candle;
    private FCk_Handle_Flame _Source;
    private bool _ClientSawBurningWhileLit = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetFlame(InHandle, k_FloorTop, 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_CandleFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_CandleFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Find_Candle(k_CandleOffset, _Candle) && Find_Candle(k_SourceOffset, _Source));
    }

    UFUNCTION()
    private void Is_CandleLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Candle) && _Candle.Get_IsLit());
    }

    UFUNCTION()
    private void Is_CandleOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Candle) && _Candle.Get_IsLit() == false);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCandle(k_CandleOffset, EMars_Flame_Ignition::Snuffed);
        Spawn_ServerCandle(k_SourceOffset, EMars_Flame_Ignition::Lit);
        WaitUntil(n"Is_CandleFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientCatchUpSeconds, n"OnServerLight");
    }

    UFUNCTION()
    private void OnServerLight(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Candle.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, _Source));
        WaitUntil(n"Is_CandleLit", n"OnServerLit", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientCatchUpSeconds, n"OnServerSnuff");
    }

    UFUNCTION()
    private void OnServerSnuff(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Candle.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Snuffed));
        WaitUntil(n"Is_CandleOut", n"OnServerOut", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Candle.Get_IsLit(), "the client's candle starts unlit");
        Watch_Signals(_Candle);
        WaitUntil(n"Is_CandleLit", n"OnClientLit", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientSawBurningWhileLit = Get_IsBurningTagged(_Candle);
        WaitUntil(n"Is_CandleOut", n"OnClientOut", k_SlowPolls);
    }

    // The tag's removal is deferred a frame.
    UFUNCTION()
    private void OnClientOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(3, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto TaggedAfter = Get_IsBurningTagged(_Candle);
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[FlameNetTest] server ignition reached the client litChanges={_LitChanges} burningWhileLit={_ClientSawBurningWhileLit} burningAfter={TaggedAfter} newEnsures={NewEnsures}");
        Assert_Equals_Int(_LitChanges, 2, "the client raised OnLitChanged once for the light and once for the snuff");
        Assert_True(_ClientSawBurningWhileLit, "the client's candle carries the Burning tag while lit");
        Assert_False(TaggedAfter, "the client's candle drops the Burning tag once out");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
