// A client's pickup lands in its own hotbar as it sees it: the client fires Cue.Mars.WorldItem.PickUp at a server rock
// with the subject as the initiator; the server stows the rock into the subject's slot 0, and the client's replicated
// copy of that slot holds the very item entity the client's rock held before the cue (TryGet_SlotIndexOf names slot 0),
// which is what the pickup task's landed condition reads.
// Surface: Ck.Hotbar.Net.AS_Hotbar_PickUpLandsInTheInitiatorsSlot
class UCk_AutoTest_Net_Hotbar_PickUpLandsInTheInitiatorsSlot : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_FloorTop = FVector(25400.0, 0.0, 5000.0);

    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_Item _ClientItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Compose_HotbarCarrier(k_FloorTop + FVector(-200.0, 0.0, 100.0), 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientReadyToPickUp", n"OnClientReadyToPickUp", k_SlowPolls);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Rock = Spawn_ServerRock(k_FloorTop + FVector(0.0, 0.0, 20.0));
        WaitUntil(n"Is_ServerStowed", n"OnServerStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_SlotHolds(0, mars_items::Rock()));
    }

    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    // The client's hotbar is ready and the rock arrived holding its item.
    UFUNCTION()
    private void Is_ClientReadyToPickUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = Find_WorldItemNear(k_FloorTop);
        auto Result = OutResult;
        Result.Set(Get_IsCarrierReady(_Carrier) && ck::IsValid(_WorldItem) && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void OnClientReadyToPickUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientItem = _WorldItem.Get_HeldItem();
        Assert_False(_Carrier.Hotbar.TryGet_SlotIndexOf(_ClientItem).IsSet(), "the item is in no slot before the cue");
        utils_cue_generic::Request_ExecuteCue(_WorldItem, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(Get_SubjectEntity()), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        WaitUntil(n"Is_ClientItemInSlot", n"OnClientItemInSlot", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientItemInSlot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Carrier.Hotbar.TryGet_SlotIndexOf(_ClientItem).IsSet());
    }

    UFUNCTION()
    private void OnClientItemInSlot(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Carrier.Hotbar.TryGet_SlotIndexOf(_ClientItem) == TOptional<int32>(0), "the client's own slot 0 holds the item it saw on the floor");
        Assert_True(Get_SlotHolds(0, mars_items::Rock()), "slot 0 holds exactly the rock");
        FinishSuccess();
    }
}
