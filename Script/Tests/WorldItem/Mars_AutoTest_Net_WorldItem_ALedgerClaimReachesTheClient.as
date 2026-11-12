// The server claims a resting rock's pickup for Ledger, as a kernel's ledger does when it takes an item, and 1.5 s later
// releases it. The claim rides the world item's replicated ledger: the client's copy reads Claimed and its pickup becomes
// disabled for Ledger and out of focus, then reads Unclaimed and its pickup is enabled and focusable again, in that order.
// Surface: Ck.WorldItem.Net.AS_WorldItem_ALedgerClaimReachesTheClient
class UCk_AutoTest_Net_WorldItem_ALedgerClaimReachesTheClient : UMars_AutoTestRig_NetWorldItem
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_FloorTop = FVector(216000.0, 0.0, 5000.0);
    private const float32 k_ClaimSeconds = 1.5f;

    private FCk_Handle_WorldItem _WorldItem;
    private int32 _EnsuresAtStart = 0;
    private FString _ClaimedText;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientClaimed", n"OnClientClaimed", k_SlowPolls);
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
        utils_world_item::Request_ClaimPickup(_Rock, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        WaitSeconds(k_ClaimSeconds, n"OnServerRelease");
    }

    UFUNCTION()
    private void OnServerRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClaimedText = mars_test_ledger_claim::Describe(_Rock.As_WorldItem());
        utils_world_item::Request_ClaimPickup(_Rock, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        const auto ReleasedText = mars_test_ledger_claim::Describe(_Rock.As_WorldItem());
        Assert_Equals_Int(Ensures, 0, "no ensure");
        Log_Result(f"claimed ({_ClaimedText}) released ({ReleasedText})");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientClaimed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = Find_WorldItemNear(k_FloorTop);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && mars_test_ledger_claim::Get_IsHeldByLedger(_WorldItem));
    }

    UFUNCTION()
    private void OnClientClaimed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClaimedText = mars_test_ledger_claim::Describe(_WorldItem);
        Assert_False(mars_test_ledger_claim::Get_IsFocusable(_WorldItem), f"the claimed pickup is out of focus ({_ClaimedText})");
        Assert_True(_WorldItem.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Claimed, f"the client's ledger reads Claimed ({_ClaimedText})");
        WaitUntil(n"Is_ClientReleased", n"OnClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && mars_test_ledger_claim::Get_IsHeldByLedger(_WorldItem) == false);
    }

    UFUNCTION()
    private void OnClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto ReleasedText = mars_test_ledger_claim::Describe(_WorldItem);
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Assert_True(mars_test_ledger_claim::Get_IsFocusable(_WorldItem), f"the released pickup is focusable again ({ReleasedText})");
        Assert_True(_WorldItem.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Unclaimed, f"the client's ledger reads Unclaimed ({ReleasedText})");
        Assert_Equals_Int(Ensures, 0, "no ensure");
        Log_Result(f"claimed ({_ClaimedText}) released ({ReleasedText})");
        FinishSuccess();
    }
}
