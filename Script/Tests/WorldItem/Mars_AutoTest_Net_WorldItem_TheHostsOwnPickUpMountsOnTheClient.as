// The host's own pickup mounts on the client too: the server picks the Persistent body up for the subject with a plain
// PickUp request (no cue, nothing initiated on the client). The client's copy is Held on the subject and settled, its
// HeldItem presents the body, and its pickup holds the Mounted claim, as a carried body offers no pickup.
// Surface: Ck.WorldItem.Net.AS_WorldItem_TheHostsOwnPickUpMountsOnTheClient
class UCk_AutoTest_Net_WorldItem_TheHostsOwnPickUpMountsOnTheClient : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 18.0f;

    private const FVector k_FloorTop = FVector(34000.0, 0.0, 5000.0);
    private const float32 k_ServerOutliveSeconds = 4.0f;

    private FCk_Handle_WorldItem _WorldItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Compose_HotbarCarrier(k_FloorTop + FVector(-200.0, 0.0, 100.0), 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientHeld", n"OnClientHeld", k_SlowPolls);
            return;
        }

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
        Assert_True(_WorldItem.Get_Carrier() == Get_SubjectEntity(), "the server's body is Held on the subject");
        WaitSeconds(k_ServerOutliveSeconds, n"OnServerDone");
    }

    UFUNCTION()
    private void OnServerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_WorldItem))
        { _WorldItem = Find_WorldItemNear(k_FloorTop); }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && Get_IsCarrierReady(_Carrier) && _WorldItem.Get_IsLinked()
            && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && _WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WorldItem.Get_Carrier() == Get_SubjectEntity(), "the client's body is Held on the subject");
        Assert_True(_WorldItem.Get_MountPoint() == GameplayTags::AttachPoint_Mars_Hand, "the client's body rides the Hand");
        Assert_True(_Carrier.HeldItem.Get_PresentationEntity() == _WorldItem, "the client's HeldItem presents the body itself");
        Assert_True(_WorldItem.Get_Pickup().Get_IsDisabledFor(EMars_Interactable_DisableReason::Mounted),
            "the client's pickup holds the Mounted claim");
        const auto CarrierIsSubject = _WorldItem.Get_Carrier() == Get_SubjectEntity();
        Log(f"[WorldItemNetTest] host pickup client held carrierIsSubject={CarrierIsSubject} presentationIsBody={_Carrier.HeldItem.Get_PresentationEntity() == _WorldItem}");
        FinishSuccess();
    }
}
