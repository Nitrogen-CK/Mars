// Selecting away from a held Persistent body carries it on every machine: the server picks the body up for the subject
// (Held on its hand), holds it a moment, then clears the selection; the body is Carried on the subject's Belt there. The
// client derives the same from the replicated selection: Carried on the subject at the Belt, settled, its HeldItem
// presenting nothing, its root on the client's own belt node at the item's carry offset, and no ensure fired since it
// first saw the body Held.
// Surface: Ck.WorldItem.Net.AS_WorldItem_SelectingAwayCarriesTheBodyOnEveryMachine
class UCk_AutoTest_Net_WorldItem_SelectingAwayCarriesTheBodyOnEveryMachine : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 18.0f;

    private const FVector k_FloorTop = FVector(29000.0, 0.0, 5000.0);
    // The server keeps the body Held this long, so the client sees it Held before the selection clears.
    private const float32 k_ServerHeldSeconds = 1.5f;
    private const float32 k_ClientSettleSeconds = 2.0f;
    private const float32 k_ServerOutliveSeconds = 5.0f;
    private const float64 k_PoseToleranceCm = 2.0;

    private FCk_Handle_WorldItem _WorldItem;
    private int32 _EnsuresBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        // A client's hand stands apart from the server's, so the pose check passes only on the client's own attach:
        // the replicated pose would put the body at the server's hand.
        const auto HandApart = utils_net::Get_HasAuthority(Subject) ? FVector::ZeroVector : FVector(0.0, 60.0, 0.0);
        Compose_HotbarCarrier(k_FloorTop + FVector(-200.0, 0.0, 100.0) + HandApart, 1);

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
        WaitSeconds(k_ServerHeldSeconds, n"OnServerHeldAMoment");
    }

    UFUNCTION()
    private void OnServerHeldAMoment(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Carrier.Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>()));
        WaitUntil(n"Is_ServerCarried", n"OnServerCarried", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCarried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried && _WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnServerCarried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WorldItem.Get_Carrier() == Get_SubjectEntity(), "the server's body is Carried on the subject");
        Assert_True(_WorldItem.Get_MountPoint() == GameplayTags::AttachPoint_Mars_Belt, "the server's body rides the Belt");
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
        Result.Set(ck::IsValid(_WorldItem) && Get_IsCarrierReady(_Carrier) && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held);
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        WaitUntil(n"Is_ClientCarried", n"OnClientCarried", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientCarried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried && _WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnClientCarried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WorldItem.Get_Carrier() == Get_SubjectEntity(), "the client's body is Carried on the subject");
        Assert_True(_WorldItem.Get_MountPoint() == GameplayTags::AttachPoint_Mars_Belt, "the client's body rides the Belt");
        Assert_False(_Carrier.Hotbar.Get_SelectedIndex().IsSet(), "the client reads no selection");
        Assert_False(ck::IsValid(_Carrier.HeldItem.Get_PresentationEntity()), "the client's HeldItem presents nothing");
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const UMars_ItemTrait_Presentation Presentation = _WorldItem.Get_Item().Get_Presentation();
        const auto Error = Get_PoseError(_WorldItem, _Carrier.Belt, Presentation.Mounting.CarryOffset);
        Assert_True(Error <= k_PoseToleranceCm, f"the client's body rides its belt node at the carry offset (off by {Error} cm)");
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried, "the client's body is still Carried");
        Assert_Equals_Int(utils_ensure::Get_EnsureCount() - _EnsuresBefore, 0, "no ensure fired while the client carried the body");
        Log(f"[WorldItemNetTest] selecting away carried point={_WorldItem.Get_MountPoint().ToString()} poseErrorCm={Error} newEnsures={utils_ensure::Get_EnsureCount() - _EnsuresBefore}");
        FinishSuccess();
    }
}
