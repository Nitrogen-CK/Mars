// A drop returns one body to the world on every machine: the server picks the Persistent body up for the subject (Held),
// then releases it; the item goes back into its holder, the body falls to rest on the floor and the server reports where.
// The client learns of the release from the item back in its own holder: its copy commits World with no ensure, exactly
// one World-mode body lies near the floor, it ends at the server's rest within 5 cm (a detached body takes the
// authority's pose again) and its pickup is offered again.
// Surface: Ck.WorldItem.Net.AS_WorldItem_ADropReturnsOneBodyToTheWorldOnEveryMachine
class UCk_AutoTest_Net_WorldItem_ADropReturnsOneBodyToTheWorldOnEveryMachine : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_FloorTop = FVector(30000.0, 0.0, 5000.0);
    private const float32 k_ServerHeldSeconds = 1.0f;
    private const float32 k_ClientSettleSeconds = 0.5f;
    private const float32 k_ServerOutliveSeconds = 4.0f;
    private const float64 k_RestToleranceCm = 5.0;
    private const float64 k_SearchRadiusCm = 1000.0;

    private FCk_Handle_WorldItem _WorldItem;
    private int32 _EnsuresBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Add_Report();
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
        WaitSeconds(k_ServerHeldSeconds, n"OnServerHeldAMoment");
    }

    UFUNCTION()
    private void OnServerHeldAMoment(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _WorldItem.Request_Release(FMars_Request_WorldItem_Release(FVector(0.0, 0.0, 50.0), FVector::ZeroVector));
        Reset_RockStill();
        WaitUntil(n"Is_ServerAtRest", n"OnServerAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsStill = Tick_RockStill();
        auto Result = OutResult;
        Result.Set(IsStill && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::World && _WorldItem.Get_HeldItem() == _WorldItem.Get_Item()
            && _WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnServerAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(ck::IsValid(_Carrier.Hotbar.Get_ItemAt(0)), "the server's slot is empty after the release");
        Write_Report(Get_RootLocation(_Rock));
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
        WaitUntil(n"Is_ClientReleasedAndReported", n"OnClientReleasedAndReported", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReleasedAndReported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::World && Get_Report().Serial >= 1);
    }

    UFUNCTION()
    private void OnClientReleasedAndReported(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Rest = Get_Report().RestLocation;
        const auto Distance = (Get_RootLocation(_WorldItem) - Rest).Size();
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::World, "the client's body is World");
        Assert_True(_WorldItem.Get_HeldItem() == _WorldItem.Get_Item(), "the client's holder holds the linked item again");
        Assert_False(_WorldItem.Is_SceneNode(), "the client's body is detached");
        Assert_Equals_Int(Get_WorldItemCountNear(k_FloorTop, k_SearchRadiusCm), 1, "exactly one World-mode body near the floor on the client");
        Assert_True(Distance <= k_RestToleranceCm, f"the client's body rests where the server's does (off by {Distance} cm)");
        Assert_False(_WorldItem.Get_Pickup().Get_IsDisabledFor(EMars_Interactable_DisableReason::Mounted), "the client's pickup is offered again");
        Assert_Equals_Int(utils_ensure::Get_EnsureCount() - _EnsuresBefore, 0, "no ensure fired from the hold to the rest");
        const auto BodiesNear = Get_WorldItemCountNear(k_FloorTop, k_SearchRadiusCm);
        Log(f"[WorldItemNetTest] drop world restOffCm={Distance} bodiesNear={BodiesNear} newEnsures={utils_ensure::Get_EnsureCount() - _EnsuresBefore} rest={Rest.ToString()}");
        FinishSuccess();
    }
}
