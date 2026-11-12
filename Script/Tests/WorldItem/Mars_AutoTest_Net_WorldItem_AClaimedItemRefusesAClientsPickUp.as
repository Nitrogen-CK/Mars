// The server claims a resting rock's pickup for Ledger. The client, once its copy reads Claimed, fires the pickup cue for
// the subject anyway (a press sent while the claim was on its way): the authority refuses it ActionBlocked, advancing the
// replicated refusal once, and the item stays in the rock's holder. The client sees that refusal, the item still in its
// holder and its hotbar slot empty; so does the server. The subject's carrier is composed on both machines, as the pawn's.
// Surface: Ck.WorldItem.Net.AS_WorldItem_AClaimedItemRefusesAClientsPickUp
class UCk_AutoTest_Net_WorldItem_AClaimedItemRefusesAClientsPickUp : UMars_AutoTestRig_NetWorldItem
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_FloorTop = FVector(217000.0, 0.0, 5000.0);
    // Long enough for the claim to reach the client, its cue to reach the server and the refusal to come back.
    private const float32 k_ServerWatchSeconds = 6.0f;

    private FMars_TESTONLY_NetCarrier _Carrier;
    private FCk_Handle_WorldItem _WorldItem;
    private int32 _EnsuresAtStart = 0;
    private int32 _SerialBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        _Carrier = Compose_Carrier(k_FloorTop + FVector(-200.0, 0.0, 100.0), 1);

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
        _SerialBefore = _Rock.As_WorldItem().Get_RefusalSerial();
        utils_world_item::Request_ClaimPickup(_Rock, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto WorldItem = _Rock.As_WorldItem(ECk_SanityCheck::UnChecked);
        const auto IsValid = ck::IsValid(WorldItem);
        const auto Serial = IsValid ? WorldItem.Get_RefusalSerial() : -1;
        const auto Holder = IsValid ? Get_HolderCount(WorldItem) : 0;
        const auto Refusal = IsValid ? WorldItem.Get_LastRefusal() : EMars_Interaction_FailReason::NowhereToStow;
        const auto IsSlotEmpty = ck::Is_NOT_Valid(_Carrier.Hotbar.Get_ItemAt(0));
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Assert_Equals_Int(Holder, 1, "the server's rock still holds its item");
        Assert_True(IsSlotEmpty, "the server's hotbar slot is empty");
        Assert_Equals_Int(Serial, _SerialBefore + 1, "the server refused one pickup");
        Assert_True(Refusal == EMars_Interaction_FailReason::ActionBlocked, f"the refusal is ActionBlocked (got {Refusal :n})");
        Assert_Equals_Int(Ensures, 0, "no ensure");
        Log_Result(f"holder={Holder} slot-empty={IsSlotEmpty} refusals {_SerialBefore}->{Serial} last={Refusal :n}");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientClaimed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = Find_WorldItemNear(k_FloorTop);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && ck::IsValid(_WorldItem.Get_HeldItem())
            && _WorldItem.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Claimed);
    }

    UFUNCTION()
    private void OnClientClaimed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialBefore = _WorldItem.Get_RefusalSerial();
        utils_cue_generic::Request_ExecuteCue(_WorldItem, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(Get_SubjectEntity()), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        WaitUntil(n"Is_ClientRefusalArrived", n"OnClientRefusalArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRefusalArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_RefusalSerial() > _SerialBefore);
    }

    UFUNCTION()
    private void OnClientRefusalArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Serial = _WorldItem.Get_RefusalSerial();
        const auto Refusal = _WorldItem.Get_LastRefusal();
        const auto Holder = Get_HolderCount(_WorldItem);
        const auto IsSlotEmpty = ck::Is_NOT_Valid(_Carrier.Hotbar.Get_ItemAt(0));
        const auto Ensures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Assert_Equals_Int(Serial, _SerialBefore + 1, "one refusal");
        Assert_True(Refusal == EMars_Interaction_FailReason::ActionBlocked, f"the refusal is ActionBlocked (got {Refusal :n})");
        Assert_Equals_Int(Holder, 1, "the client's holder still holds the item");
        Assert_True(IsSlotEmpty, "the client's hotbar slot is empty");
        Assert_Equals_Int(Ensures, 0, "no ensure");
        Log_Result(f"holder={Holder} slot-empty={IsSlotEmpty} refusals {_SerialBefore}->{Serial} last={Refusal :n}");
        FinishSuccess();
    }
}
