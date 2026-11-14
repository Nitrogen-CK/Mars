// A fig vine the server empties through its zone (25 Blunt) and lets regrow: the client's copy of the vine disables its
// zone once its forage reads exhausted, and once the forage replenishes its zone is enabled again and its Health reads
// its max.
// Surface: Ck.HitZone.Net.AS_HitZone_AVinesZoneFollowsItsForageOnTheClient
class UCk_AutoTest_Net_HitZone_AVinesZoneFollowsItsForageOnTheClient : UMars_AutoTestRig_NetHitZone
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(514000.0, 0.0, 5000.0);
    private const float32 k_RegrowSeconds = 3.0f;

    private FString _ExhaustedLine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_VineExhausted", n"OnClientExhausted", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFigVine(k_RegrowSeconds);
        WaitUntil(n"Is_VineFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ZoneHit(25.0f, GameplayTags::DamageType_Mars_Blunt);
        WaitUntil(n"Is_VineReplenished", n"OnServerReplenished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReplenished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeldAfterRegrow");
    }

    UFUNCTION()
    private void OnServerHeldAfterRegrow(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The server tracks the fig it released.
        Track_FigsNear();
        Log_ZoneRow("AVinesZoneFollowsItsForageOnTheClient", f"exhausted={_Exhausted} replenished={_Replenished}");
        Assert_Equals_Int(_Exhausted, 1, "the server's vine exhausted once");
        Assert_Equals_Int(_Replenished, 1, "the server's vine regrew once");
        Assert_True(_Zone.Get_IsEnabled(), "the server's zone is enabled again");
        Assert_Equals_Float(_Health.Get_Current(), _Health.Get_Max(), 0.01f, "the server's vine is healed to its max");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_VineExhausted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsVineFound() && _Forage.Get_IsExhausted());
    }

    UFUNCTION()
    private void Is_VineReplenished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsVineFound() && _Replenished > 0 && _Forage.Get_IsExhausted() == false);
    }

    UFUNCTION()
    private void OnClientExhausted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientExhaustedSettled");
    }

    UFUNCTION()
    private void OnClientExhaustedSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsEnabled = _Zone.Get_IsEnabled();
        _ExhaustedLine = f"enabledWhileExhausted={IsEnabled}";
        Assert_False(IsEnabled, "the client's zone is disabled while its forage is exhausted");
        WaitUntil(n"Is_VineReplenished", n"OnClientReplenished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientReplenished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientReplenishedSettled");
    }

    UFUNCTION()
    private void OnClientReplenishedSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_ZoneRow("AVinesZoneFollowsItsForageOnTheClient", f"exhausted={_Exhausted} replenished={_Replenished} {_ExhaustedLine}");
        Assert_True(_Zone.Get_IsEnabled(), "the client's zone is enabled once its forage replenished");
        Assert_Equals_Float(_Health.Get_Current(), _Health.Get_Max(), 0.01f, "the client's vine reads its max Health");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    // World items near the base, tracked for cleanup.
    private void Track_FigsNear()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsNear(Candidate))
            { Track_ForCleanup(Candidate); }
        }
    }
}
