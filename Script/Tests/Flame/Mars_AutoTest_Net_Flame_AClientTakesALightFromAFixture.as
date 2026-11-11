// A lit candle and the subject holding an unlit torch; the client reads TakeLight at the candle and fires Act(TakeLight) at
// it, and on both machines the torch is lit.
// Surface: Ck.Flame.Net.AS_Flame_AClientTakesALightFromAFixture
class UCk_AutoTest_Net_Flame_AClientTakesALightFromAFixture : UMars_AutoTestRig_NetFlame
{
    private const FVector k_FloorTop = FVector(62000.0, 0.0, 5000.0);
    private const FVector k_CandleOffset = FVector(200.0, 0.0, 0.0);

    private FCk_Handle_Flame _Candle;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetFlame(InHandle, k_FloorTop, 1);
        _HoldDefinition = mars_items::Torch();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_TorchHeldAndLitCandleFound", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_TorchHeldAndLitCandleFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsItemHeld() && Find_Candle(k_CandleOffset, _Candle) && _Candle.Get_IsLit());
    }

    UFUNCTION()
    private void Is_TorchLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_HeldFlame) && _HeldFlame.Get_IsLit());
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFlameItem(mars_items::Torch());
        Spawn_ServerCandle(k_CandleOffset, EMars_Flame_Ignition::Lit);
        WaitUntil(n"Is_ServerItemLinked", n"OnServerLinked", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLinked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        PickUp_ServerItem();
        WaitUntil(n"Is_TorchHeldAndLitCandleFound", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_TorchLit", n"OnServerTorchLit", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerTorchLit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Candle.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_Flame_Action::TakeLight, f"the client reads TakeLight at the candle (got [{Action :n}])");
        utils_flame::Request_ActFor(_Candle, Get_SubjectEntity(), EMars_Flame_Verb::TakeLight);
        WaitUntil(n"Is_TorchLit", n"OnClientTorchLit", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientTorchLit(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[FlameNetTest] client took a light from a candle torchLit={_HeldFlame.Get_IsLit()} candleLit={_Candle.Get_IsLit()} newEnsures={NewEnsures}");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
