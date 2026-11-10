// A pickup the server refuses comes back as the world item's replicated refusal: the subject's hotbar is full on the
// server (its one bag slot and the overflow each hold a rock), so the drain has nowhere to stow, bumps RefusalSerial with
// NowhereToStow and leaves the item in its holder; the client sees the serial advance with that reason, the item still
// in the holder. The refused initiator rides the same ledger; whether it resolves on the client (a pawn named across
// actors) is logged, not asserted.
// Surface: Ck.WorldItem.Net.AS_WorldItem_RefusalReachesTheInitiator
class UCk_AutoTest_Net_WorldItem_RefusalReachesTheInitiator : UMars_AutoTestRig_NetWorldItem
{
    private const FVector k_FloorTop = FVector(19000.0, 0.0, 5000.0);
    // Long enough for the client to find the rock, fire, and see the refusal.
    private const float32 k_ServerWatchSeconds = 8.0f;

    private FMars_TESTONLY_NetCarrier _Carrier;
    private FCk_Handle_WorldItem _WorldItem;
    private int32 _SerialBeforeCue = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _Carrier = Compose_Carrier(k_FloorTop + FVector(-200.0, 0.0, 100.0), 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientRockHeld", n"OnClientRockHeld", k_SlowPolls);
            return;
        }

        Seed_ServerSlot(_Carrier.Hotbar, 0);
        Seed_ServerSlot(_Carrier.Hotbar, 1);
        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Rock = Spawn_ServerRock(k_FloorTop + FVector(0.0, 0.0, 20.0));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto WorldItem = _Rock.As_WorldItem(ECk_SanityCheck::UnChecked);
        Assert_True(ck::IsValid(WorldItem) && Get_HolderCount(WorldItem) == 1, "the server's rock still holds its item");
        Assert_True(_Carrier.Hotbar.Get_CanStow(WorldItem.Get_HeldItem()) == false, "the server's hotbar is still full");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientRockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = Find_WorldItemNear(k_FloorTop);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void OnClientRockHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialBeforeCue = _WorldItem.Get_RefusalSerial();
        utils_cue_generic::Request_ExecuteCue(_WorldItem, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(Get_SubjectEntity()), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        WaitUntil(n"Is_ClientRefusalArrived", n"OnClientRefusalArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRefusalArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_RefusalSerial() > _SerialBeforeCue);
    }

    UFUNCTION()
    private void OnClientRefusalArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_WorldItem.Get_RefusalSerial(), _SerialBeforeCue + 1, "one refusal");
        Assert_True(_WorldItem.Get_LastRefusal() == EMars_Interaction_FailReason::NowhereToStow,
            f"the refusal is NowhereToStow (got {_WorldItem.Get_LastRefusal() :n})");
        Assert_Equals_Int(Get_HolderCount(_WorldItem), 1, "the client's holder still holds the item");

        const auto Refused = _WorldItem.Get_LastRefused();
        const auto RefusedValid = ck::IsValid(Refused);
        const auto RefusedIsSubject = RefusedValid && Refused == Get_SubjectEntity();
        Log(f"[WorldItemNet] the refused initiator resolved on the client: {RefusedIsSubject} (valid {RefusedValid})");
        FinishSuccess();
    }
}
