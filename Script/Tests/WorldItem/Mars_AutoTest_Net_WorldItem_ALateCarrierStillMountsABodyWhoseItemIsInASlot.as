// A carrier composed late still mounts a body whose item is already in its slot: the server picks the Persistent body up
// for the subject, waits until it is Held and settled, then raises a ready flag in the replicated report. Only then does
// the client compose its carrier: its linked copy of the body has an empty holder and an item in a slot of a hotbar the
// client has not built yet, which it cannot mount (it stays World, with no ensure). Once the carrier is ready the client's
// body is Held on the subject, its HeldItem presents the body, and OnHeldItemChanged carried the item exactly once.
// Surface: Ck.WorldItem.Net.AS_WorldItem_ALateCarrierStillMountsABodyWhoseItemIsInASlot
class UCk_AutoTest_Net_WorldItem_ALateCarrierStillMountsABodyWhoseItemIsInASlot : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_FloorTop = FVector(31000.0, 0.0, 5000.0);
    // The server outlives the client's late compose, its slot adoption and its mount.
    private const float32 k_ServerOutliveSeconds = 6.0f;

    private FCk_Handle_WorldItem _WorldItem;
    private int32 _HeldItemChangesToTheItem = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Add_Report();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientFlagged", n"OnClientFlagged", k_SlowPolls);
            return;
        }

        Compose_HotbarCarrier(k_FloorTop + FVector(-200.0, 0.0, 100.0), 1);
        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Rock = Spawn_ServerPersistent(k_FloorTop + FVector(0.0, 0.0, 20.0));
        WaitUntil(n"Is_ServerLinkedAndReady", n"OnServerLinkedAndReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLinkedAndReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = _Rock.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_IsLinked() && ck::IsValid(_WorldItem.Get_HeldItem()) && Get_IsCarrierReady(_Carrier));
    }

    UFUNCTION()
    private void OnServerLinkedAndReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(Get_SubjectEntity()));
        WaitUntil(n"Is_ServerHeld", n"OnServerHeldMounted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && _WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnServerHeldMounted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Write_Report(FVector::ZeroVector);
        WaitSeconds(k_ServerOutliveSeconds, n"OnServerDone");
    }

    UFUNCTION()
    private void OnServerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientFlagged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_WorldItem))
        { _WorldItem = Find_WorldItemNear(k_FloorTop); }

        auto Result = OutResult;
        Result.Set(Get_Report().Serial >= 1 && ck::IsValid(_WorldItem) && _WorldItem.Get_IsLinked()
            && ck::Is_NOT_Valid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void OnClientFlagged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::World, "without a carrier the client's body stays World");
        Compose_HotbarCarrier(k_FloorTop + FVector(-200.0, 0.0, 100.0), 1);
        _Carrier.HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnClientHeldItemChanged"));
        WaitUntil(n"Is_ClientHeld", n"OnClientHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        if (ck::IsValid(_WorldItem) && InNew == _WorldItem.Get_Item())
        { _HeldItemChangesToTheItem += 1; }
    }

    UFUNCTION()
    private void Is_ClientHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_WorldItem))
        { _WorldItem = Find_WorldItemNear(k_FloorTop); }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && Get_IsCarrierReady(_Carrier) && _WorldItem.Get_IsLinked()
            && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && _WorldItem.Get_IsSettled()
            && _Carrier.HeldItem.Get_PresentationEntity() == _WorldItem);
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WorldItem.Get_Carrier() == Get_SubjectEntity(), "the client's body is Held on the subject");
        Assert_True(_Carrier.Hotbar.Get_ItemAt(0) == _WorldItem.Get_Item(), "the client's slot holds the linked item");
        Assert_True(_Carrier.HeldItem.Get_CurrentItem() == _WorldItem.Get_Item(), "the client's HeldItem holds the linked item");
        Assert_Equals_Int(_HeldItemChangesToTheItem, 1, "OnHeldItemChanged carried the item exactly once on the client");
        Log(f"[WorldItemNetTest] late carrier held heldItemChangesToTheItem={_HeldItemChangesToTheItem} presentationIsBody={_Carrier.HeldItem.Get_PresentationEntity() == _WorldItem}");
        FinishSuccess();
    }
}
