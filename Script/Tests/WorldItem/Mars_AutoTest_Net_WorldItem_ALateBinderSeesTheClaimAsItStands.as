// The server claims a rock's pickup for Ledger in the continuation in which it first finds the rock a world item, so the
// claim is in the ledger before the client's copy has bound anything. Within a few frames of its copy becoming a world
// item, the client's pickup is disabled for Ledger and its ledger reads Claimed: the claim as it stands is applied once at
// the bind, not only on a later notify.
// Surface: Ck.WorldItem.Net.AS_WorldItem_ALateBinderSeesTheClaimAsItStands
class UCk_AutoTest_Net_WorldItem_ALateBinderSeesTheClaimAsItStands : UMars_AutoTestRig_NetWorldItem
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_FloorTop = FVector(218000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 4.0f;
    // Frames from the client's copy becoming a world item to its pickup disabled for Ledger.
    private const int32 k_MaxFrames = 10;

    private FCk_Handle_WorldItem _WorldItem;
    private int32 _EnsuresAtStart = 0;
    private int64 _FoundFrame = -1;
    private int64 _ClaimedFrame = -1;

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
        WaitUntil(n"Is_ServerRockWorldItem", n"OnServerRockWorldItem", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRockWorldItem(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rock) && _Rock.Has_Fragment(FMars_Feature_WorldItem));
    }

    UFUNCTION()
    private void OnServerRockWorldItem(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_world_item::Request_ClaimPickup(_Rock, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Text = mars_test_ledger_claim::Describe(_Rock.As_WorldItem());
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Assert_Equals_Int(Ensures, 0, "no ensure");
        Log_Result(Text);
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientClaimed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Frame = int64(utils_time::Get_FrameCounter());
        _WorldItem = Find_WorldItemNear(k_FloorTop);
        if (ck::IsValid(_WorldItem) && _FoundFrame < 0)
        { _FoundFrame = Frame; }

        const auto IsClaimed = ck::IsValid(_WorldItem) && mars_test_ledger_claim::Get_IsHeldByLedger(_WorldItem);
        if (IsClaimed)
        { _ClaimedFrame = Frame; }

        auto Result = OutResult;
        Result.Set(IsClaimed);
    }

    UFUNCTION()
    private void OnClientClaimed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Frames = _ClaimedFrame - _FoundFrame;
        const auto Text = mars_test_ledger_claim::Describe(_WorldItem);
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Assert_True(Frames <= k_MaxFrames, f"the client's pickup was disabled for Ledger within {k_MaxFrames} frames of its copy becoming a world item (took {Frames})");
        Assert_True(_WorldItem.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Claimed, f"the client's ledger reads Claimed ({Text})");
        Assert_Equals_Int(Ensures, 0, "no ensure");
        Log_Result(f"found@{_FoundFrame} claimed@{_ClaimedFrame} frames={Frames} {Text}");
        FinishSuccess();
    }
}
