// A lit lantern of one-second measures lying on the floor: its MeasuresLeft falls on both machines, the client's own
// measure clock never runs, and the client raises OnMeasuresChanged once for each fall it sees.
// Surface: Ck.Flame.Net.AS_Flame_FuelBurnsOnTheAuthorityOnly
class UCk_AutoTest_Net_Flame_FuelBurnsOnTheAuthorityOnly : UMars_AutoTestRig_NetFlame
{
    private const FVector k_FloorTop = FVector(59000.0, 0.0, 5000.0);
    // The falls each machine waits to see.
    private const int32 k_Falls = 3;

    private FCk_Handle_Flame _Flame;
    private int32 _StartMeasures = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetFlame(InHandle, k_FloorTop, 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientFlameLit", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFlameComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Flame = _Rock.As_Flame(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Flame));
    }

    // This machine's copy of the lantern lying by the floor, composed and lit.
    UFUNCTION()
    private void Is_ClientFlameLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Flame))
        {
            const auto WorldItem = Find_WorldItemNear(_FloorTop);
            if (ck::IsValid(WorldItem))
            { _Flame = WorldItem.H().As_Flame(ECk_SanityCheck::UnChecked); }
        }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_Flame) && _Flame.Get_IsLit());
    }

    UFUNCTION()
    private void Is_Burnt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Flame) && _Flame.Get_MeasuresLeft() <= _StartMeasures - k_Falls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFlameItem(Get_QuickLantern());
        WaitUntil(n"Is_ServerFlameComposed", n"OnServerComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
        // The client binds a measure or two after the light; the server outlasts its falls.
        _StartMeasures = _Flame.Get_Measures() - 2;
        WaitUntil(n"Is_Burnt", n"OnServerBurnt", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerBurnt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _StartMeasures = _Flame.Get_MeasuresLeft();
        Watch_Signals(_Flame);
        WaitUntil(n"Is_Burnt", n"OnClientBurnt", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientBurnt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Falls = _StartMeasures - _Flame.Get_MeasuresLeft();
        const auto Elapsed = _Flame.Get_Fragment(FMars_Fragment_Flame_Local).MeasureElapsed;
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[FlameNetTest] fuel burns on the authority only start={_StartMeasures} falls={Falls} measuresChanged={_MeasuresChanges} clientElapsed={Elapsed} newEnsures={NewEnsures}");
        Assert_True(Falls >= k_Falls, f"the client's MeasuresLeft fell (got {Falls} falls)");
        Assert_True(Elapsed == 0.0f, f"the client's own measure clock never ran (got {Elapsed})");
        Assert_Equals_Int(_MeasuresChanges, Falls, "the client raised OnMeasuresChanged once for each fall");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
