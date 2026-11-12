// The client claims its own copy of a resting rock's pickup for Ledger, as a kernel still running on a client does: its own
// pickup is disabled for Ledger, but a machine without authority publishes nothing, so 1.5 s later its ledger still reads
// Unclaimed, and the server's pickup and ledger are untouched at the end.
// Surface: Ck.WorldItem.Net.AS_WorldItem_TheClientWroteNoClaim
class UCk_AutoTest_Net_WorldItem_TheClientWroteNoClaim : UMars_AutoTestRig_NetWorldItem
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_FloorTop = FVector(219000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 6.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    private FCk_Handle_WorldItem _WorldItem;
    private int32 _EnsuresAtStart = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientRockFound", n"OnClientRockFound", k_SlowPolls);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private void Log_Result(FString InText)
    {
        const FString Machine = utils_net::Get_HasAuthority(Get_SubjectEntity()) ? "server" : "client";
        const auto TestName = GetClass().GetName();
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Log(f"[WorldItemNetTest] {TestName} {Machine}: {InText} ensures={Ensures}");
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Rock = Spawn_ServerRock(k_FloorTop + FVector(0.0, 0.0, 20.0));
        WaitUntil(n"Is_ServerRockStill", n"OnServerRockStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRockStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Tick_RockStill());
    }

    UFUNCTION()
    private void OnServerRockStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto WorldItem = _Rock.As_WorldItem();
        const auto Text = mars_test_ledger_claim::Describe(WorldItem);
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Assert_False(mars_test_ledger_claim::Get_IsHeldByLedger(WorldItem), f"the server's pickup is not disabled for Ledger ({Text})");
        Assert_True(WorldItem.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Unclaimed, f"the server's ledger reads Unclaimed ({Text})");
        Assert_Equals_Int(Ensures, 0, "no ensure");
        Log_Result(Text);
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientRockFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = Find_WorldItemNear(k_FloorTop);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void OnClientRockFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_world_item::Request_ClaimPickup(_WorldItem, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Text = mars_test_ledger_claim::Describe(_WorldItem);
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Assert_True(_WorldItem.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Unclaimed, f"the client's ledger reads Unclaimed ({Text})");
        Assert_True(mars_test_ledger_claim::Get_IsHeldByLedger(_WorldItem), f"the client's own pickup is disabled for Ledger ({Text})");
        Assert_Equals_Int(Ensures, 0, "no ensure");
        Log_Result(Text);
        FinishSuccess();
    }
}
