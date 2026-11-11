// A client's pickup of a Persistent body is Held on every machine: once the client's copy is linked and its carrier
// ready, it fires Cue.Mars.WorldItem.PickUp once; the server stows the item into the subject's slot (the arrival rule
// selects it) and mounts the body Held on the subject's hand. The client derives the same mount from the replicated slot
// and selection: its copy goes from World straight to Held on the subject's Hand and settles, its HeldItem presents the
// body itself (Borrowed, no Visual-mode copy anywhere), the body rides the client's own hand node at the held offset,
// and no ensure fires while it does (the replicated pose yields to the local mount). A rock is no food, so the
// selected-food door is not read.
// Surface: Ck.WorldItem.Net.AS_WorldItem_AClientPickUpOfAPersistentItemIsHeldOnEveryMachine
class UCk_AutoTest_Net_WorldItem_AClientPickUpOfAPersistentItemIsHeldOnEveryMachine : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 18.0f;

    private const FVector k_FloorTop = FVector(28000.0, 0.0, 5000.0);
    private const float32 k_ClientSettleSeconds = 2.0f;
    // The server outlives the client's cue, its mount and its settle.
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
            WaitUntil(n"Is_ClientReadyToPickUp", n"OnClientReadyToPickUp", k_SlowPolls);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Rock = Spawn_ServerPersistent(k_FloorTop + FVector(0.0, 0.0, 20.0));
        WaitUntil(n"Is_ServerHeld", n"OnServerHeldMounted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = _Rock.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_IsLinked() && _Carrier.Hotbar.Get_ItemAt(0) == _WorldItem.Get_Item()
            && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && _WorldItem.Get_IsSettled());
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
    private void Is_ClientReadyToPickUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_WorldItem))
        { _WorldItem = Find_WorldItemNear(k_FloorTop); }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_IsLinked() && ck::IsValid(_WorldItem.Get_HeldItem())
            && Get_IsCarrierReady(_Carrier));
    }

    UFUNCTION()
    private void OnClientReadyToPickUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::World, "the client's body starts World");
        Record_MountChanges(_WorldItem);
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        utils_cue_generic::Request_ExecuteCue(_WorldItem, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(Get_SubjectEntity()), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        WaitUntil(n"Is_ClientHeld", n"OnClientHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && _WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto& Held = _Carrier.HeldItem.Get_Fragment(FMars_Fragment_HeldItem);
        Assert_True(_WorldItem.Get_Carrier() == Get_SubjectEntity(), "the client's body is Held on the subject");
        Assert_True(_WorldItem.Get_MountPoint() == GameplayTags::AttachPoint_Mars_Hand, "the client's body rides the Hand");
        Assert_True(_Carrier.Hotbar.Get_ItemAt(0) == _WorldItem.Get_Item(), "the client's slot holds the linked item");
        Assert_Equals_Int(_MountChanges.Num(), 1, f"the client's copy changed mount once, World to Held (got: {Describe_MountChanges()})");
        Assert_True(_MountChanges.Num() == 1 && _MountChanges[0] == EMars_WorldItem_Mount::Held, "the one change is to Held");
        Assert_True(_Carrier.HeldItem.Get_PresentationEntity() == _WorldItem, "the client's HeldItem presents the body itself");
        Assert_True(Held.PresentationOwnership == EMars_HeldItem_PresentationOwnership::Borrowed, "the body is a Borrowed presentation");
        Assert_Equals_Int(Get_VisualWorldItemCount(), 0, "no Visual-mode world item exists on the client");
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const UMars_ItemTrait_Presentation Presentation = _WorldItem.Get_Item().Get_Presentation();
        const auto Error = Get_PoseError(_WorldItem, _Carrier.Hand, Presentation.Mounting.HeldOffset);
        Assert_True(Error <= k_PoseToleranceCm, f"the client's body rides its hand node at the held offset (off by {Error} cm)");
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held, "the client's body is still Held");
        Assert_Equals_Int(utils_ensure::Get_EnsureCount() - _EnsuresBefore, 0, "no ensure fired while the client held the body");
        const auto Visuals = Get_VisualWorldItemCount();
        Log(f"[WorldItemNetTest] client pickup held changes=[{Describe_MountChanges()}] poseErrorCm={Error} newEnsures={utils_ensure::Get_EnsureCount() - _EnsuresBefore} presentationIsBody={_Carrier.HeldItem.Get_PresentationEntity() == _WorldItem} visuals={Visuals}");
        FinishSuccess();
    }
}
