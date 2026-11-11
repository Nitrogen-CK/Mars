// A one-fig vine with a short regrow, released on the server: the client raises OnReleased, OnExhausted, then
// OnReplenished from the replicated ledger, in the authority's order, and never holds a regrow timer of its own (the
// regrow runs on the authority alone).
// Surface: Ck.Forage.Net.AS_Forage_ExhaustionAndRegrowReachTheClient
class UCk_AutoTest_Net_Forage_ExhaustionAndRegrowReachTheClient : UMars_AutoTestRig_NetForage
{
    private const FVector k_Base = FVector(70000.0, 0.0, 5000.0);
    private const float32 k_RegrowSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_Replenished", n"OnClientReplenished", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFigVine(k_RegrowSeconds);
        WaitUntil(n"Is_VineFound", n"OnServerVineFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_VineFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourceFound(n"TAG_MarsForageVine"));
    }

    UFUNCTION()
    private void OnServerVineFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Knock));
        WaitUntil(n"Is_Replenished", n"OnServerReplenished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Replenished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourceFound(n"TAG_MarsForageVine") && _Replenished > 0);
        // The server tracks the fig it released.
        Count_WorldItemsNear(mars_items::Fig());
    }

    UFUNCTION()
    private void OnServerReplenished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Forage.Get_ChargesLeft(), 1, "the server's vine regrew its fig");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReplenished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Charges = _Forage.Get_ChargesLeft();
        const auto RegrowPending = _Forage.Get_IsRegrowPending();
        Assert_Equals_String(_Order, "REP", "the client raised released, exhausted, replenished, once each, in order");
        Assert_False(_RegrowPendingAtExhaust, "the client had no regrow timer when it exhausted");
        Assert_False(RegrowPending, "the client has no regrow timer now");
        Assert_Equals_Int(Charges, 1, "the client's vine holds its fig again");
        Log(f"[ForageNetTest] ExhaustionAndRegrowReachTheClient order={_Order} regrowAtExhaust={_RegrowPendingAtExhaust} regrowNow={RegrowPending} charges={Charges}");
        FinishSuccess();
    }
}
